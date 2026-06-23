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

  /// Lists the render runtimes the provider supports ("ffmpeg" always, plus
  /// "remotion" when the cinematic composer is available). Empty on failure.
  Future<List<String>> runtimes() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/runtimes'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['runtimes'] as List? ?? const []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// Renders [scenes] (each `{headline, subtitle, seconds, accent}`) to an MP4,
  /// narrated with [voice], using [runtime] ("ffmpeg" fast cards, or "remotion"
  /// cinematic motion graphics).
  Future<RenderResult> render(
    List<Map<String, dynamic>> scenes, {
    String? voice,
    String? runtime,
  }) async {
    // Cinematic renders run a headless browser — give them more headroom.
    final timeout = runtime == 'remotion'
        ? const Duration(seconds: 600)
        : const Duration(seconds: 300);
    final res = await _http
        .post(
          Uri.parse('$baseUrl/render'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'scenes': scenes,
            'voice': ?voice,
            'runtime': ?runtime,
          }),
        )
        .timeout(timeout);
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

  /// Reveals a finished clip in Finder (select it in its folder). Best-effort.
  Future<void> reveal(String path) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/reveal'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path': path}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Revealing is a nicety; ignore failures.
    }
  }
}

class RenderException implements Exception {
  const RenderException(this.message);
  final String message;
  @override
  String toString() => 'RenderException: $message';
}
