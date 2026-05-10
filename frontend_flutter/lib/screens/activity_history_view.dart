import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident_model.dart';
import '../providers/analysis_history_provider.dart';
import '../providers/incident_provider.dart';
import '../util/date_range_filter.dart';
import '../widgets/analysis_widgets.dart';
import '../widgets/filter_bar_widgets.dart';
import '../widgets/glass.dart';
import '../widgets/incident_preview_sheet.dart';

enum ActivityKindFilter { all, video, photo, live }

class _MergedActivityRow {
  _MergedActivityRow.analysis(this.analysis) : incident = null;
  _MergedActivityRow.live(this.incident) : analysis = null;

  final AnalysisHistoryEntry? analysis;
  final IncidentModel? incident;

  DateTime get time => analysis?.at ?? incident!.createdAt;
  bool get isLive => incident != null;
}

/// Timeline: uploads + live incidents, with kind + date filters.
class ActivityHistoryView extends StatefulWidget {
  const ActivityHistoryView({super.key});

  @override
  State<ActivityHistoryView> createState() => _ActivityHistoryViewState();
}

class _ActivityHistoryViewState extends State<ActivityHistoryView> {
  ActivityKindFilter _kind = ActivityKindFilter.all;
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

  List<_MergedActivityRow> _buildMerged(
    AnalysisHistoryProvider history,
    IncidentProvider incidents,
  ) {
    final rows = <_MergedActivityRow>[];
    for (final e in history.recentAll()) {
      rows.add(_MergedActivityRow.analysis(e));
    }
    for (final i in incidents.incidents) {
      rows.add(_MergedActivityRow.live(i));
    }
    rows.sort((a, b) => b.time.compareTo(a.time));
    return rows;
  }

  Iterable<_MergedActivityRow> _applyFilters(List<_MergedActivityRow> rows) {
    Iterable<_MergedActivityRow> r = rows;
    switch (_kind) {
      case ActivityKindFilter.video:
        r = r.where((x) => x.analysis?.kind == AnalysisKind.video);
        break;
      case ActivityKindFilter.photo:
        r = r.where((x) => x.analysis?.kind == AnalysisKind.photo);
        break;
      case ActivityKindFilter.live:
        r = r.where((x) => x.isLive);
        break;
      case ActivityKindFilter.all:
        break;
    }
    if (_range != null) {
      final range = _range!;
      r = r.where((x) => isDateInRange(x.time, range));
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy · HH:mm');
    final history = context.watch<AnalysisHistoryProvider>();
    final incidents = context.watch<IncidentProvider>();

    final merged = _buildMerged(history, incidents);
    final filtered = _applyFilters(merged).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              DateRangeFilterButton(
                range: _range,
                onPick: _pickRange,
                onClear: () => setState(() => _range = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _kindChip('All', ActivityKindFilter.all),
                _kindChip('Video', ActivityKindFilter.video),
                _kindChip('Photo', ActivityKindFilter.photo),
                _kindChip('Live', ActivityKindFilter.live),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap a row for details',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.42)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? GlassPanel(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        merged.isEmpty
                            ? 'No activity yet — run Video/Photo AI or wait for live detections'
                            : 'Nothing matches these filters',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = filtered[index];
                      if (row.isLive) {
                        final i = row.incident!;
                        return _liveTile(context, i, dateFmt);
                      }
                      final e = row.analysis!;
                      final isVideo = e.kind == AnalysisKind.video;
                      final color = isVideo ? const Color(0xFF7C6CF9) : const Color(0xFF4FC29D);
                      final name = e.sourceFileName ?? (isVideo ? 'Video' : 'Photo');
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppChrome.radiusMd),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black.withValues(alpha: 0.45),
                            builder: (ctx) => AnalysisResultsSheet(results: e.resultsSnapshot),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppChrome.radiusMd),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: color.withValues(alpha: 0.2),
                                    ),
                                    child: Icon(
                                      isVideo ? Icons.movie_outlined : Icons.image_outlined,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${e.detectionCount} detection${e.detectionCount == 1 ? '' : 's'} · ${dateFmt.format(e.at.toLocal())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.28)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(String label, ActivityKindFilter value) {
    final sel = _kind == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _kind = value),
        selectedColor: const Color(0xFF3B9EFF).withValues(alpha: 0.35),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: sel ? Colors.white : Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side: BorderSide(color: Colors.white.withValues(alpha: sel ? 0.35 : 0.14)),
      ),
    );
  }

  Widget _liveTile(BuildContext context, IncidentModel i, DateFormat dateFmt) {
    const color = Color(0xFFFFB74D);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppChrome.radiusMd),
        onTap: () => showIncidentPreviewSheet(context, i),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppChrome.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withValues(alpha: 0.2),
                  ),
                  child: const Icon(Icons.sensors_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live · ${i.incidentType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(i.confidenceScore * 100).toStringAsFixed(1)}% · cam ${i.cameraId} · ${dateFmt.format(i.createdAt.toLocal())}',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.28)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
