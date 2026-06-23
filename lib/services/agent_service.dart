import '../models/studio_models.dart';
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
}
