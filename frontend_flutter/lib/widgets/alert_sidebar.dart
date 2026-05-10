import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident_model.dart';
import '../providers/incident_provider.dart';
import 'glass.dart';

class AlertSidebar extends StatelessWidget {
  const AlertSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents.take(20).toList();

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 18, color: Colors.white.withValues(alpha: 0.65)),
              const SizedBox(width: 8),
              Text(
                'Alerts',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.4,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          if (incidentProvider.loadError != null) ...[
            const SizedBox(height: 10),
            Text(
              incidentProvider.loadError!,
              style: TextStyle(color: Colors.orange.shade200, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: incidents.isEmpty
                ? Center(
                    child: Text(
                      'Nothing yet',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: incidents.length,
                    itemBuilder: (_, index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + index * 28),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: _AlertTile(incident: incidents[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatefulWidget {
  const _AlertTile({required this.incident});
  final IncidentModel incident;

  @override
  State<_AlertTile> createState() => _AlertTileState();
}

Widget _snapshotPreview(String url) {
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return Image.network(
      u,
      height: 96,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 72,
        color: Colors.black.withValues(alpha: 0.35),
        child: Icon(Icons.broken_image_outlined, color: Colors.white.withValues(alpha: 0.28)),
      ),
    );
  }
  return Container(
    height: 56,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    color: Colors.black.withValues(alpha: 0.25),
    child: Icon(Icons.link_off_rounded, size: 20, color: Colors.white.withValues(alpha: 0.28)),
  );
}

class _AlertTileState extends State<_AlertTile> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MMM d · HH:mm').format(widget.incident.createdAt.toLocal());
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isHovering ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(AppChrome.radiusSm),
          border: Border.all(
            color: isHovering ? const Color(0xFF5BB0FF).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.09),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.incident.snapshotUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _snapshotPreview(widget.incident.snapshotUrl),
              ),
            const SizedBox(height: 10),
            Text(
              widget.incident.incidentType,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${(widget.incident.confidenceScore * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF7EC8FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  ' · $dateText',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.incident.isFalsePositive
                    ? null
                    : () => context.read<IncidentProvider>().markFalsePositive(widget.incident.id),
                child: Text(
                  'False positive',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.incident.isFalsePositive
                        ? Colors.white.withValues(alpha: 0.28)
                        : const Color(0xFFFFB74D),
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
