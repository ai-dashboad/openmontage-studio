import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/studio_models.dart';

/// A saved production: the editable scene plan plus where it is in the pipeline,
/// and (once rendered) the finished file. Persisting this is what lets a user
/// close the app and come back to their edits instead of losing them.
class StudioProject {
  StudioProject({
    required this.id,
    required this.name,
    required this.scenes,
    required this.stageIndex,
    required this.updatedAtIso,
    this.voice = 'Samantha',
    this.runtime = 'ffmpeg',
    this.renderPath,
    this.renderSeconds,
    this.renderBytes,
  });

  final String id;
  String name;
  List<Scene> scenes;
  int stageIndex;
  String updatedAtIso;
  String voice;
  String runtime;
  String? renderPath;
  double? renderSeconds;
  int? renderBytes;

  bool get hasRender => renderPath != null && renderPath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scenes': [for (final s in scenes) s.toJson()],
    'stage': stageIndex,
    'updatedAt': updatedAtIso,
    'voice': voice,
    'runtime': runtime,
    if (renderPath != null) 'renderPath': renderPath,
    if (renderSeconds != null) 'renderSeconds': renderSeconds,
    if (renderBytes != null) 'renderBytes': renderBytes,
  };

  static StudioProject fromJson(Map<String, dynamic> j) => StudioProject(
    id: j['id'] as String? ?? 'p',
    name: j['name'] as String? ?? 'Untitled',
    scenes: ((j['scenes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Scene.fromJson)
        .toList(),
    stageIndex: (j['stage'] as num?)?.toInt() ?? 2,
    updatedAtIso: j['updatedAt'] as String? ?? '',
    voice: j['voice'] as String? ?? 'Samantha',
    runtime: j['runtime'] as String? ?? 'ffmpeg',
    renderPath: j['renderPath'] as String?,
    renderSeconds: (j['renderSeconds'] as num?)?.toDouble(),
    renderBytes: (j['renderBytes'] as num?)?.toInt(),
  );
}

/// Persists projects locally (shared_preferences), most-recently-updated first.
class ProjectStore {
  ProjectStore({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'projects';
  static const _max = 24;

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<List<StudioProject>> load() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final projects = list
          .whereType<Map<String, dynamic>>()
          .map(StudioProject.fromJson)
          .toList();
      projects.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
      return projects;
    } catch (_) {
      return [];
    }
  }

  /// Inserts or updates [project] by id, stamping [updatedAtIso].
  Future<void> save(StudioProject project) async {
    try {
      final current = await load();
      current.removeWhere((p) => p.id == project.id);
      final next = [project, ...current].take(_max).toList();
      await (await _prefs).setString(
        _key,
        jsonEncode([for (final p in next) p.toJson()]),
      );
    } catch (_) {
      // Persisting is best-effort; never let it break an edit.
    }
  }

  Future<void> delete(String id) async {
    try {
      final current = await load()
        ..removeWhere((p) => p.id == id);
      await (await _prefs).setString(
        _key,
        jsonEncode([for (final p in current) p.toJson()]),
      );
    } catch (_) {
      // Best-effort.
    }
  }
}
