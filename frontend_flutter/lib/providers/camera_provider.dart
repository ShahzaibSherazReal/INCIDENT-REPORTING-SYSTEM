import 'package:flutter/material.dart';

import '../models/camera_model.dart';
import '../models/local_device_feed.dart';
import '../services/database_service.dart';
import '../widgets/device_camera_live.dart';

class CameraProvider extends ChangeNotifier {
  CameraProvider(this._databaseService) {
    loadCameras();
  }

  final DatabaseService _databaseService;
  bool isLoading = false;
  String? loadError;
  List<CameraModel> cameras = [];
  List<LocalDeviceFeed> localDeviceFeeds = [];

  Future<void> loadCameras() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      cameras = (await _databaseService.fetchCamerasFromBackend())
          .where((c) => !c.streamUrl.startsWith('device://'))
          .toList();
    } catch (e) {
      loadError = e.toString();
      try {
        cameras = (await _databaseService.fetchCameras())
            .where((c) => !c.streamUrl.startsWith('device://'))
            .toList();
      } catch (_) {
        cameras = [];
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggle(String cameraId, bool isActive) async {
    await _databaseService.toggleCamera(cameraId: cameraId, isActive: isActive);
    cameras = cameras
        .map((camera) => camera.id == cameraId ? camera.copyWith(isActive: isActive) : camera)
        .toList();
    notifyListeners();
  }

  Future<void> addCamera({required String name, required String streamUrl, bool isActive = true}) async {
    await _databaseService.createCameraOnBackend(name: name, streamUrl: streamUrl, isActive: isActive);
    await loadCameras();
  }

  Future<void> uploadDeviceCameraFrame(String backendCameraId, List<int> jpegBytes) async {
    await _databaseService.uploadDeviceCameraFrame(cameraId: backendCameraId, imageBytes: jpegBytes);
  }

  /// Picks this device's camera (auto if one, dialog if many) and adds a grid tile.
  /// Registers `device://…` on the backend so frames can be analyzed without a stream URL.
  Future<void> addLocalDeviceFeedFromPicker(BuildContext context) async {
    final selected = await pickDeviceCameraDescription(context);
    if (selected == null || !context.mounted) return;
    final feedId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final displayName = deviceCameraDisplayLabel(selected);
    String? backendCameraId;
    try {
      backendCameraId = await _databaseService.createCameraOnBackend(
        name: displayName,
        streamUrl: 'device://$feedId',
        isActive: false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Live AI unavailable (camera not registered): $e')),
        );
      }
    }
    localDeviceFeeds.add(
      LocalDeviceFeed(
        id: feedId,
        displayName: displayName,
        camera: selected,
        backendCameraId: backendCameraId,
      ),
    );
    notifyListeners();
  }

  void removeLocalDeviceFeed(String id) {
    localDeviceFeeds.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
