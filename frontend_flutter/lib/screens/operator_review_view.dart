import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident_model.dart';
import '../providers/incident_provider.dart';
import '../widgets/glass.dart';

/// Operator-only desk to validate real incidents or dismiss false alarms.
class OperatorReviewView extends StatelessWidget {
  const OperatorReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents.where((i) => !i.isFalsePositive).take(80).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Validate / dismiss alerts',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Validate confirms a genuine detection. Dismiss marks it as a false positive for records.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.white.withValues(alpha: 0.48)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: incidentProvider.loadError != null
                ? Center(
                    child: Text(
                      incidentProvider.loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 13),
                    ),
                  )
                : incidents.isEmpty
                    ? Center(
                        child: Text(
                          'No open alerts',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: incidents.length,
                        itemBuilder: (_, i) => _ReviewCard(incident: incidents[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.incident});

  final IncidentModel incident;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MMM d, HH:mm').format(incident.createdAt.toLocal());
    final validated = incident.operatorValidated;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.incidentType,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(incident.confidenceScore * 100).toStringAsFixed(1)}% · $dateText',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                      ),
                      if (validated)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 16, color: Colors.greenAccent.shade100),
                              const SizedBox(width: 6),
                              Text(
                                'Validated',
                                style: TextStyle(fontSize: 12, color: Colors.greenAccent.shade100),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: validated
                      ? null
                      : () => context.read<IncidentProvider>().validateOperatorIncident(incident.id),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Validate'),
                ),
                TextButton.icon(
                  onPressed: () => context.read<IncidentProvider>().markFalsePositive(incident.id),
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.orange.shade200),
                  label: Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.orange.shade200),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
