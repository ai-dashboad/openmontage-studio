import 'package:flutter/foundation.dart';

import 'agent_service.dart';
import 'command_runner.dart';
import 'tts_client.dart';

/// Availability phase of the local media tools (ffmpeg + `say`).
enum MediaPhase { unknown, starting, up, down, failed }

/// Watches the local tooling the studio depends on, surfaced as status lights:
/// the agent (Ollama) and the media tools (ffmpeg + `say`). The app drives those
/// tools directly now, so there is no server to start — availability simply
/// reflects whether the binaries are installed.
class ProviderManager extends ChangeNotifier {
  ProviderManager({
    required this.agent,
    required this.media,
    CommandRunner runner = const SystemCommandRunner(),
  }) : _runner = runner;

  final AgentService agent;
  final TtsClient media;
  final CommandRunner _runner;

  bool agentUp = false;
  MediaPhase mediaPhase = MediaPhase.unknown;
  String? failureHint;

  bool get mediaUp => mediaPhase == MediaPhase.up;

  /// One-shot probe of the agent and the media tools.
  Future<void> probe() async {
    final results = await Future.wait([
      agent.status().then((s) => s.connected).catchError((_) => false),
      media.health().catchError((_) => false),
      _runner.exists('ffmpeg').catchError((_) => false),
    ]);
    agentUp = results[0];
    final mediaReady = results[1] && results[2];
    mediaPhase = mediaReady ? MediaPhase.up : MediaPhase.down;
    failureHint = mediaReady
        ? null
        : 'ffmpeg or the `say` voice engine is missing. Install ffmpeg: '
              'brew install ffmpeg';
    notifyListeners();
  }

  /// There is no server to start — the app runs the tools directly. Kept for
  /// the UI's "retry" affordances; it simply re-probes availability.
  Future<void> ensureRunning() => probe();
}
