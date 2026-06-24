import 'dart:io';

import 'command_runner.dart';
import 'voice_settings.dart';
import 'voice_source.dart';

/// A synthesized narration clip produced by the active voice source.
class TtsClip {
  const TtsClip({
    required this.path,
    required this.voice,
    required this.bytes,
    required this.seconds,
  });

  final String path;
  final String voice;
  final int bytes;
  final double seconds;
}

/// Local-first text-to-speech facade. Delegates to the user's chosen
/// [VoiceSettings] source (OS-native by default, cloud neural optionally) so the
/// voice picker and preview reflect the selection across macOS, Windows, and
/// Linux. Synthesizes narration to disk and plays it back through the host's
/// audio player.
class TtsClient {
  TtsClient({
    CommandRunner runner = const SystemCommandRunner(),
    VoiceSettings? voiceSettings,
  }) : _runner = runner,
       _voices = voiceSettings ?? VoiceSettings();

  final CommandRunner _runner;
  final VoiceSettings _voices;
  int _clipIndex = 0;

  Directory get _workDir {
    final dir = Directory('${Directory.systemTemp.path}/openmontage-media');
    dir.createSync(recursive: true);
    return dir;
  }

  /// Whether narration is available at all — the OS-native engine is the floor,
  /// so this stays green even when a cloud source is selected but offline.
  Future<bool> health() => const SystemVoiceSource().health(_runner);

  /// Lists selectable voices for the active source, best-quality first.
  Future<List<String>> voices() => _voices.voices(_runner);

  /// Synthesizes [text] to an audio clip on disk and returns its metadata.
  Future<TtsClip> synthesize(String text, {String? voice}) async {
    final base = '${_workDir.path}/narration_${_clipIndex++}';
    final clip = await _voices.synthesize(
      _runner,
      text,
      outPathBase: base,
      voice: voice,
    );
    if (clip == null) {
      throw const TtsException('No narration was produced');
    }
    return TtsClip(
      path: clip.path,
      voice: clip.voice,
      bytes: clip.bytes,
      seconds: clip.seconds,
    );
  }

  /// Plays a previously synthesized clip through the speakers. Best-effort.
  Future<void> play(String path) async {
    if (Platform.isMacOS) {
      _runner.spawn('afplay', [path]);
    } else if (Platform.isWindows) {
      _runner.spawn('powershell', [
        '-NoProfile',
        '-Command',
        "(New-Object Media.SoundPlayer '$path').PlaySync()",
      ]);
    } else {
      _runner.spawn('ffplay', ['-nodisp', '-autoexit', '-loglevel', 'quiet', path]);
    }
  }
}

class TtsException implements Exception {
  const TtsException(this.message);
  final String message;
  @override
  String toString() => 'TtsException: $message';
}
