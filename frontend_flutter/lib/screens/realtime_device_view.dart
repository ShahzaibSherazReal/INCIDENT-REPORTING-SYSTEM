import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
import '../services/app_config.dart';
import '../services/database_service.dart';
import '../widgets/device_camera_live.dart';
import '../widgets/glass.dart';

/// Device camera with continuous frames to the backend (YOLO + incidents).
/// Only starts the camera while [active] is true (IndexedStack sibling tabs stay idle).
class RealtimeDeviceView extends StatefulWidget {
  const RealtimeDeviceView({super.key, required this.active});

  final bool active;

  @override
  State<RealtimeDeviceView> createState() => _RealtimeDeviceViewState();
}

class _RealtimeDeviceViewState extends State<RealtimeDeviceView> {
  DatabaseService? _databaseService;
  CameraController? _controller;
  Timer? _timer;
  String? _backendCameraId;
  String? _bootstrapError;
  bool _initializing = false;
  bool _streaming = true;
  bool _uploadBusy = false;
  String _statusLine = 'Starting…';
  List<Map<String, dynamic>> _lastDetections = [];
  DateTime? _lastSnackAt;
  CameraDescription? _lens;

  @override
  void didUpdateWidget(RealtimeDeviceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onTabBecameVisible());
    }
    if (!widget.active && oldWidget.active) {
      unawaited(_onTabHidden());
    }
  }

  Future<void> _onTabBecameVisible() async {
    if (!mounted || !widget.active) return;
    if (_controller != null || _initializing) return;
    await _bootstrapPreferredLens();
  }

  Future<void> _onTabHidden() async {
    _stopTimer();
    await _stopSession(deleteBackendRow: true);
    if (mounted) {
      setState(() {
        _bootstrapError = null;
        _lastDetections = [];
        _statusLine = 'Starting…';
        _initializing = false;
      });
    }
  }

  Future<void> _bootstrapPreferredLens() async {
    if (!mounted || !widget.active) return;
    final permitted = await ensureDeviceCameraPermission();
    if (!mounted || !widget.active) return;
    if (!permitted) {
      setState(() {
        _bootstrapError = 'Camera permission denied.';
        _initializing = false;
      });
      return;
    }
    List<CameraDescription> cams;
    try {
      cams = await availableCameras();
    } catch (e) {
      if (mounted && widget.active) {
        setState(() {
          _bootstrapError = '$e';
          _initializing = false;
        });
      }
      return;
    }
    if (!mounted || !widget.active) return;
    if (cams.isEmpty) {
      setState(() {
        _bootstrapError = 'No cameras found.';
        _initializing = false;
      });
      return;
    }
    final lens = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    await _startSession(lens);
  }

  Future<void> _stopSession({required bool deleteBackendRow}) async {
    _stopTimer();
    final c = _controller;
    final id = _backendCameraId;
    final db = _databaseService;
    if (mounted) {
      setState(() {
        _controller = null;
        _backendCameraId = null;
      });
    } else {
      _controller = null;
      _backendCameraId = null;
    }
    await c?.dispose();
    if (deleteBackendRow && id != null && db != null) {
      try {
        await db.deleteCameraOnBackend(id);
      } catch (_) {}
    }
  }

  Future<void> _startSession(CameraDescription lens) async {
    final db = _databaseService;
    if (db == null || !mounted || !widget.active) return;

    setState(() {
      _initializing = true;
      _bootstrapError = null;
      _statusLine = 'Connecting…';
    });

    await _stopSession(deleteBackendRow: true);

    final feedId = 'rt-${DateTime.now().millisecondsSinceEpoch}';
    String backendId;
    try {
      backendId = await db.createCameraOnBackend(
        name: 'Realtime AI',
        streamUrl: 'device://$feedId',
        isActive: false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _bootstrapError = 'Could not register on server: $e';
        });
      }
      return;
    }

    final controller = CameraController(
      lens,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      try {
        await db.deleteCameraOnBackend(backendId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _initializing = false;
          _bootstrapError = '$e';
        });
      }
      return;
    }

    if (!mounted || !widget.active) {
      await controller.dispose();
      try {
        await db.deleteCameraOnBackend(backendId);
      } catch (_) {}
      return;
    }

    setState(() {
      _controller = controller;
      _backendCameraId = backendId;
      _lens = lens;
      _initializing = false;
      _streaming = true;
      _lastDetections = [];
      _statusLine = 'Live · AI scanning';
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: AppConfig.realtimeFrameIntervalMs),
      (_) => _pushFrame(),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pushFrame() async {
    if (!widget.active || !_streaming || _uploadBusy || !mounted) return;
    final c = _controller;
    final id = _backendCameraId;
    final db = _databaseService;
    if (c == null || id == null || db == null || !c.value.isInitialized) return;

    _uploadBusy = true;
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted || !widget.active) return;

      final map = await db.uploadDeviceCameraFrame(cameraId: id, imageBytes: bytes);
      if (!mounted || !widget.active) return;

      if (map['skipped'] == true) return;

      final emitted = (map['detections_emitted'] as num?)?.toInt() ?? 0;
      final raw = map['detections'];
      final detections = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            detections.add(Map<String, dynamic>.from(e as Map));
          }
        }
      }

      if (emitted > 0) {
        setState(() {
          _lastDetections = detections;
          _statusLine = 'Alert · $emitted new detection(s)';
        });
        unawaited(context.read<IncidentProvider>().refresh(silentErrors: true));

        final now = DateTime.now();
        if (_lastSnackAt == null || now.difference(_lastSnackAt!) > const Duration(seconds: 5)) {
          _lastSnackAt = now;
          final types = detections.map((d) => d['incident_type']?.toString() ?? '?').toSet().join(', ');
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('Detected: $types')),
          );
        }
      } else if (mounted && _streaming) {
        setState(() => _statusLine = 'Live · AI scanning');
      }
    } catch (_) {
      if (mounted) setState(() => _statusLine = 'Network error · retrying…');
    } finally {
      _uploadBusy = false;
    }
  }

  Future<void> _pickAnotherLens(BuildContext context) async {
    final picked = await pickDeviceCameraDescription(context);
    if (picked == null || !mounted || !widget.active) return;
    setState(() => _initializing = true);
    await _startSession(picked);
  }

  Future<void> _retryBootstrap() async {
    setState(() {
      _bootstrapError = null;
      _initializing = true;
    });
    if (_lens != null) {
      await _startSession(_lens!);
    } else {
      await _bootstrapPreferredLens();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    final c = _controller;
    final id = _backendCameraId;
    final db = _databaseService;
    _controller = null;
    _backendCameraId = null;
    c?.dispose();
    if (id != null && db != null) {
      unawaited(db.deleteCameraOnBackend(id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _databaseService ??= context.read<DatabaseService>();

    if (!widget.active) {
      return const SizedBox.shrink();
    }

    if (_bootstrapError != null && _controller == null && !_initializing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: GlassPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.orange.shade200, size: 40),
                const SizedBox(height: 14),
                Text(
                  _bootstrapError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.35),
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: _retryBootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if ((_initializing || _controller == null) && _bootstrapError == null) {
      return const Center(child: PulseLoader(size: 52));
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: PulseLoader(size: 52));
    }

    final previewSize = c.value.previewSize;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fire, smoke, weapons, falls, and PPE issues are detected on the server as frames arrive.',
                  style: TextStyle(fontSize: 12, height: 1.35, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
              IconButton(
                tooltip: 'Switch camera',
                onPressed: () => _pickAnotherLens(context),
                icon: Icon(Icons.cameraswitch_rounded, color: Colors.white.withValues(alpha: 0.75)),
              ),
              IconButton(
                tooltip: _streaming ? 'Pause detection' : 'Resume',
                onPressed: () {
                  setState(() => _streaming = !_streaming);
                  if (_streaming) {
                    _startTimer();
                  } else {
                    _stopTimer();
                    setState(() => _statusLine = 'Paused');
                  }
                },
                icon: Icon(
                  _streaming ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_lastDetections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade200),
                        const SizedBox(width: 8),
                        Text(
                          'Latest detections',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _lastDetections = []),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final d in _lastDetections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${d['incident_type']} · ${(((d['confidence_score'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.82)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.black,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.center,
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
                        child: Row(
                          children: [
                            Icon(
                              _streaming ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                              size: 14,
                              color: _streaming ? Colors.redAccent.shade100 : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusLine,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
