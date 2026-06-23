import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'agent_service.dart';
import 'tts_client.dart';

/// Lifecycle phase of the local media provider (`backend/provider_server.py`).
enum MediaPhase { unknown, starting, up, down, failed }

/// Watches the local services the studio depends on and, on launch, auto-starts
/// the media provider so the user never has to open a terminal. It tracks two
/// things the UI surfaces as status lights: the agent (Ollama) and the media
/// provider (ffmpeg + `say`, on :8765).
///
/// Auto-start spawns `python3 backend/provider_server.py` as a detached process.
/// It still relies on `python3` and `ffmpeg` being installed; when they aren't,
/// the phase becomes [MediaPhase.failed] with a hint instead of a silent hang.
class ProviderManager extends ChangeNotifier {
  ProviderManager({required this.agent, required this.media, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AgentService agent;
  final TtsClient media;
  final AssetBundle _bundle;

  bool agentUp = false;
  MediaPhase mediaPhase = MediaPhase.unknown;
  String? failureHint;

  bool get mediaUp => mediaPhase == MediaPhase.up;

  /// One-shot probe of both services. Safe to call from widgets — no timers.
  Future<void> probe() async {
    final results = await Future.wait([
      agent.status().then((s) => s.connected).catchError((_) => false),
      media.health().catchError((_) => false),
    ]);
    agentUp = results[0];
    if (mediaPhase != MediaPhase.starting) {
      mediaPhase = results[1] ? MediaPhase.up : MediaPhase.down;
    }
    notifyListeners();
  }

  /// Ensures the media provider is running, spawning it if needed. Idempotent:
  /// returns immediately if it is already up or currently starting.
  Future<void> ensureRunning() async {
    if (mediaPhase == MediaPhase.starting) return;
    if (await media.health()) {
      mediaPhase = MediaPhase.up;
      notifyListeners();
      return;
    }
    final scriptPath = await _resolveScript();
    if (scriptPath == null) {
      mediaPhase = MediaPhase.failed;
      failureHint =
          'Could not find provider_server.py. Run it manually: '
          'python3 backend/provider_server.py';
      notifyListeners();
      return;
    }
    mediaPhase = MediaPhase.starting;
    notifyListeners();
    try {
      await Process.start(
        'python3',
        [scriptPath],
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (e) {
      mediaPhase = MediaPhase.failed;
      failureHint =
          'Could not launch python3 (${e.message}). Install it, or run '
          'python3 backend/provider_server.py manually.';
      notifyListeners();
      return;
    }
    // Poll for the server to come up (it takes a moment to bind the port).
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (await media.health()) {
        mediaPhase = MediaPhase.up;
        notifyListeners();
        return;
      }
    }
    mediaPhase = MediaPhase.failed;
    failureHint =
        'The media provider did not respond. Is ffmpeg installed? '
        '(brew install ffmpeg)';
    notifyListeners();
  }

  /// Resolves a runnable path to `provider_server.py`. Prefers an on-disk copy
  /// when running from source (so edits to the script take effect immediately),
  /// and otherwise extracts the script bundled as an asset to a temp file — the
  /// path that works in a packaged .app, where the cwd is `/`.
  Future<String?> _resolveScript() async {
    final onDisk = File(
      '${Directory.current.path}/backend/provider_server.py',
    );
    if (onDisk.existsSync()) return onDisk.absolute.path;
    try {
      final code = await _bundle.loadString('backend/provider_server.py');
      final out = File(
        '${Directory.systemTemp.path}/openmontage_provider_server.py',
      );
      await out.writeAsString(code);
      return out.path;
    } catch (_) {
      return null;
    }
  }
}
