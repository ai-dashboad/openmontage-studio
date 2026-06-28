import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'digital_human.dart';

/// Owns the user's digital-human choice (which presenter source + its key) and
/// generates a presenter clip through the selected source. Mirrors MediaSettings
/// so the Settings UI and the editor stay consistent. Defaults to local-free.
class DigitalHumanSettings {
  DigitalHumanSettings({List<DigitalHumanSource>? sources, SharedPreferences? prefs})
    : sources =
          sources ??
          [
            const NoneDigitalHuman(),
            LocalLipSyncSource(), // free, on-device default
            HeyGenSource(),
            DidSource(),
          ],
      _injected = prefs;

  final List<DigitalHumanSource> sources;
  final SharedPreferences? _injected;

  static const _selectedKey = 'digital_human_source';
  static const _keysKey = 'digital_human_keys';

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

  DigitalHumanSource get selected => sources.firstWhere(
    (s) => s.id == _selectedId,
    orElse: () => sources.first,
  );
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

  /// Generates a presenter clip for [script] via the selected source. Null when
  /// the source is "none", the script is empty, or generation fails.
  Future<PresenterClip?> generate(String script) async {
    await load();
    final src = selected;
    if (src.id == 'none' || script.trim().isEmpty) return null;
    return src.generate(script, key: keyFor(src.id));
  }
}
