import 'package:flutter/material.dart';

import 'glass.dart';

/// Gradient primary action button (video / photo pages).
class FabGlass extends StatelessWidget {
  const FabGlass({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.mini = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0xFF3B9EFF).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(mini ? 18 : 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(mini ? 18 : 20),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mini ? 18 : 20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4FA8FF), Color(0xFF2563C8)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x992563C8),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mini ? 12 : 22,
              vertical: mini ? 12 : 16,
            ),
            child: label == null
                ? Icon(icon, color: Colors.white, size: mini ? 22 : 26)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        label!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AnalyzingDialog extends StatelessWidget {
  const AnalyzingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulseLoader(size: 56),
            const SizedBox(height: 22),
            Text(
              'Analyzing',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Backend inference',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisResultsSheet extends StatelessWidget {
  const AnalysisResultsSheet({super.key, required this.results});

  final Map<String, dynamic> results;

  static double _confidencePct(Map<String, dynamic> d) {
    final v = (d['confidence'] as num?)?.toDouble() ?? 0;
    return v * 100;
  }

  @override
  Widget build(BuildContext context) {
    final detections = (results['detections'] as List?) ?? [];
    final count = results['detections_count'] as int? ?? detections.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: GlassPanel(
            borderRadius: 28,
            blurSigma: 18,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        'Detections',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassChip(
                        label: '$count',
                        accent: const Color(0xFF5BB0FF),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: detections.isEmpty
                      ? Center(
                          child: Text(
                            'No objects above threshold',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: detections.length,
                          itemBuilder: (context, index) {
                            final d = Map<String, dynamic>.from(detections[index] as Map);
                            final url = (d['snapshot_url'] ?? '').toString();
                            final pct = _confidencePct(d);
                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 280 + (index * 45).clamp(0, 400)),
                              tween: Tween(begin: 0, end: 1),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) {
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, 16 * (1 - t)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ResultRow(
                                  incidentType: '${d['incident_type']}',
                                  model: '${d['model']}',
                                  confidencePct: pct,
                                  imageUrl: url,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ResultRow extends StatelessWidget {
  const ResultRow({
    super.key,
    required this.incidentType,
    required this.model,
    required this.confidencePct,
    required this.imageUrl,
  });

  final String incidentType;
  final String model;
  final double confidencePct;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppChrome.radiusMd),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _thumb(imageUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidentType,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.center_focus_strong_outlined, size: 14, color: Colors.white.withValues(alpha: 0.45)),
                        const SizedBox(width: 4),
                        Text(
                          '${confidencePct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Color(0xFF7EC8FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          model,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return Image.network(
        u,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 76,
          height: 76,
          color: Colors.white.withValues(alpha: 0.06),
          child: Icon(Icons.broken_image_outlined, color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }
    return Container(
      width: 76,
      height: 76,
      color: Colors.white.withValues(alpha: 0.06),
      child: Icon(
        u.isEmpty ? Icons.hide_image_outlined : Icons.folder_open_outlined,
        color: Colors.white.withValues(alpha: 0.28),
      ),
    );
  }
}
