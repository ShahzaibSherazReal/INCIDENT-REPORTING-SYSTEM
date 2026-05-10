import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens a full-screen live preview from **this** device's cameras (phone, laptop webcam in browser, etc.).
/// If only one camera exists it starts immediately; otherwise the user picks which camera to use.
Future<void> showDeviceCameraLive(BuildContext context) async {
  final permitted = await _ensureCameraPermission();
  if (!permitted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required for live preview.')),
      );
    }
    return;
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
    return;
  }

  if (!context.mounted) return;
  if (cameras.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No cameras found on this device.')),
    );
    return;
  }

  final CameraDescription selected;
  if (cameras.length == 1) {
    selected = cameras.first;
  } else {
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
                  leading: Icon(_iconForLens(c.lensDirection)),
                  title: Text(_cameraTitle(c)),
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
    if (picked == null || !context.mounted) return;
    selected = picked;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _DeviceCameraLiveScreen(camera: selected),
    ),
  );
}

Future<bool> _ensureCameraPermission() async {
  if (kIsWeb) return true;
  try {
    final status = await Permission.camera.request();
    return status.isGranted;
  } catch (_) {
    return true;
  }
}

IconData _iconForLens(CameraLensDirection d) {
  switch (d) {
    case CameraLensDirection.front:
      return Icons.camera_front_rounded;
    case CameraLensDirection.back:
      return Icons.camera_rear_rounded;
    case CameraLensDirection.external:
      return Icons.camera_outdoor_rounded;
  }
}

String _cameraTitle(CameraDescription c) {
  final lens = switch (c.lensDirection) {
    CameraLensDirection.front => 'Front',
    CameraLensDirection.back => 'Back',
    CameraLensDirection.external => 'External',
  };
  return '$lens camera';
}

class _DeviceCameraLiveScreen extends StatefulWidget {
  const _DeviceCameraLiveScreen({required this.camera});

  final CameraDescription camera;

  @override
  State<_DeviceCameraLiveScreen> createState() => _DeviceCameraLiveScreenState();
}

class _DeviceCameraLiveScreenState extends State<_DeviceCameraLiveScreen> {
  CameraController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = CameraController(
      widget.camera,
      kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
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
    _controller?.dispose();
    super.dispose();
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
                    SizedBox.expand(
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ),
                    ),
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
