import 'dart:convert';
import 'package:http/http.dart' as http;

/// A synthesized narration clip produced by the local TTS provider.
class TtsClip {
  const TtsClip({
    required this.path,
    required this.voice,
    required this.bytes,
    required this.seconds,
  });

  final String path;
  final String voice;
  final int bytes;
  final double seconds;
}

/// Client for the local TTS provider (`backend/tts_server.py`, macOS `say`).
/// Another "localhost provider" — real narration audio, offline, no API key.
class TtsClient {
  TtsClient({this.baseUrl = 'http://127.0.0.1:8765', http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Whether the provider is reachable.
  Future<bool> health() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return false;
      return (jsonDecode(res.body) as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Lists the narration voices available on this machine. Empty on failure.
  Future<List<String>> voices() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/voices'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['voices'] as List? ?? const []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// Synthesizes [text] to an audio clip on disk and returns its metadata.
  Future<TtsClip> synthesize(String text, {String? voice}) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/tts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'voice': ?voice}),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw TtsException('TTS provider returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return TtsClip(
      path: body['path'] as String,
      voice: body['voice'] as String? ?? 'default',
      bytes: (body['bytes'] as num?)?.toInt() ?? 0,
      seconds: (body['seconds'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Plays a previously synthesized clip through the speakers. Best-effort.
  Future<void> play(String path) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/tts/play'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path': path}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Playback is a nicety; ignore failures.
    }
  }
}

class TtsException implements Exception {
  const TtsException(this.message);
  final String message;
  @override
  String toString() => 'TtsException: $message';
}
