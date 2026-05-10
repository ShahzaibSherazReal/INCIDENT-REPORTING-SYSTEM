import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/analysis_history_provider.dart';
import '../services/analysis_flow.dart';
import '../util/date_range_filter.dart';
import '../widgets/analysis_widgets.dart';
import '../widgets/filter_bar_widgets.dart';
import '../widgets/glass.dart';

class PhotoAnalyzeView extends StatefulWidget {
  const PhotoAnalyzeView({super.key});

  @override
  State<PhotoAnalyzeView> createState() => _PhotoAnalyzeViewState();
}

class _PhotoAnalyzeViewState extends State<PhotoAnalyzeView> {
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B9EFF),
              surface: Color(0xFF121820),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    setState(() => _range = selected);
  }

  List<AnalysisHistoryEntry> _filterByDate(List<AnalysisHistoryEntry> items) {
    if (_range == null) return items;
    return items.where((e) => isDateInRange(e.at, _range!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy · HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4FC29D).withValues(alpha: 0.45),
                            const Color(0xFF4FC29D).withValues(alpha: 0.14),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photo intelligence',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Still frame · dual models',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Center(
                  child: FabGlass(
                    icon: Icons.add_photo_alternate_rounded,
                    label: 'Choose image',
                    onPressed: () => runAnalysisWorkflow(context, isVideo: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Recent runs',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const Spacer(),
              DateRangeFilterButton(
                range: _range,
                onPick: _pickRange,
                onClear: () => setState(() => _range = null),
              ),
              TextButton(
                onPressed: () => context.read<AnalysisHistoryProvider>().clearKind(AnalysisKind.photo),
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Consumer<AnalysisHistoryProvider>(
            builder: (context, h, _) {
              final all = h.byKind(AnalysisKind.photo);
              final items = _filterByDate(all);
              if (all.isEmpty) {
                return GlassPanel(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: Center(
                    child: Text(
                      'No photo analyses yet',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
                    ),
                  ),
                );
              }
              if (items.isEmpty) {
                return GlassPanel(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Center(
                    child: Text(
                      'No runs in this date range',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
                    ),
                  ),
                );
              }
              return Column(
                children: items.map((e) {
                  final label = e.sourceFileName ?? 'Image file';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PhotoHistoryTile(
                      fileLabel: label,
                      detectionCount: e.detectionCount,
                      dateLine: dateFmt.format(e.at.toLocal()),
                      onOpen: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        barrierColor: Colors.black.withValues(alpha: 0.45),
                        builder: (ctx) => AnalysisResultsSheet(results: e.resultsSnapshot),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoHistoryTile extends StatelessWidget {
  const _PhotoHistoryTile({
    required this.fileLabel,
    required this.detectionCount,
    required this.dateLine,
    required this.onOpen,
  });

  final String fileLabel;
  final int detectionCount;
  final String dateLine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final countLabel =
        '$detectionCount detection${detectionCount == 1 ? '' : 's'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppChrome.radiusMd),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppChrome.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.image_outlined, color: const Color(0xFF4FC29D).withValues(alpha: 0.95)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$countLabel · $dateLine',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.48)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white.withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
