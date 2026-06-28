import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A resolved image for a scene background: a URL (stock/cloud) or a local file
/// path (locally generated), plus where it came from for attribution.
class SceneImage {
  const SceneImage({required this.url, this.credit});
  final String url;
  final String? credit;
}

/// A pluggable source of scene imagery. The user picks one in Settings; each
/// scene's [SceneImage] is resolved from its query. Implementations: free stock
/// (Pexels), cloud AI (FAL), local diffusion — all behind this one seam, so the
/// render and preview don't care where the image came from.
abstract class ImageSource {
  /// Stable id persisted in settings (e.g. 'pexels').
  String get id;

  /// Human label shown in Settings.
  String get label;

  /// Whether this source needs an API key.
  bool get needsKey;

  /// Short hint for the key field (where to get it), or null.
  String? get keyHint => null;

  /// Resolves an image for [query]. Returns null when none/failed. [key] is the
  /// user-provided API key (may be empty for keyless sources).
  Future<SceneImage?> resolve(String query, {String key = ''});
}

/// The "off" source — scenes keep their designed color cards.
class NoneImageSource implements ImageSource {
  const NoneImageSource();
  @override
  String get id => 'none';
  @override
  String get label => 'None (designed cards)';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => null;
  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async => null;
}

/// Free stock photos via the Pexels API (a free key from pexels.com/api).
class PexelsImageSource implements ImageSource {
  PexelsImageSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  @override
  String get id => 'pexels';
  @override
  String get label => 'Pexels (free stock photos)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Free key at pexels.com/api';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (key.isEmpty || query.trim().isEmpty) return null;
    final uri = Uri.parse(
      'https://api.pexels.com/v1/search'
      '?per_page=1&orientation=landscape&query=${Uri.encodeQueryComponent(query)}',
    );
    final res = await _http
        .get(uri, headers: {'Authorization': key})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw ImageSourceException('Pexels returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final photos = (body['photos'] as List?) ?? const [];
    if (photos.isEmpty) return null;
    final p = photos.first as Map<String, dynamic>;
    final src = (p['src'] as Map<String, dynamic>?) ?? const {};
    final url = (src['large2x'] ?? src['large'] ?? src['original']) as String?;
    if (url == null) return null;
    return SceneImage(url: url, credit: p['photographer'] as String?);
  }
}

class ImageSourceException implements Exception {
  const ImageSourceException(this.message);
  final String message;
  @override
  String toString() => 'ImageSourceException: $message';
}

// --- AIGC text-to-image sources --------------------------------------------
//
// Each turns a scene's query into a generated background image. Cloud providers
// are BYOK — the user pastes their own key, so generation runs on (and is billed
// to) their account, tapping their free quota first. The local provider talks to
// a Stable Diffusion endpoint on the user's machine for a zero-cost option.

/// Shapes a scene query into a vivid background-image prompt. Kept here so every
/// generative source produces consistent, ad-ready, text-free backgrounds.
String buildImagePrompt(String query) =>
    '${query.trim()}, cinematic advertising background, dramatic lighting, '
    'high detail, photographic, no text, no watermark';

