import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'image_source.dart';

/// Owns the user's media-source choice (which image source + its API keys) and
/// resolves scene images through the selected source. New sources (FAL, local
/// diffusion, …) register here and the rest of the app stays unchanged.
class MediaSettings {
  MediaSettings({List<ImageSource>? sources, SharedPreferences? prefs})
    : sources =
          sources ??
          [
            const NoneImageSource(),
            // AIGC text-to-image: cloud (BYOK) for quality, local for free.
            FalImageSource(),
            OpenAiImageSource(),
            GeminiImageSource(),
            GrokImageSource(),
            LocalDiffusionImageSource(),
            // Stock photos.
            PexelsImageSource(),
          ],
      _injected = prefs;

  final List<ImageSource> sources;
  final SharedPreferences? _injected;

  static const _selectedKey = 'media_image_source';
  static const _keysKey = 'media_image_keys';

  String _selectedId = 'none';
  Map<String, String> _keys = {};
  bool _loaded = false;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await _prefs;
      _selectedId = p.getString(_selectedKey) ?? 'none';
      final raw = p.getString(_keysKey);
      if (raw != null) {
        _keys = (jsonDecode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v.toString()),
        );
      }
    } catch (_) {}
    _loaded = true;
  }

  ImageSource get selected =>
      sources.firstWhere((s) => s.id == _selectedId, orElse: () => sources.first);
  String get selectedId => _selectedId;
  bool get isActive => _selectedId != 'none';
  String keyFor(String id) => _keys[id] ?? '';

  Future<void> setSource(String id) async {
    _selectedId = id;
    await (await _prefs).setString(_selectedKey, id);
  }

  Future<void> setKey(String id, String key) async {
    _keys[id] = key;
    await (await _prefs).setString(_keysKey, jsonEncode(_keys));
  }

  /// Resolves one image for [query] using the selected source. Null if the
  /// source is "none", the query is empty, or it fails.
  Future<SceneImage?> resolve(String query) async {
    await load();
    final src = selected;
    if (src.id == 'none' || query.trim().isEmpty) return null;
    try {
      return await src.resolve(query, key: keyFor(src.id));
    } catch (_) {
      return null;
    }
  }
}
