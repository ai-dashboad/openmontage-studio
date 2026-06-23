import 'dart:convert';
import 'package:flutter/material.dart';
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
/// production agent and carries on a grounded conversation about the current
/// production. This is the seam where tool-calling (driving pipeline stages)
/// will later plug in; for now it is a grounded conversational turn.
class AgentService {
  AgentService({OllamaClient? ollama}) : _ollama = ollama ?? OllamaClient();

  final OllamaClient _ollama;

  static const String _systemPrompt = '''
You are the production agent inside OpenMontage Studio, a desktop app for
AI-orchestrated video production. Videos move through a fixed pipeline:
idea -> script -> scene_plan -> assets -> edit -> compose -> publish. Each
creative stage ends at a human approval gate.

Be concise and concrete. When the user describes a video, propose a short plan
in terms of scenes (a hook, a few content beats, a close) with rough timings.
Speak as a collaborator, not a chatbot. Keep replies under 120 words.''';

  String get model => _ollama.model;

  Future<AgentStatus> status() async {
    final s = await _ollama.status();
    return AgentStatus(connected: s.reachable, model: _ollama.model);
  }

  /// Produces the agent's next reply given the visible conversation [history].
  Future<String> reply(List<ChatMessage> history) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      for (final m in history)
        {
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.text,
        },
    ];
    return _ollama.chat(messages);
  }

  static const String _planPrompt = '''
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
    final text = await _ollama.chat([
      {'role': 'system', 'content': _planPrompt},
      {'role': 'user', 'content': 'Brief: $brief'},
    ]);
    final scenes = _parseScenes(text);
    if (scenes.isEmpty) {
      throw const OllamaException('Model returned no usable scene plan');
    }
    return scenes;
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
