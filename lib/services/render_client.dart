import 'dart:convert';
import 'package:http/http.dart' as http;

/// The result of a real render: a finished MP4 on disk.
class RenderResult {
  const RenderResult({
    required this.path,
    required this.scenes,
    required this.seconds,
    required this.bytes,
  });

  final String path;
  final int scenes;
  final double seconds;
  final int bytes;
}

/// Client for the local render provider (`backend/provider_server.py`, ffmpeg +
/// macOS `say`). Produces a real MP4 from a scene plan — offline, no API key.
class RenderClient {
  RenderClient({
    this.baseUrl = 'http://127.0.0.1:8765',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Renders [scenes] (each `{headline, subtitle, seconds, accent}`) to an MP4.
  Future<RenderResult> render(List<Map<String, dynamic>> scenes) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/render'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'scenes': scenes}),
        )
        .timeout(const Duration(seconds: 180));
    if (res.statusCode != 200) {
      throw RenderException('Render provider returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return RenderResult(
      path: body['path'] as String,
      scenes: (body['scenes'] as num?)?.toInt() ?? scenes.length,
      seconds: (body['seconds'] as num?)?.toDouble() ?? 0,
      bytes: (body['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Opens a finished clip in the system's default player. Best-effort.
  Future<void> open(String path) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/open'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path': path}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Opening is a nicety; ignore failures.
    }
  }
}

class RenderException implements Exception {
  const RenderException(this.message);
  final String message;
  @override
  String toString() => 'RenderException: $message';
}
