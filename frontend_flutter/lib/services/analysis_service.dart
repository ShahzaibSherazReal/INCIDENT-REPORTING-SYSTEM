import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

class AnalysisPickResult {
  const AnalysisPickResult({required this.results, required this.fileName});

  final Map<String, dynamic> results;
  final String fileName;
}

class AnalysisService {
  Future<AnalysisPickResult?> pickAndAnalyzeVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('File bytes not available (try a smaller file or use Chrome with file access).');
    }
    final map = await _postMultipartAnalyze(
      Uri.parse('${AppConfig.backendBaseUrl}/analyze-video'),
      bytes,
      file.name,
      timeout: const Duration(minutes: 30),
    );
    return AnalysisPickResult(results: map, fileName: file.name);
  }

  Future<AnalysisPickResult?> pickAndAnalyzeImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Image bytes not available.');
    }
    final map = await _postMultipartAnalyze(
      Uri.parse('${AppConfig.backendBaseUrl}/analyze-image'),
      bytes,
      file.name,
      timeout: const Duration(minutes: 5),
    );
    return AnalysisPickResult(results: map, fileName: file.name);
  }

  /// Same as [pickAndAnalyzeImage] but with bytes already in memory (e.g. camera capture).
  Future<Map<String, dynamic>> analyzeImageBytes(
    List<int> bytes, {
    String filename = 'capture.jpg',
  }) async {
    return _postMultipartAnalyze(
      Uri.parse('${AppConfig.backendBaseUrl}/analyze-image'),
      bytes,
      filename,
      timeout: const Duration(minutes: 5),
    );
  }

  Future<Map<String, dynamic>> _postMultipartAnalyze(
    Uri url,
    List<int> bytes,
    String filename, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final request = http.MultipartRequest('POST', url)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out after ${timeout.inMinutes} minutes. '
        'Video analysis can take a long time — try a shorter clip or lower resolution.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Cannot reach the backend at ${url.origin} (analyze). '
        'Check phone internet / Wi‑Fi; open ${url.origin}/docs in Chrome on the same device. '
        'If that fails: DNS or firewall. If only the app fails: uninstall and reinstall after rebuilding '
        '(ensure AndroidManifest includes INTERNET permission). Underlying: $e',
      );
    }

    try {
      final body = await streamed.stream.bytesToString().timeout(timeout);
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
      throw Exception('Server ${streamed.statusCode}: $body');
    } on FormatException catch (e) {
      throw Exception('Bad response from server (${streamed.statusCode}): $e');
    }
  }
}
