import 'package:flutter/material.dart';

import '../models/camera_model.dart';
import '../services/database_service.dart';

class CameraProvider extends ChangeNotifier {
  CameraProvider(this._databaseService) {
    loadCameras();
  }

  final DatabaseService _databaseService;
  bool isLoading = false;
  String? loadError;
  List<CameraModel> cameras = [];

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
}
