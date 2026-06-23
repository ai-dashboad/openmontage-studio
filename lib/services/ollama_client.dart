import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reachability and available models for a local Ollama server.
class OllamaStatus {
  const OllamaStatus({required this.reachable, this.models = const []});
  final bool reachable;
  final List<String> models;
}

/// Thin client for a local [Ollama](https://ollama.com) server. This is the
/// "localhost provider" that backs the agent — a local LLM reached over HTTP,
/// so it works fully offline with no API key.
class OllamaClient {
  OllamaClient({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'qwen2.5:latest',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String model;
  final http.Client _http;

  /// Lists installed models; doubles as a reachability check.
  Future<OllamaStatus> status() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return const OllamaStatus(reachable: false);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final models = (body['models'] as List? ?? [])
          .map((m) => (m as Map)['name'] as String)
          .toList();
      return OllamaStatus(reachable: true, models: models);
    } catch (_) {
      return const OllamaStatus(reachable: false);
    }
  }

  /// Sends a non-streaming chat completion and returns the assistant text.
  ///
  /// [messages] is a list of `{role, content}` maps with roles `system`,
  /// `user`, or `assistant`.
  Future<String> chat(List<Map<String, String>> messages) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'stream': false,
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode != 200) {
      throw OllamaException('Ollama returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (body['message'] as Map?)?['content'] as String?;
    if (content == null) {
      throw const OllamaException('Ollama response had no message content');
    }
    return content.trim();
  }
}

class OllamaException implements Exception {
  const OllamaException(this.message);
  final String message;
  @override
  String toString() => 'OllamaException: $message';
}
