import 'package:flutter/foundation.dart';

enum AnalysisKind { video, photo }

@immutable
class AnalysisHistoryEntry {
  const AnalysisHistoryEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.detectionCount,
    required this.resultsSnapshot,
    this.sourceFileName,
  });

  final String id;
  final DateTime at;
  final AnalysisKind kind;
  final int detectionCount;
  final Map<String, dynamic> resultsSnapshot;
  /// Original picked file name from the device (e.g. `clip.mp4`).
  final String? sourceFileName;
}

class AnalysisHistoryProvider extends ChangeNotifier {
  static const int _maxEntries = 80;

  final List<AnalysisHistoryEntry> _items = [];

  List<AnalysisHistoryEntry> recentAll() {
    final copy = [..._items]..sort((a, b) => b.at.compareTo(a.at));
    return copy;
  }

  List<AnalysisHistoryEntry> byKind(AnalysisKind kind) {
    return _items.where((e) => e.kind == kind).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  void addFromResults(
    AnalysisKind kind,
    Map<String, dynamic> results, {
    String? sourceFileName,
  }) {
    final detections = (results['detections'] as List?) ?? [];
    final count = results['detections_count'] as int? ?? detections.length;
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    _items.insert(
      0,
      AnalysisHistoryEntry(
        id: id,
        at: DateTime.now(),
        kind: kind,
        detectionCount: count,
        resultsSnapshot: Map<String, dynamic>.from(results),
        sourceFileName: sourceFileName,
      ),
    );
    while (_items.length > _maxEntries) {
      _items.removeLast();
    }
    notifyListeners();
  }

  void clearKind(AnalysisKind kind) {
    _items.removeWhere((e) => e.kind == kind);
    notifyListeners();
  }
}
