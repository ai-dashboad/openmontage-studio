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
}
