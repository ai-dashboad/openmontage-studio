import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'video_gen.dart';

/// Owns the user's AI-video source choice (which provider + its key) and
/// generates a clip through it. Mirrors MediaSettings/DigitalHumanSettings.
class VideoSettings {
  VideoSettings({List<VideoSource>? sources, SharedPreferences? prefs})
    : sources =
          sources ??
          [
            const NoneVideoSource(),
            LocalVideoSource(), // free, on-device
            VeoVideoSource(),
            RunwayVideoSource(),
          ],
      _injected = prefs;

  final List<VideoSource> sources;
  final SharedPreferences? _injected;

  static const _selectedKey = 'video_source';
  static const _keysKey = 'video_keys';

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
        _keys = (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    _loaded = true;
  }

  VideoSource get selected =>
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

  /// Generates a clip for [prompt] via the selected source. Null when the source
  /// is "none", the prompt is empty, or generation fails.
  Future<GeneratedVideo?> generate(String prompt, {String initImagePath = ''}) async {
    await load();
    final src = selected;
    if (src.id == 'none' || prompt.trim().isEmpty) return null;
    return src.generate(prompt, key: keyFor(src.id), initImagePath: initImagePath);
  }
}
