// Dev smoke check: exercises the real OllamaClient against a local Ollama
// server. Run with `dart run tool/agent_smoke.dart` while Ollama is running.
//
// Uses OllamaClient directly (no Flutter imports) so it runs on the plain Dart
// VM; AgentService only adds the system prompt on top of this same client.
import 'package:openmontage_studio/services/ollama_client.dart';

Future<void> main() async {
  final client = OllamaClient();

  final status = await client.status();
  // ignore: avoid_print
  print('reachable=${status.reachable} models=${status.models}');
  if (!status.reachable) {
    // ignore: avoid_print
    print(
      'Ollama not reachable on localhost:11434 — start it and pull a model.',
    );
    return;
  }

  final reply = await client.chat(const [
    {
      'role': 'system',
      'content': 'You are the OpenMontage Studio production agent. Be brief.',
    },
    {
      'role': 'user',
      'content': 'Give me a 3-beat plan for a 20s explainer on tides.',
    },
  ]);
  // ignore: avoid_print
  print('--- agent reply ---\n$reply');

  // Structured plan path: does the model return a parseable JSON array?
  final plan = await client.chat(const [
    {
      'role': 'system',
      'content':
          'Turn the brief into a scene plan. Respond with ONLY a JSON array of '
          'objects with fields title, type, seconds, headline, subtitle.',
    },
    {'role': 'user', 'content': 'Brief: a 30s explainer on black holes'},
  ]);
  final start = plan.indexOf('[');
  final end = plan.lastIndexOf(']');
  final ok = start >= 0 && end > start;
  // ignore: avoid_print
  print(
    '--- plan json detected=$ok ---\n${plan.substring(0, plan.length.clamp(0, 400))}',
  );
}
