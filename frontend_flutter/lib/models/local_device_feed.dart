import 'package:camera/camera.dart';

/// A live tile backed by this device's camera.
///
/// [backendCameraId] is the FastAPI/Supabase camera row (`stream_url` starts with `device://`);
/// used to POST frames for YOLO detection. Null if registration failed.
class LocalDeviceFeed {
  LocalDeviceFeed({
    required this.id,
    required this.displayName,
    required this.camera,
    this.backendCameraId,
  });

  final String id;
  final String displayName;
  final CameraDescription camera;
  final String? backendCameraId;
}
