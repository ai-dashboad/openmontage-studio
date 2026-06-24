import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'command_runner.dart';
import 'voice_source.dart';

/// Owns the user's narration choice (which voice source, its API key, and the
/// selected voice name) and synthesizes through the active source. The OS-native
/// "system" source is always present and is the default, so narration works with
/// zero setup on macOS, Windows, and Linux. New sources register here and the
/// renderer stays unchanged.
class VoiceSettings {
  VoiceSettings({List<VoiceSource>? sources, SharedPreferences? prefs})
    : sources =
          sources ??
          [const SystemVoiceSource(), ElevenLabsVoiceSource()],
      _injected = prefs;

  final List<VoiceSource> sources;
  final SharedPreferences? _injected;

  static const _selectedKey = 'voice_source';
  static const _keysKey = 'voice_keys';
  static const _voiceNameKey = 'voice_names'; // selected voice name per source

  String _selectedId = 'system';
  Map<String, String> _keys = {};
  Map<String, String> _voiceNames = {};
  bool _loaded = false;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await _prefs;
      _selectedId = p.getString(_selectedKey) ?? 'system';
      _keys = _decodeMap(p.getString(_keysKey));
      _voiceNames = _decodeMap(p.getString(_voiceNameKey));
    } catch (_) {}
    _loaded = true;
  }

  Map<String, String> _decodeMap(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  VoiceSource get selected => sources.firstWhere(
    (s) => s.id == _selectedId,
    orElse: () => sources.first,
  );
  String get selectedId => _selectedId;
  String keyFor(String id) => _keys[id] ?? '';

  /// The chosen voice name for the active source, or its default.
  String get voiceName {
    final stored = _voiceNames[_selectedId];
    return (stored == null || stored.isEmpty) ? selected.defaultVoice : stored;
  }

  String voiceNameFor(String id) => _voiceNames[id] ?? '';

  Future<void> setSource(String id) async {
    _selectedId = id;
    await (await _prefs).setString(_selectedKey, id);
  }

  Future<void> setKey(String id, String key) async {
    _keys[id] = key;
    await (await _prefs).setString(_keysKey, jsonEncode(_keys));
  }

  Future<void> setVoiceName(String name) async {
    _voiceNames[_selectedId] = name;
    await (await _prefs).setString(_voiceNameKey, jsonEncode(_voiceNames));
  }

  /// Lists selectable voices for the active source.
  Future<List<String>> voices(CommandRunner runner) async {
    await load();
    final src = selected;
    try {
      return await src.voices(runner, key: keyFor(src.id));
    } catch (_) {
      return const [];
    }
  }

  /// Synthesizes [text] to `<outPathBase>.<ext>` via the active source, falling
  /// back to the always-available system voice if the chosen source fails.
  Future<VoiceClip?> synthesize(
    CommandRunner runner,
    String text, {
    required String outPathBase,
    String? voice,
  }) async {
    await load();
    final src = selected;
    final voiceName = (voice == null || voice.isEmpty)
        ? voiceNameFor(src.id)
        : voice;
    try {
      return await src.synthesize(
        runner,
        text,
        voice: voiceName,
        outPathBase: outPathBase,
        key: keyFor(src.id),
      );
    } catch (_) {
      if (src.id == 'system') rethrow;
      // Graceful degradation: never block a render because a cloud voice or its
      // key is unavailable — fall back to the free, offline OS voice.
      return const SystemVoiceSource().synthesize(
        runner,
        text,
        outPathBase: outPathBase,
      );
    }
  }
}
