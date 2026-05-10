import asyncio
import logging
import os
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import cv2
from dotenv import load_dotenv
import shutil

import numpy as np
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from storage3.exceptions import StorageApiError
from supabase import Client, create_client
from ultralytics import YOLO

load_dotenv()

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"
SNAPSHOTS_DIR = BASE_DIR / "snapshots"
SNAPSHOTS_DIR.mkdir(exist_ok=True)
UPLOADS_DIR = BASE_DIR / "uploads"
UPLOADS_DIR.mkdir(exist_ok=True)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_SNAPSHOT_BUCKET = os.getenv("SUPABASE_SNAPSHOT_BUCKET", "incident-snapshots")
# Base URL the browser uses to load snapshots when falling back to files served by this API.
BACKEND_PUBLIC_URL = os.getenv("BACKEND_PUBLIC_URL", "http://localhost:8000").rstrip("/")
CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.55"))
PROCESS_FPS = float(os.getenv("PROCESS_FPS", "2.5"))


class CameraCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    stream_url: str = Field(min_length=1)
    is_active: bool = True


class CameraUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=100)
    stream_url: Optional[str] = Field(default=None, min_length=1)
    is_active: Optional[bool] = None


class ToggleCameraPayload(BaseModel):
    is_active: bool


class FalsePositivePayload(BaseModel):
    is_false_positive: bool = True


class DetectionEvent(BaseModel):
    camera_id: str
    camera_name: str
    incident_type: str
    confidence_score: float
    snapshot_url: Optional[str] = None
    timestamp: datetime
    bbox: List[float]
    model_name: str


INCIDENT_CLASSES = {
    "fire": "Fire",
    "smoke": "Smoke",
    "weapon": "Weapon",
    "gun": "Weapon",
    "knife": "Weapon",
    "accident": "Accident",
    "fall": "Fall",
    "ppe violation": "PPE Violation",
    "no helmet": "PPE Violation",
    "no vest": "PPE Violation",
}


class WebSocketManager:
    def __init__(self) -> None:
        self.connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self.connections:
            self.connections.remove(websocket)

    async def broadcast(self, message: Dict[str, Any]) -> None:
        disconnected: List[WebSocket] = []
        for connection in self.connections:
            try:
                await connection.send_json(message)
            except Exception:
                disconnected.append(connection)
        for connection in disconnected:
            self.disconnect(connection)


class AppState:
    def __init__(self) -> None:
        self.supabase: Optional[Client] = None
        self.models: Dict[str, YOLO] = {}
        self.cameras: Dict[str, Dict[str, Any]] = {}
        self.camera_tasks: Dict[str, asyncio.Task] = {}
        self.ws_manager = WebSocketManager()
        self.model_labels: Dict[str, List[str]] = defaultdict(list)
        # Last loop time for POST /cameras/{id}/device-frame rate limiting (per camera_id).
        self.device_frame_last_ts: Dict[str, float] = {}


state = AppState()
app = FastAPI(title="AI Incident Reporting System API", version="1.0.0")

# allow_credentials=False: browsers reject Access-Control-Allow-Origin=* together with
# credentials; Flutter Web → backend is cross-origin and would get "Failed to fetch".
# allow_private_network: Chrome may block localhost-origin pages calling loopback unless
# Access-Control-Allow-Private-Network is set on preflight.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    allow_private_network=True,
)

app.mount("/snapshots", StaticFiles(directory=str(SNAPSHOTS_DIR)), name="snapshots")


def map_incident_type(raw_label: str) -> str:
    key = raw_label.strip().lower()
    return INCIDENT_CLASSES.get(key, "Accident")


def get_supabase() -> Optional[Client]:
    if SUPABASE_URL and SUPABASE_KEY:
        return create_client(SUPABASE_URL, SUPABASE_KEY)
    return None


async def run_yolo_inference(model: YOLO, frame):
    return await asyncio.to_thread(model.predict, frame, verbose=False)


