import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/camera_model.dart';
import '../models/incident_model.dart';
import 'app_config.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Primary path for dashboard: FastAPI + service role (works for guest mode).
  Future<List<CameraModel>> fetchCamerasFromBackend() async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Backend /cameras ${response.statusCode}: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => CameraModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<IncidentModel>> fetchIncidentsFromBackend({int limit = 200}) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/incidents?limit=$limit');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Backend /incidents ${response.statusCode}: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => IncidentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<String> createCameraOnBackend({
    required String name,
    required String streamUrl,
    bool isActive = true,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'stream_url': streamUrl,
        'is_active': isActive,
      }),
    );
    if (response.statusCode >= 300) {
      throw Exception('Create camera failed: ${response.statusCode} ${response.body}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Create camera response missing id');
    }
    return id;
  }

  /// Sends one JPEG for server-side detection (live phone camera).
  Future<Map<String, dynamic>> uploadDeviceCameraFrame({
    required String cameraId,
    required List<int> imageBytes,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras/$cameraId/device-frame');
    final request = http.MultipartRequest('POST', url)
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'frame.jpg'),
      );
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString().timeout(const Duration(seconds: 90));
    if (streamed.statusCode >= 300) {
      throw Exception('device-frame ${streamed.statusCode}: $body');
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  Future<List<CameraModel>> fetchCameras() async {
    final rows = await _client.from('cameras').select().order('name');
    return rows.map((row) => CameraModel.fromJson(row)).toList();
  }

  Future<List<IncidentModel>> fetchIncidents({
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _client.from('incidents').select().order('created_at', ascending: false);
    final incidents = rows.map((row) => IncidentModel.fromJson(row)).toList();
    return incidents.where((incident) {
      final afterStart = from == null || !incident.createdAt.isBefore(from);
      final beforeEnd = to == null || !incident.createdAt.isAfter(to);
      return afterStart && beforeEnd;
    }).toList();
  }

  Stream<IncidentModel> subscribeToIncidents() {
    return _client
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.first)
        .map((row) => IncidentModel.fromJson(row));
  }

  Stream<List<IncidentModel>> incidentsFeed() {
    return _client
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => IncidentModel.fromJson(row)).toList());
  }

  Future<void> markFalsePositive(String incidentId) async {
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/incidents/$incidentId/false-positive');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'is_false_positive': true}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return;
    } catch (_) {}
    await _client.from('incidents').update({'is_false_positive': true}).eq('id', incidentId);
  }

  Future<void> toggleCamera({
    required String cameraId,
    required bool isActive,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras/$cameraId/toggle');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_active': isActive}),
    );
    if (response.statusCode >= 300) {
      throw Exception('Failed to toggle camera: ${response.body}');
    }
  }
}
