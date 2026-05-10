import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/camera_model.dart';
import '../providers/camera_provider.dart';
import 'glass.dart';

Future<void> showAddCameraSheet(BuildContext context) async {
  final nameCtl = TextEditingController(text: 'Feed 1');
  final urlCtl = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.38,
        maxChildSize: 0.9,
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
                    'New stream',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RTSP, file path, or a camera index (0, 1, 2…) on the machine running FastAPI.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Built-in cameras (API PC)',
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
                          },
                        ),
                    ],
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'OpenCV opens cameras on the PC running Python — not the browser’s camera. '
                        'Use this PC’s webcam when Chrome and FastAPI are on the same machine; '
                        'for a phone, enter an RTSP / IP Webcam URL instead.',
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
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
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

    if (cameraProvider.loadError != null && cameraProvider.cameras.isEmpty) {
      return _BackendHintCard(
        error: cameraProvider.loadError!,
        onRetry: () => cameraProvider.loadCameras(),
        onAdd: () => showAddCameraSheet(context),
      );
    }

    if (cameraProvider.cameras.isEmpty) {
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
              itemCount: cameraProvider.cameras.length,
              itemBuilder: (_, index) {
                final camera = cameraProvider.cameras[index];
                return _CameraCard(
                  camera: camera,
                  onToggle: (value) => cameraProvider.toggle(camera.id, value),
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
                'Add a stream from the toolbar.',
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