async def persist_snapshot(camera_id: str, frame, incident_id: str) -> str:
    safe_camera = str(camera_id).replace("/", "_").replace("\\", "_")
    file_name = f"{safe_camera}_{incident_id}.jpg"
    local_path = SNAPSHOTS_DIR / file_name
    await asyncio.to_thread(cv2.imwrite, str(local_path), frame)

    local_public_url = f"{BACKEND_PUBLIC_URL}/snapshots/{file_name}"

    if not state.supabase:
        return local_public_url

    try:
        with open(local_path, "rb") as image_file:
            state.supabase.storage.from_(SUPABASE_SNAPSHOT_BUCKET).upload(
                path=file_name,
                file=image_file,
                file_options={"content-type": "image/jpeg", "upsert": "true"},
            )
        return state.supabase.storage.from_(SUPABASE_SNAPSHOT_BUCKET).get_public_url(file_name)
    except StorageApiError as exc:
        logger.warning(
            "Supabase Storage upload failed (%s); serving snapshot from API. "
            "Create bucket %r in Supabase or set BACKEND_PUBLIC_URL if the UI cannot load images.",
            exc,
            SUPABASE_SNAPSHOT_BUCKET,
        )
        return local_public_url
    except OSError as exc:
        logger.warning("Could not read snapshot for upload: %s", exc)
        return local_public_url
    except Exception as exc:
        # Upload may raise httpx errors (timeout, connect) not wrapped as StorageApiError;
        # video analysis calls this many times and would otherwise crash the whole request.
        logger.warning(
            "Supabase Storage upload failed (%s: %s); serving snapshot from API.",
            type(exc).__name__,
            exc,
        )
        return local_public_url


async def insert_incident(payload: Dict[str, Any]) -> None:
    if not state.supabase:
        return
    await asyncio.to_thread(lambda: state.supabase.table("incidents").insert(payload).execute())


async def dispatch_detections_from_frame(camera_id: str, camera_name: str, frame) -> None:
    """Run all loaded models on one BGR frame; persist incidents and WS broadcast (same as live stream)."""
    for model_name, model in state.models.items():
        results = await run_yolo_inference(model, frame)
        if not results:
            continue

        prediction = results[0]
        boxes = getattr(prediction, "boxes", [])
        for box in boxes:
            conf = float(box.conf[0].item())
            if conf < CONFIDENCE_THRESHOLD:
                continue

            class_id = int(box.cls[0].item())
            label_map = prediction.names
            raw_label = label_map.get(class_id, "accident")
            incident_type = map_incident_type(raw_label)
            xyxy = box.xyxy[0].tolist()
            incident_id = str(uuid.uuid4())
            snapshot_url = await persist_snapshot(camera_id, frame, incident_id)

            incident_payload = {
                "id": incident_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "camera_id": camera_id,
                "incident_type": incident_type,
                "confidence_score": round(conf, 4),
                "snapshot_url": snapshot_url,
                "is_false_positive": False,
            }

            await insert_incident(incident_payload)

            event = DetectionEvent(
                camera_id=camera_id,
                camera_name=camera_name,
                incident_type=incident_type,
                confidence_score=round(conf, 4),
                snapshot_url=snapshot_url,
                timestamp=datetime.now(timezone.utc),
                bbox=[round(v, 2) for v in xyxy],
                model_name=model_name,
            )
            await state.ws_manager.broadcast({"type": "incident_detected", "payload": event.model_dump(mode="json")})


async def process_camera_stream(camera_id: str) -> None:
    min_interval = 1.0 / PROCESS_FPS
    last_processed = 0.0

    while True:
        camera = state.cameras.get(camera_id)
        if not camera:
            return
        if not camera.get("is_active"):
            await asyncio.sleep(1.0)
            continue

        capture = cv2.VideoCapture(camera["stream_url"])
        if not capture.isOpened():
            await state.ws_manager.broadcast(
                {"camera_id": camera_id, "status": "disconnected", "message": "Unable to open stream"}
            )
            await asyncio.sleep(5.0)
            continue

        await state.ws_manager.broadcast({"camera_id": camera_id, "status": "connected"})

        try:
            while camera.get("is_active", False):
                ok, frame = capture.read()
                if not ok:
                    break

                now = asyncio.get_event_loop().time()
                if now - last_processed < min_interval:
                    continue
                last_processed = now

                await dispatch_detections_from_frame(camera_id, camera["name"], frame)
        finally:
            capture.release()
            await state.ws_manager.broadcast({"camera_id": camera_id, "status": "reconnecting"})
            await asyncio.sleep(2.0)


