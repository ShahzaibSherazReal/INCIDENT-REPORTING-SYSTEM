import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission + enumeration + optional picker dialog. Returns `null` if cancelled / denied / none.
Future<CameraDescription?> pickDeviceCameraDescription(BuildContext context) async {
  final permitted = await ensureDeviceCameraPermission();
  if (!permitted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required for live preview.')),
      );
    }
    return null;
  }

  List<CameraDescription> cameras;
  try {
    cameras = await availableCameras();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access cameras: $e')),
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  if (cameras.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No cameras found on this device.')),
    );
    return null;
  }

  if (cameras.length == 1) return cameras.first;

  final picked = await showDialog<CameraDescription>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose camera'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in cameras)
              ListTile(
                leading: Icon(iconForLensDirection(c.lensDirection)),
                title: Text(deviceCameraDisplayLabel(c)),
                subtitle: c.name.isNotEmpty ? Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
      ],
    ),
  );
  return picked;
}

Future<bool> ensureDeviceCameraPermission() async {
  if (kIsWeb) return true;
  try {
    final status = await Permission.camera.request();
    return status.isGranted;
  } catch (_) {
    return true;
  }
}

IconData iconForLensDirection(CameraLensDirection d) {
  switch (d) {
    case CameraLensDirection.front:
      return Icons.camera_front_rounded;
    case CameraLensDirection.back:
      return Icons.camera_rear_rounded;
    case CameraLensDirection.external:
      return Icons.camera_outdoor_rounded;
  }
}

String deviceCameraDisplayLabel(CameraDescription c) {
  final lens = switch (c.lensDirection) {
    CameraLensDirection.front => 'Front',
    CameraLensDirection.back => 'Back',
    CameraLensDirection.external => 'External',
  };
  return '$lens camera';
}

/// Opens a full-screen live preview from **this** device's cameras (phone, laptop webcam in browser, etc.).
Future<void> showDeviceCameraLive(BuildContext context) async {
  final selected = await pickDeviceCameraDescription(context);
  if (selected == null || !context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => DeviceCameraLiveScreen.fromLens(selected),
    ),
  );
}

/// Full-screen preview: either a **new** controller from [CameraDescription], or **borrow** an existing one
/// (same hardware session — avoids black screen / glitch when expanding from the live grid).
class DeviceCameraLiveScreen extends StatefulWidget {
  const DeviceCameraLiveScreen._({
    super.key,
    this.camera,
    this.borrowedController,
  }) : assert(
          (camera != null && borrowedController == null) || (camera == null && borrowedController != null),
        );

  factory DeviceCameraLiveScreen.fromLens(CameraDescription camera) {
    return DeviceCameraLiveScreen._(camera: camera);
  }

  factory DeviceCameraLiveScreen.borrow(CameraController borrowedController) {
    return DeviceCameraLiveScreen._(borrowedController: borrowedController);
  }

  final CameraDescription? camera;
  final CameraController? borrowedController;

  @override
  State<DeviceCameraLiveScreen> createState() => _DeviceCameraLiveScreenState();
}

class _DeviceCameraLiveScreenState extends State<DeviceCameraLiveScreen> {
  CameraController? _controller;
  bool _ready = false;
  String? _error;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    final borrowed = widget.borrowedController;
    if (borrowed != null) {
      _ownsController = false;
      _controller = borrowed;
      _ready = borrowed.value.isInitialized;
      if (!_ready) {
        _error = 'Camera not ready.';
      }
    } else {
      _ownsController = true;
      _initFromLens();
    }
  }

  Future<void> _initFromLens() async {
    final desc = widget.camera;
    if (desc == null) return;
    final controller = CameraController(
      desc,
      // High preset causes noticeable lag on many phones; medium is a better default.
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  Widget _previewLayer(CameraController c) {
    final previewSize = c.value.previewSize;
    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          child: previewSize != null
              ? SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(c),
                )
              : AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: CameraPreview(c),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                  ],
                ),
              ),
            )
          : !_ready || _controller == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white54))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _previewLayer(_controller!),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
