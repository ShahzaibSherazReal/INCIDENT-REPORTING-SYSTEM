import 'package:camera/camera.dart';

/// A live preview tile backed by this device's camera (capture & analyze from the Live grid).
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