async def start_camera_task(camera_id: str) -> None:
    if camera_id in state.camera_tasks and not state.camera_tasks[camera_id].done():
        return
    state.camera_tasks[camera_id] = asyncio.create_task(process_camera_stream(camera_id))


@app.on_event("startup")
async def startup_event() -> None:
    state.supabase = get_supabase()

    model_files = [MODELS_DIR / "yolo_model_1.pt", MODELS_DIR / "yolo_model_2.pt"]
    for model_path in model_files:
        if not model_path.exists():
            raise RuntimeError(f"Model missing: {model_path}")
        model = YOLO(str(model_path))
        state.models[model_path.stem] = model

    if state.supabase:
        response = await asyncio.to_thread(lambda: state.supabase.table("cameras").select("*").execute())
        for row in response.data or []:
            camera_id = row["id"]
            state.cameras[camera_id] = row
            if row.get("is_active"):
                await start_camera_task(camera_id)


@app.on_event("shutdown")
async def shutdown_event() -> None:
    for task in state.camera_tasks.values():
        task.cancel()
    await asyncio.gather(*state.camera_tasks.values(), return_exceptions=True)


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "models_loaded": list(state.models.keys()),
        "camera_count": len(state.cameras),
    }


@app.get("/cameras")
async def list_cameras() -> List[Dict[str, Any]]:
    return list(state.cameras.values())


@app.get("/incidents")
async def list_incidents(limit: int = 200) -> List[Dict[str, Any]]:
    if not state.supabase:
        return []
    safe_limit = min(max(limit, 1), 500)
    response = await asyncio.to_thread(
        lambda: state.supabase.table("incidents")
        .select("*")
        .order("created_at", desc=True)
        .limit(safe_limit)
        .execute()
    )
    return response.data or []


@app.patch("/incidents/{incident_id}/false-positive")
async def mark_incident_false_positive(incident_id: str, payload: FalsePositivePayload) -> Dict[str, Any]:
    if not state.supabase:
        raise HTTPException(status_code=503, detail="Database not configured")
    await asyncio.to_thread(
        lambda: state.supabase.table("incidents")
        .update({"is_false_positive": payload.is_false_positive})
        .eq("id", incident_id)
        .execute()
    )
    return {"status": "ok", "id": incident_id, "is_false_positive": payload.is_false_positive}


@app.post("/cameras")
async def create_camera(payload: CameraCreate) -> Dict[str, Any]:
    camera_id = str(uuid.uuid4())
    camera = {"id": camera_id, **payload.model_dump()}
    state.cameras[camera_id] = camera

    if state.supabase:
        await asyncio.to_thread(lambda: state.supabase.table("cameras").insert(camera).execute())

    if payload.is_active:
        await start_camera_task(camera_id)
    return camera


@app.put("/cameras/{camera_id}")
async def update_camera(camera_id: str, payload: CameraUpdate) -> Dict[str, Any]:
    if camera_id not in state.cameras:
        raise HTTPException(status_code=404, detail="Camera not found")

    updates = payload.model_dump(exclude_none=True)
    state.cameras[camera_id].update(updates)

    if state.supabase and updates:
        await asyncio.to_thread(
            lambda: state.supabase.table("cameras").update(updates).eq("id", camera_id).execute()
        )

    if state.cameras[camera_id].get("is_active"):
        await start_camera_task(camera_id)
    return state.cameras[camera_id]


@app.delete("/cameras/{camera_id}")
async def delete_camera(camera_id: str) -> Dict[str, str]:
    if camera_id not in state.cameras:
        raise HTTPException(status_code=404, detail="Camera not found")

    state.cameras.pop(camera_id)
    task = state.camera_tasks.pop(camera_id, None)
    if task:
        task.cancel()

    if state.supabase:
        await asyncio.to_thread(lambda: state.supabase.table("cameras").delete().eq("id", camera_id).execute())
    return {"status": "deleted"}


