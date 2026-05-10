import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/incident_model.dart';
import 'glass.dart';

Future<void> showIncidentPreviewSheet(BuildContext context, IncidentModel incident) {
  final fmt = DateFormat('MMM d, yyyy · HH:mm');
  final url = incident.snapshotUrl.trim();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: GlassPanel(
            borderRadius: 26,
            blurSigma: 18,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.sensors_rounded, color: Colors.orange.shade200),
                    const SizedBox(width: 8),
                    Text(
                      'Live incident',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (url.startsWith('http://') || url.startsWith('https://'))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, color: Colors.white.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Text(
                      url.isEmpty ? 'No snapshot URL' : url,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ),
                const SizedBox(height: 18),
                _kv('Type', incident.incidentType),
                _kv('Confidence', '${(incident.confidenceScore * 100).toStringAsFixed(1)}%'),
                _kv('Camera ID', incident.cameraId),
                _kv('Time', fmt.format(incident.createdAt.toLocal())),
                if (incident.isFalsePositive)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Marked false positive',
                      style: TextStyle(color: Colors.green.shade200, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
