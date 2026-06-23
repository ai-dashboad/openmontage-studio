import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import '../models/studio_models.dart';
import '../theme/app_theme.dart';
import 'ollama_client.dart';

/// Live connection state for the agent, surfaced in the chat header.
class AgentStatus {
  const AgentStatus({required this.connected, required this.model});
  final bool connected;
  final String model;
}

/// The minimal agent loop. It frames a local LLM as the OpenMontage Studio
/// production agent using the editable skills in `assets/skills/`, and carries
/// on a grounded conversation about the current production. The skills are the
/// "how"; this class is plumbing. Tool-calling (driving more stages) plugs in
/// at the same seam.
class AgentService {
  AgentService({OllamaClient? ollama, AssetBundle? bundle})
    : _ollama = ollama ?? OllamaClient(),
      _bundle = bundle ?? rootBundle;

  final OllamaClient _ollama;
  final AssetBundle _bundle;

  final Map<String, String> _skillCache = {};

  /// Loads a skill from the asset bundle, falling back to embedded text so the
  /// agent still works if assets aren't available (e.g. some test harnesses).
  Future<String> _skill(String name, String fallback) async {
    final cached = _skillCache[name];
    if (cached != null) return cached;
    try {
      final text = await _bundle.loadString('assets/skills/$name');
      _skillCache[name] = text;
      return text;
    } catch (_) {
      return fallback;
    }
  }

  String get model => _ollama.model;

  Future<AgentStatus> status() async {
    final s = await _ollama.status();
    return AgentStatus(connected: s.reachable, model: _ollama.model);
  }

  /// Produces the agent's next reply given the visible conversation [history],
  /// grounded in the production skill.
  Future<String> reply(List<ChatMessage> history) async {
    final system = await _skill('production.md', _productionFallback);
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      for (final m in history)
        {
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.text,
        },
    ];
    return _ollama.chat(messages);
  }

  /// A one-line summary of what the agent will do for [stageName], grounded in
  /// that stage's skill. Used as the pipeline advances stage to stage.
  Future<String> summarizeStage(String stageName) async {
    final skill = await _skill('stage-$stageName.md', _productionFallback);
    return _ollama.chat([
      {'role': 'system', 'content': skill},
      {
        'role': 'user',
        'content':
            'In one short sentence, state what you will do for the "$stageName" '
            'stage of this video. No preamble.',
      },
    ]);
  }

  static const String _productionFallback = '''
You are the production agent inside OpenMontage Studio, a desktop app for
AI-orchestrated video production. Videos move through a fixed pipeline:
idea -> script -> scene_plan -> assets -> edit -> compose -> publish. Each
creative stage ends at a human approval gate.

Be concise and concrete. When the user describes a video, propose a short plan
in terms of scenes (a hook, a few content beats, a close) with rough timings.
Speak as a collaborator, not a chatbot. Keep replies under 120 words.''';

  static const String _planFallback = '''
You turn a one-line video brief into a scene plan for OpenMontage Studio.
Respond with ONLY a JSON array (no prose, no markdown fences) of 4 to 6 scenes.
Each scene is an object with these fields:
  "title":    short label (e.g. "Hook", "Stat", "Close")
  "type":     one of hero_title, stat_card, bar_chart, pie_chart, text_card
  "seconds":  number, the scene duration (total across scenes ~20-30s)
  "headline": the main on-screen line
  "subtitle": a short supporting line
Start with a hero_title hook and end with a text_card close.''';

  /// Turns a one-line [brief] into a structured scene plan via the local model.
  /// Throws if the model is unreachable or returns no usable plan; callers can
  /// fall back to a default plan.
  Future<List<Scene>> planScenes(String brief) async {
    final skill = await _skill('stage-scene-plan.md', _planFallback);
    final text = await _ollama.chat([
      {'role': 'system', 'content': skill},
      {'role': 'user', 'content': 'Brief: $brief'},
    ]);
    final scenes = _parseScenes(text);
    if (scenes.isEmpty) {
      throw const OllamaException('Model returned no usable scene plan');
    }
    return scenes;
  }

  /// Revises a single [scene] per a natural-language [instruction], returning
  /// the scene with an updated headline/subtitle. Throws if the model is
  /// unreachable or returns nothing usable; callers can keep the original.
  Future<Scene> reviseScene(Scene scene, String instruction) async {
    final text = await _ollama.chat([
      {
        'role': 'system',
        'content':
            'You revise one scene of a short video. Given the current scene and '
            'an instruction, respond with ONLY a JSON object (no prose, no code '
            'fences) with two fields: "headline" and "subtitle". Keep the '
            'headline punchy and the subtitle a short supporting line.',
      },
      {
        'role': 'user',
        'content':
            'Current headline: "${scene.headline}"\n'
            'Current subtitle: "${scene.subtitle}"\n'
            'Instruction: $instruction',
      },
    ]);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const OllamaException('Model returned no usable revision');
    }
    final Map<String, dynamic> obj;
    try {
      obj = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw const OllamaException('Model revision was not valid JSON');
    }
    return scene.copyWith(
      headline: (obj['headline'] as String?)?.trim().isNotEmpty == true
          ? (obj['headline'] as String).trim()
          : scene.headline,
      subtitle: (obj['subtitle'] as String?)?.trim().isNotEmpty == true
          ? (obj['subtitle'] as String).trim()
          : scene.subtitle,
    );
  }

  static const List<Color> _accents = [
    AppColors.accentCyan,
    AppColors.accentPurple,
    AppColors.accentAmber,
    AppColors.accentGreen,
  ];

  /// Extracts the JSON array from a model response (tolerating wrapping prose
  /// or code fences) and maps it to [Scene]s with cumulative timings.
  List<Scene> _parseScenes(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    final List<dynamic> raw;
    try {
      raw = jsonDecode(text.substring(start, end + 1)) as List<dynamic>;
    } catch (_) {
      return const [];
    }
    final scenes = <Scene>[];
    var cursor = 0.0;
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] is! Map) continue;
      final m = raw[i] as Map<String, dynamic>;
      final seconds =
          (m['seconds'] as num?)?.toDouble().clamp(1.0, 15.0) ?? 4.0;
      scenes.add(
        Scene(
          id: 'gen_$i',
          type: (m['type'] as String?) ?? 'text_card',
          title: (m['title'] as String?) ?? 'Scene ${i + 1}',
          startSeconds: cursor,
          endSeconds: cursor + seconds,
          accent: _accents[i % _accents.length],
          headline: (m['headline'] as String?) ?? '',
          subtitle: (m['subtitle'] as String?) ?? '',
        ),
      );
      cursor += seconds;
    }
    return scenes;
  }
}