@app.post("/cameras/{camera_id}/device-frame")
async def ingest_device_frame(camera_id: str, file: UploadFile = File(...)) -> Dict[str, Any]:
    """JPEG frame from a mobile/local preview; must be a camera registered with stream_url device://…"""
    cam = state.cameras.get(camera_id)
    if not cam:
        raise HTTPException(status_code=404, detail="Camera not found")
    stream_url = str(cam.get("stream_url") or "")
    if not stream_url.startswith("device://"):
        raise HTTPException(status_code=400, detail="Camera is not configured for device frame ingest")

    loop = asyncio.get_event_loop()
    now = loop.time()
    min_interval = 1.0 / max(PROCESS_FPS, 0.25)
    last = state.device_frame_last_ts.get(camera_id, 0.0)
    if now - last < min_interval:
        return {"status": "throttled", "skipped": True}

    raw = await file.read()
    buf = np.frombuffer(raw, dtype=np.uint8)
    frame = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image")

    state.device_frame_last_ts[camera_id] = now
    await dispatch_detections_from_frame(camera_id, cam["name"], frame)
    return {"status": "ok"}


@app.post("/cameras/{camera_id}/toggle")
async def toggle_camera(camera_id: str, payload: ToggleCameraPayload) -> Dict[str, Any]:
    if camera_id not in state.cameras:
        raise HTTPException(status_code=404, detail="Camera not found")

    state.cameras[camera_id]["is_active"] = payload.is_active
    if state.supabase:
        await asyncio.to_thread(
            lambda: state.supabase.table("cameras")
            .update({"is_active": payload.is_active})
            .eq("id", camera_id)
            .execute()
        )

    if payload.is_active:
        await start_camera_task(camera_id)
    return state.cameras[camera_id]


@app.post("/analyze-image")
async def analyze_image(file: UploadFile = File(...)) -> Dict[str, Any]:
    raw = await file.read()
    buf = np.frombuffer(raw, dtype=np.uint8)
    frame = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image")

    detections = []
    for model_name, model in state.models.items():
        results = await run_yolo_inference(model, frame)
        if not results:
            continue
        prediction = results[0]
        boxes = getattr(prediction, "boxes", [])
        for box in boxes:
            conf = float(box.conf[0].item())
            if conf < CONFIDENCE_THRESHOLD:
                continue
            class_id = int(box.cls[0].item())
            raw_label = prediction.names.get(class_id, "accident")
            incident_type = map_incident_type(raw_label)
            incident_id = str(uuid.uuid4())
            snapshot_url = await persist_snapshot("photo_upload", frame, incident_id)
            detections.append(
                {
                    "incident_type": incident_type,
                    "confidence": round(conf, 4),
                    "snapshot_url": snapshot_url,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "model": model_name,
                }
            )

    return {"status": "completed", "detections_count": len(detections), "detections": detections}


@app.post("/analyze-video")
async def analyze_video(file: UploadFile = File(...)) -> Dict[str, Any]:
    file_path = UPLOADS_DIR / f"{uuid.uuid4()}_{file.filename}"
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    capture = cv2.VideoCapture(str(file_path))
    if not capture.isOpened():
        raise HTTPException(status_code=400, detail="Could not open video file")

    detections = []
    frame_count = 0
    process_interval = int(capture.get(cv2.CAP_PROP_FPS) / PROCESS_FPS)
    if process_interval < 1: process_interval = 1

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break

            if frame_count % process_interval == 0:
                for model_name, model in state.models.items():
                    results = await run_yolo_inference(model, frame)
                    if not results:
                        continue
                    
                    prediction = results[0]
                    boxes = getattr(prediction, "boxes", [])
                    for box in boxes:
                        conf = float(box.conf[0].item())
                        if conf < CONFIDENCE_THRESHOLD:
                            continue

                        class_id = int(box.cls[0].item())
                        raw_label = prediction.names.get(class_id, "accident")
                        incident_type = map_incident_type(raw_label)
                        
                        incident_id = str(uuid.uuid4())
                        snapshot_url = await persist_snapshot("video_upload", frame, incident_id)
                        
                        detections.append({
                            "incident_type": incident_type,
                            "confidence": round(conf, 4),
                            "snapshot_url": snapshot_url,
                            "timestamp": datetime.now(timezone.utc).isoformat(),
                            "model": model_name
                        })
            frame_count += 1
    finally:
        capture.release()
        if file_path.exists():
            os.remove(file_path)

    return {"status": "completed", "detections_count": len(detections), "detections": detections}

@app.websocket("/ws/detections")
async def detection_ws(websocket: WebSocket) -> None:
    await state.ws_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        state.ws_manager.disconnect(websocket)
