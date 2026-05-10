import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/alert_sidebar.dart';
import '../widgets/evidence_logs_table.dart';
import '../widgets/live_monitoring_grid.dart';
import '../widgets/stream_toolbar.dart';

/// Live streams, evidence table, and real-time alerts (previous dashboard core).
class LiveOperationsView extends StatefulWidget {
  const LiveOperationsView({super.key});

  @override
  State<LiveOperationsView> createState() => _LiveOperationsViewState();
}

class _LiveOperationsViewState extends State<LiveOperationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CameraProvider>().loadCameras();
      context.read<IncidentProvider>().refresh(silentErrors: false);
    });
  }

  Future<void> _openDeviceCamera() => context.read<CameraProvider>().addLocalDeviceFeedFromPicker(context);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;
          return isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StreamToolbar(
                            onAddStream: () => showAddCameraSheet(context),
                            onOpenDeviceCamera: _openDeviceCamera,
                          ),
                          const SizedBox(height: 12),
                          const Expanded(flex: 3, child: LiveMonitoringGrid()),
                          const SizedBox(height: 14),
                          const Expanded(flex: 2, child: EvidenceLogsTable()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(flex: 1, child: AlertSidebar()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StreamToolbar(
                      onAddStream: () => showAddCameraSheet(context),
                      onOpenDeviceCamera: _openDeviceCamera,
                    ),
                    const SizedBox(height: 12),
                    const Expanded(child: LiveMonitoringGrid()),
                    const SizedBox(height: 14),
                    const Expanded(child: EvidenceLogsTable()),
                  ],
                );
        },
      ),
    );
  }
}
