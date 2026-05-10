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
      cameras = await _databaseService.fetchCamerasFromBackend();
    } catch (e) {
      loadError = e.toString();
      try {
        cameras = await _databaseService.fetchCameras();
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

  /// Picks this device's camera (auto if one, dialog if many) and adds a grid tile (not saved on API).
  Future<void> addLocalDeviceFeedFromPicker(BuildContext context) async {
    final selected = await pickDeviceCameraDescription(context);
    if (selected == null || !context.mounted) return;
    localDeviceFeeds.add(
      LocalDeviceFeed(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        displayName: deviceCameraDisplayLabel(selected),
        camera: selected,
      ),
    );
    notifyListeners();
  }

  void removeLocalDeviceFeed(String id) {
    localDeviceFeeds.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
