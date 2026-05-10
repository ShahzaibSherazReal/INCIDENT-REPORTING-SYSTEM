import 'package:camera/camera.dart';

/// A live tile backed by this device's camera (not persisted on FastAPI).
class LocalDeviceFeed {
  LocalDeviceFeed({
    required this.id,
    required this.displayName,
    required this.camera,
  });

  final String id;
  final String displayName;
  final CameraDescription camera;
}
