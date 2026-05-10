import 'package:flutter/material.dart';

class StreamToolbar extends StatelessWidget {
  const StreamToolbar({
    super.key,
    required this.onAddStream,
    required this.onOpenDeviceCamera,
  });

  final VoidCallback onAddStream;
  /// Opens this device's camera (phone / laptop webcam) with live preview.
  final VoidCallback onOpenDeviceCamera;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onAddStream,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B9EFF).withValues(alpha: 0.22),
                    const Color(0xFF3B9EFF).withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: const Color(0xFF3B9EFF).withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_link_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Text(
                      'Add stream',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Adds this device’s camera as a tile in the live grid (same as Add stream → This device’s camera).',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpenDeviceCamera,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, size: 20, color: Colors.white.withValues(alpha: 0.88)),
                      const SizedBox(width: 8),
                      Text(
                        'Device camera',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
