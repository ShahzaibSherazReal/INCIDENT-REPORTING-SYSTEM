import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident_model.dart';
import '../providers/incident_provider.dart';
import 'glass.dart';

class EvidenceLogsTable extends StatefulWidget {
  const EvidenceLogsTable({super.key});

  @override
  State<EvidenceLogsTable> createState() => _EvidenceLogsTableState();
}

class _EvidenceLogsTableState extends State<EvidenceLogsTable> {
  DateTimeRange? _range;
  List<IncidentModel> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _rows = context.read<IncidentProvider>().incidents;
  }

  Future<void> _pickRange() async {
    final incidentProvider = context.read<IncidentProvider>();
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
    if (selected == null) return;
    setState(() {
      _range = selected;
      _loading = true;
    });
    final items = await incidentProvider.fetchByDate(from: selected.start, to: selected.end);
    if (!mounted) return;
    setState(() {
      _rows = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().incidents;
    final source = _range == null ? incidents : _rows;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.table_chart_outlined, size: 18, color: Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 8),
                  Text(
                    'Evidence',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _pickRange,
                icon: Icon(Icons.date_range_rounded, size: 18, color: Colors.white.withValues(alpha: 0.65)),
                label: Text(
                  _range == null
                      ? 'Date range'
                      : '${DateFormat('MMM d').format(_range!.start)} — ${DateFormat('MMM d').format(_range!.end)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: PulseLoader(size: 44))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.white.withValues(alpha: 0.06),
                          dataTableTheme: DataTableThemeData(
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            dataTextStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 42,
                          horizontalMargin: 12,
                          columns: const [
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Camera')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Conf.')),
                            DataColumn(label: Text('FP')),
                          ],
                          rows: source
                              .map(
                                (item) => DataRow(
                                  cells: [
                                    DataCell(Text(DateFormat('MMM d, HH:mm').format(item.createdAt.toLocal()))),
                                    DataCell(Text(item.cameraId, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                                    DataCell(Text(item.incidentType)),
                                    DataCell(Text('${(item.confidenceScore * 100).toStringAsFixed(1)}%')),
                                    DataCell(
                                      Icon(
                                        item.isFalsePositive ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        size: 18,
                                        color: item.isFalsePositive
                                            ? const Color(0xFF81C784)
                                            : Colors.white.withValues(alpha: 0.22),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
