import 'dart:convert';

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
