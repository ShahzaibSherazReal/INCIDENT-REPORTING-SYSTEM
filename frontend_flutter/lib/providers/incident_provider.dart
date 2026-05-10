import 'dart:async';

import 'package:flutter/material.dart';

import '../models/incident_model.dart';
import '../services/database_service.dart';

class IncidentProvider extends ChangeNotifier {
  IncidentProvider(this._databaseService) {
    refresh(silentErrors: false);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh(silentErrors: true));
  }

  final DatabaseService _databaseService;
  Timer? _timer;

  final List<IncidentModel> _incidents = [];
  bool isLoading = true;
  String? loadError;

  List<IncidentModel> get incidents => List.unmodifiable(_incidents);

  Future<void> refresh({bool silentErrors = false}) async {
    try {
      final list = await _databaseService.fetchIncidentsFromBackend();
      loadError = null;
      _incidents
        ..clear()
        ..addAll(list);
    } catch (e) {
      loadError = e.toString();
      if (!silentErrors) debugPrint('[IncidentProvider] $e');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> markFalsePositive(String incidentId) async {
    await _databaseService.markFalsePositive(incidentId);
    await refresh(silentErrors: true);
  }

  Future<List<IncidentModel>> fetchByDate({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final all = await _databaseService.fetchIncidentsFromBackend(limit: 500);
      return all.where((incident) {
        final afterStart = from == null || !incident.createdAt.isBefore(from);
        final beforeEnd = to == null || !incident.createdAt.isAfter(to);
        return afterStart && beforeEnd;
      }).toList();
    } catch (_) {
      return _databaseService.fetchIncidents(from: from, to: to);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