/// Decodes base64 image data to a temp PNG and returns its path. Generated
/// images live under the system temp dir so the preview (Image.file) and the
/// renderer can read them without a network round-trip.
Future<String> _saveImageBytes(List<int> bytes) async {
  final dir = Directory('${Directory.systemTemp.path}/openmontage-media/aigc')
    ..createSync(recursive: true);
  final file = File(
    '${dir.path}/img_${bytes.length}_${bytes.isEmpty ? 0 : bytes.first}_'
    '${bytes.length > 1 ? bytes[bytes.length ~/ 2] : 0}.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// FLUX via fal.ai — a strong, fast default for AI backgrounds. Returns a hosted
/// URL (works in the preview and the renderer like any stock image).
class FalImageSource implements ImageSource {
  FalImageSource({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;

  @override
  String get id => 'fal';
  @override
  String get label => 'FLUX · fal.ai (AI, high quality)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at fal.ai/dashboard/keys';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (key.isEmpty || query.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse('https://fal.run/fal-ai/flux/schnell'),
          headers: {
            'Authorization': 'Key $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'prompt': buildImagePrompt(query),
            'image_size': 'landscape_16_9',
            'num_images': 1,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw ImageSourceException('fal.ai returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final images = (body['images'] as List?) ?? const [];
    if (images.isEmpty) return null;
    final url = (images.first as Map<String, dynamic>)['url'] as String?;
    return url == null ? null : SceneImage(url: url, credit: 'FLUX · fal.ai');
  }
}

/// OpenAI image generation (DALL·E 3) — returns a hosted URL.
class OpenAiImageSource implements ImageSource {
  OpenAiImageSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  @override
  String get id => 'openai';
  @override
  String get label => 'OpenAI · DALL·E 3 (AI)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at platform.openai.com/api-keys';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (key.isEmpty || query.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse('https://api.openai.com/v1/images/generations'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'dall-e-3',
            'prompt': buildImagePrompt(query),
            'size': '1792x1024',
            'n': 1,
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw ImageSourceException('OpenAI returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    if (data.isEmpty) return null;
    final first = data.first as Map<String, dynamic>;
    final url = first['url'] as String?;
    if (url != null) return SceneImage(url: url, credit: 'DALL·E 3');
    final b64 = first['b64_json'] as String?;
    if (b64 == null) return null;
    return SceneImage(url: await _saveImageBytes(base64Decode(b64)));
  }
}

/// xAI Grok image generation — OpenAI-compatible images endpoint, returns a URL.
class GrokImageSource implements ImageSource {
  GrokImageSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  @override
  String get id => 'grok';
  @override
  String get label => 'xAI · Grok image (AI)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at console.x.ai';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (key.isEmpty || query.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse('https://api.x.ai/v1/images/generations'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'grok-2-image',
            'prompt': buildImagePrompt(query),
            'n': 1,
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw ImageSourceException('xAI returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    if (data.isEmpty) return null;
    final first = data.first as Map<String, dynamic>;
    final url = first['url'] as String?;
    if (url != null) return SceneImage(url: url, credit: 'Grok');
    final b64 = first['b64_json'] as String?;
    if (b64 == null) return null;
    return SceneImage(url: await _saveImageBytes(base64Decode(b64)));
  }
}

/// Google Gemini native image generation. Returns inline base64, saved locally.
/// Gemini's free tier is the most generous for getting started.
class GeminiImageSource implements ImageSource {
  GeminiImageSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  static const _model = 'gemini-2.5-flash-image';

  @override
  String get id => 'gemini';
  @override
  String get label => 'Google · Gemini (AI)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Free key at aistudio.google.com/apikey';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (key.isEmpty || query.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            '$_model:generateContent?key=$key',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': buildImagePrompt(query)},
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['IMAGE', 'TEXT'],
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw ImageSourceException('Gemini returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = (body['candidates'] as List?) ?? const [];
    for (final c in candidates) {
      final parts =
          (((c as Map<String, dynamic>)['content'] as Map<String, dynamic>?)
                  ?['parts'] as List?) ??
          const [];
      for (final p in parts) {
        final inline = (p as Map<String, dynamic>)['inlineData'] as Map?;
        final data = inline?['data'] as String?;
        if (data != null) {
          return SceneImage(url: await _saveImageBytes(base64Decode(data)));
        }
      }
    }
    return null;
  }
}

/// Local Stable Diffusion via an Automatic1111-compatible endpoint
/// (http://127.0.0.1:7860). Free, on-device, no key — for users who run their
/// own model (Draw Things, ComfyUI with the A1111 API, or A1111 itself).
class LocalDiffusionImageSource implements ImageSource {
  LocalDiffusionImageSource({http.Client? httpClient, String? endpoint})
    : _http = httpClient ?? http.Client(),
      _endpoint = endpoint ?? 'http://127.0.0.1:7860';
  final http.Client _http;
  final String _endpoint;

  @override
  String get id => 'local_sd';
  @override
  String get label => 'Local Stable Diffusion (free, on-device)';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => 'Runs against a local SD endpoint on :7860';

  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    if (query.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse('$_endpoint/sdapi/v1/txt2img'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': buildImagePrompt(query),
            'width': 1024,
            'height': 576,
            'steps': 24,
          }),
        )
        .timeout(const Duration(seconds: 180));
    if (res.statusCode != 200) {
      throw ImageSourceException('Local SD returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final images = (body['images'] as List?) ?? const [];
    if (images.isEmpty) return null;
    return SceneImage(url: await _saveImageBytes(base64Decode(images.first as String)));
  }
}
