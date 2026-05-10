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

  Future<void> deleteCameraOnBackend(String cameraId) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras/$cameraId');
    final response = await http.delete(url);
    if (response.statusCode >= 300 && response.statusCode != 404) {
      throw Exception('Delete camera failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Phone realtime stream → same pipeline as server ingest (`device://` cameras).
  Future<Map<String, dynamic>> uploadDeviceCameraFrame({
    required String cameraId,
    required List<int> imageBytes,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/cameras/$cameraId/device-frame');
    final request = http.MultipartRequest('POST', url)
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'frame.jpg'));
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString().timeout(const Duration(seconds: 120));
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

  Future<void> validateOperatorIncident(String incidentId, {bool validated = true}) async {
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/incidents/$incidentId/operator-validate');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'operator_validated': validated}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return;
    } catch (_) {}
    await _client.from('incidents').update({'operator_validated': validated}).eq('id', incidentId);
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

  Map<String, String> _staffTierHeaders(String tier) => {'X-AIRS-Built-In-Tier': tier};

  /// Explains 404: Manage panel hits `/admin/*` on BACKEND_URL; old Railway builds omit those routes.
  Never _throwStaffApiFailure(String label, http.Response response) {
    final base = AppConfig.backendBaseUrl;
    final code = response.statusCode;
    final body = response.body;
    if (code == 404) {
      throw Exception(
        '$label: 404 Not Found — server par `/admin/*` routes register nahi (purani backend deploy?). '
        'Fix: latest `backend_python` Railway par redeploy karo, ya local: '
        '`flutter run --dart-define=BACKEND_URL=http://localhost:8000` + uvicorn. '
        'BACKEND_URL=$base  Response: $body',
      );
    }
    if (code == 503 && body.toLowerCase().contains('database not configured')) {
      throw Exception(
        '$label: HTTP 503 — Railway/backend par Supabase env vars missing hain. '
        'Variables me EXACT naam se lagao:\n'
        '• SUPABASE_URL = https://<project>.supabase.co\n'
        '• SUPABASE_SERVICE_ROLE_KEY = service_role JWT (anon key NAHI)\n'
        'Save karke service redeploy/restart karo. Phir /health me supabase_configured: true aana chahiye.\n'
        'BACKEND_URL=$base  Response: $body',
      );
    }
    throw Exception('$label: HTTP $code  Response: $body');
  }

  Future<List<Map<String, dynamic>>> fetchStaffUsers({required String tier}) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/admin/users');
    final response = await http.get(url, headers: _staffTierHeaders(tier));
    if (response.statusCode != 200) {
      _throwStaffApiFailure('Admin users list (/admin/users)', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> updateStaffUserRole({
    required String tier,
    required String userId,
    required String role,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/admin/users/$userId');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        ..._staffTierHeaders(tier),
      },
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode >= 300) {
      _throwStaffApiFailure('Update user role (/admin/users)', response);
    }
  }

  Future<Map<String, dynamic>> fetchAiConfig({required String tier}) async {
    final headers = _staffTierHeaders(tier);
    var url = Uri.parse('${AppConfig.backendBaseUrl}/admin/ai-config');
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 404) {
      url = Uri.parse('${AppConfig.backendBaseUrl}/admin/aiconfig');
      response = await http.get(url, headers: headers);
    }
    if (response.statusCode != 200) {
      _throwStaffApiFailure('AI config (GET /admin/ai-config)', response);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> patchAiConfig({
    required String tier,
    double? confidenceThreshold,
    double? processFps,
    double? deviceFrameConfidence,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      ..._staffTierHeaders(tier),
    };
    final body = <String, dynamic>{};
    if (confidenceThreshold != null) body['confidence_threshold'] = confidenceThreshold;
    if (processFps != null) body['process_fps'] = processFps;
    if (deviceFrameConfidence != null) body['device_frame_confidence'] = deviceFrameConfidence;
    final encoded = jsonEncode(body);
    var url = Uri.parse('${AppConfig.backendBaseUrl}/admin/ai-config');
    var response = await http.patch(url, headers: headers, body: encoded);
    if (response.statusCode == 404) {
      url = Uri.parse('${AppConfig.backendBaseUrl}/admin/aiconfig');
      response = await http.patch(url, headers: headers, body: encoded);
    }
    if (response.statusCode >= 300) {
      _throwStaffApiFailure('AI config save (PATCH /admin/ai-config)', response);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> purgeEvidence({required String tier}) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/admin/purge-evidence');
    final response = await http.post(url, headers: _staffTierHeaders(tier));
    if (response.statusCode >= 300) {
      _throwStaffApiFailure('Purge evidence (/admin/purge-evidence)', response);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
