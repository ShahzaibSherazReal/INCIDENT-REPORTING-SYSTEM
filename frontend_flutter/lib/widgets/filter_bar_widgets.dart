import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact date-range filter control for lists.
class DateRangeFilterButton extends StatelessWidget {
  const DateRangeFilterButton({
    super.key,
    required this.range,
    required this.onPick,
    required this.onClear,
  });

  final DateTimeRange? range;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    final label = range == null
        ? 'Date filter'
        : range!.start.year == range!.end.year &&
                range!.start.month == range!.end.month &&
                range!.start.day == range!.end.day
            ? fmt.format(range!.start)
            : '${fmt.format(range!.start)} — ${fmt.format(range!.end)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onPick,
          icon: Icon(Icons.date_range_rounded, size: 18, color: Colors.white.withValues(alpha: 0.65)),
          label: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Clear dates',
            icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.45)),
            onPressed: onClear,
          ),
      ],
    );
  }
}
