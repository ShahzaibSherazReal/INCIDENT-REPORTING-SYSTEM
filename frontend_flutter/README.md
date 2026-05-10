# AIRS Frontend (Flutter Web + Mobile)

This is the Flutter client for the AI-Based Incident Reporting System (AIRS).
It connects to Supabase for authentication and realtime incidents, and to the FastAPI backend for camera control.

## Prerequisites

- Flutter SDK (stable, 3.22+ recommended)
- Chrome (for web target)
- Android Studio / Xcode (for mobile targets)

## Configuration

1. Open `lib/services/app_config.dart`.
2. Confirm the values:
   - `supabaseUrl`
   - `supabaseAnonKey`
   - `backendBaseUrl`
3. Set `backendBaseUrl` to your reachable backend host:
   - Local web dev: `http://127.0.0.1:8000`
   - Physical device: `http://<your-lan-ip>:8000`

## Install dependencies

```bash
flutter pub get
```

## Run on Web

```bash
flutter run -d chrome
```

## Run on Android

```bash
flutter run -d android
```

## Build Web Release

```bash
flutter build web --release
```

## Features in this scaffold

- Supabase login and role-based session context (`Operator` / `System Administrator`)
- Live monitoring grid with camera state toggles (admin controls)
- Realtime incident sidebar with fade-in cards and hover glow effects
- False-positive update action on incidents
- Historical evidence table with date-range filtering
- Dark Mode Executive theme:
  - Background `#0F0F10`
  - Card surface `#1A1A1C`
  - Border `#2D2D2D`
  - Accent `#007BFF`

## Backend dependency

This frontend expects the backend endpoints from `backend_python/main.py`:

- `POST /cameras/{camera_id}/toggle`
- `GET /cameras`
- WebSocket stream: `/ws/detections` (for future direct feed overlays)

## Troubleshooting

- If auth works but profile role is null, ensure `public.users` has a row for your `auth.users.id`.
- If camera toggle fails, verify `backendBaseUrl` and CORS/network path.
- If incidents do not appear, verify:
  - Supabase realtime enabled for `public.incidents`
  - Backend uses valid `SUPABASE_SERVICE_ROLE_KEY`
