import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/analysis_history_provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/analysis_widgets.dart';
import 'analysis_service.dart';

Future<void> runAnalysisWorkflow(
  BuildContext context, {
  required bool isVideo,
}) async {
  final navigator = Navigator.of(context);
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final history = context.read<AnalysisHistoryProvider>();
  final incidentProvider = context.read<IncidentProvider>();
  final analysisService = AnalysisService();

  try {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const AnalyzingDialog(),
    );

    final picked = isVideo
        ? await analysisService.pickAndAnalyzeVideo()
        : await analysisService.pickAndAnalyzeImage();

    if (!context.mounted) return;
    navigator.pop();

    if (picked == null) return;
    if (!context.mounted) return;

    final kind = isVideo ? AnalysisKind.video : AnalysisKind.photo;
    history.addFromResults(kind, picked.results, sourceFileName: picked.fileName);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => AnalysisResultsSheet(results: picked.results),
    );

    if (!context.mounted) return;
    await incidentProvider.refresh(silentErrors: true);
  } catch (e) {
    if (context.mounted && navigator.canPop()) navigator.pop();
    if (context.mounted) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
