import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/camera_model.dart';
import '../models/local_device_feed.dart';
import '../providers/camera_provider.dart';
import 'glass.dart';

enum _AddStreamMode { url, device }

Future<void> showAddCameraSheet(BuildContext context) async {
  final nameCtl = TextEditingController(text: 'Feed 1');
  final urlCtl = TextEditingController();
  var mode = _AddStreamMode.url;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: mode == _AddStreamMode.url ? 0.58 : 0.42,
            minChildSize: 0.36,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) {
              final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: GlassPanel(
                  borderRadius: 26,
                  blurSigma: 18,
                  padding: EdgeInsets.zero,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(22, 16, 22, 22 + bottomInset),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Add to live feed',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('URL / server stream'),
                            selected: mode == _AddStreamMode.url,
                            onSelected: (_) => setModalState(() => mode = _AddStreamMode.url),
                          ),
                          ChoiceChip(
                            label: const Text('This device’s camera'),
                            selected: mode == _AddStreamMode.device,
                            onSelected: (_) => setModalState(() => mode = _AddStreamMode.device),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (mode == _AddStreamMode.url) ...[
                        Text(
                          'RTSP, file path, or camera index (0, 1, 2…) on the machine running FastAPI.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Built-in cameras (API server)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.4,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var idx = 0; idx <= 2; idx++)
                              ActionChip(
                                avatar: Icon(Icons.videocam_outlined, size: 18, color: Colors.white.withValues(alpha: 0.75)),
                                label: Text(
                                  idx == 0 ? 'Webcam · 0' : 'Camera · $idx',
                                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.88)),
                                ),
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                onPressed: () {
                                  nameCtl.text = idx == 0 ? 'Webcam' : 'Camera $idx';
                                  urlCtl.text = '$idx';
                                  setModalState(() {});
                                },
                              ),
                          ],
                        ),
                        if (kIsWeb)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'OpenCV uses cameras on the PC running Python — not the browser camera. '
                              'For this phone, use RTSP / IP Webcam URL or “This device’s camera”.',
                              style: TextStyle(fontSize: 11, height: 1.35, color: Colors.white.withValues(alpha: 0.36)),
                            ),
                          ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: nameCtl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: urlCtl,
                          decoration: const InputDecoration(
                            labelText: 'URL or index',
                            hintText: '0 · rtsp://… · C:/clip.mp4',
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: () async {
                            final name = nameCtl.text.trim();
                            final url = urlCtl.text.trim();
                            if (name.isEmpty || url.isEmpty) return;
                            try {
                              await ctx.read<CameraProvider>().addCamera(name: name, streamUrl: url);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            }
                          },
                          child: const Text('Save stream'),
                        ),
                      ] else ...[
                        Text(
                          'Adds a live preview tile from this phone or laptop. It stays on the device only '
                          '(not sent as a stream URL to the API). Use the URL tab for Railway / server feeds.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.48), fontSize: 13, height: 1.35),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () async {
                            await ctx.read<CameraProvider>().addLocalDeviceFeedFromPicker(ctx);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Add device camera to grid'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class LiveMonitoringGrid extends StatelessWidget {
  const LiveMonitoringGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final remoteCount = cameraProvider.cameras.length;
    final localCount = cameraProvider.localDeviceFeeds.length;
    final totalTiles = remoteCount + localCount;

    if (cameraProvider.isLoading) {
      return GlassPanel(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 16 / 10,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppChrome.radiusMd),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    if (cameraProvider.loadError != null && remoteCount == 0 && localCount == 0) {
      return _BackendHintCard(
        error: cameraProvider.loadError!,
        onRetry: () => cameraProvider.loadCameras(),
        onAdd: () => showAddCameraSheet(context),
      );
    }

    if (totalTiles == 0) {
      return _EmptyCameras(onAdd: () => showAddCameraSheet(context), onRefresh: () => cameraProvider.loadCameras());
    }

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cameraProvider.loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      cameraProvider.loadError!,
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 16 / 10,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: totalTiles,
              itemBuilder: (_, index) {
                if (index < remoteCount) {
                  final camera = cameraProvider.cameras[index];
                  return _CameraCard(
                    camera: camera,
                    onToggle: (value) => cameraProvider.toggle(camera.id, value),
                  );
                }
                final feed = cameraProvider.localDeviceFeeds[index - remoteCount];
                return _LocalDeviceCameraCard(
                  feed: feed,
                  onRemove: () => cameraProvider.removeLocalDeviceFeed(feed.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCameras extends StatelessWidget {
  const _EmptyCameras({required this.onAdd, required this.onRefresh});

  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(height: 16),
              Text(
                'No feeds',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use Add stream → URL/server feed, or This device’s camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.42), height: 1.4),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add stream')),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendHintCard extends StatelessWidget {
  const _BackendHintCard({
    required this.error,
    required this.onRetry,
    required this.onAdd,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.orange.shade200),
                  const SizedBox(width: 10),
                  Text(
                    'API offline',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(color: Colors.red.shade200, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Text(
                'Start FastAPI in backend_python, then retry.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.48), height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onAdd, child: const Text('Add anyway')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalDeviceCameraCard extends StatefulWidget {
  const _LocalDeviceCameraCard({
    required this.feed,
    required this.onRemove,
  });

  final LocalDeviceFeed feed;
  final VoidCallback onRemove;

  @override
  State<_LocalDeviceCameraCard> createState() => _LocalDeviceCameraCardState();
}

class _LocalDeviceCameraCardState extends State<_LocalDeviceCameraCard> {
  CameraController? _controller;
  bool _ready = false;
  bool _previewOn = true;

  @override
  void initState() {
    super.initState();
    if (_previewOn) _startPreview();
  }

  Future<void> _startPreview() async {
    final c = CameraController(
      widget.feed.camera,
      kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _ready = false);
    }
  }

  Future<void> _stopPreview() async {
    await _controller?.dispose();
    if (!mounted) return;
    setState(() {
      _controller = null;
      _ready = false;
    });
  }

  Future<void> _setPreviewOn(bool on) async {
    setState(() => _previewOn = on);
    if (on) {
      await _startPreview();
    } else {
      await _stopPreview();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppChrome.radiusMd),
        border: Border.all(color: const Color(0xFF7CBEFF).withValues(alpha: 0.45)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.feed.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'This device · local preview',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _previewOn,
                  activeThumbColor: const Color(0xFF5BB0FF),
                  onChanged: (v) => _setPreviewOn(v),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: Colors.white.withValues(alpha: 0.65)),
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: !_previewOn || !_ready || _controller == null
                    ? ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Text(
                            _previewOn ? 'Starting…' : 'Off',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: _previewOn ? 0.45 : 0.35),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    : ClipRect(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCard extends StatefulWidget {
  const _CameraCard({
    required this.camera,
    required this.onToggle,
  });

  final CameraModel camera;
  final Future<void> Function(bool value) onToggle;

  @override
  State<_CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<_CameraCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppChrome.radiusMd),
          border: Border.all(
            color: isHovering ? const Color(0xFF5BB0FF).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: isHovering
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563C8).withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
          color: Colors.white.withValues(alpha: isHovering ? 0.07 : 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.camera.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Switch.adaptive(
                    value: widget.camera.isActive,
                    activeThumbColor: const Color(0xFF5BB0FF),
                    onChanged: (value) => widget.onToggle(value),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.camera.streamUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: widget.camera.isActive ? 0.28 : 0.18),
                  ),
                  child: Text(
                    widget.camera.isActive ? 'Live' : 'Off',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: widget.camera.isActive ? 0.85 : 0.4),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
