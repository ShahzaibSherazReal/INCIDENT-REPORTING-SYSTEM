import 'package:flutter/material.dart';

/// True when [at] falls on a calendar day inside [range] (local time).
bool isDateInRange(DateTime at, DateTimeRange range) {
  final local = at.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  return !d.isBefore(start) && !d.isAfter(end);
}
