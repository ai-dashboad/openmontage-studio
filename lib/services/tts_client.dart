import 'dart:io';

import 'command_runner.dart';

/// A synthesized narration clip produced locally by macOS `say`.
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

/// Local text-to-speech, driven directly via the macOS `say` engine — no server
/// process. Synthesizes narration to disk, plays it through `afplay`, and lists
/// installed voices via `say -v ?`.
class TtsClient {
  TtsClient({CommandRunner runner = const SystemCommandRunner()})
    : _runner = runner;

  final CommandRunner _runner;
  static const _defaultVoice = 'Samantha';
  int _clipIndex = 0;

  Directory get _workDir {
    final dir = Directory('${Directory.systemTemp.path}/openmontage-media');
    dir.createSync(recursive: true);
    return dir;
  }

  /// Whether the TTS tool is available on this machine.
  Future<bool> health() => _runner.exists('say');

  /// Lists installed English voices, common high-quality ones first.
  Future<List<String>> voices() async {
    final result = await _runner.run('say', ['-v', '?']);
    if (!result.ok) return const [];
    final names = <String>[];
    final pattern = RegExp(r'^(.*?)\s+([a-z]{2}[-_][A-Z]{2})\s');
    for (final line in result.stdout.split(RegExp(r'\r?\n'))) {
      final match = pattern.firstMatch(line);
      if (match != null && match.group(2)!.startsWith('en')) {
        names.add(match.group(1)!.trim());
      }
    }
    if (names.isEmpty) return const [_defaultVoice];
    const preferred = ['Samantha', 'Alex', 'Daniel', 'Karen', 'Moira', 'Tessa'];
    final ordered = [for (final p in preferred) if (names.contains(p)) p];
    ordered.addAll(names.where((n) => !ordered.contains(n)));
    return ordered;
  }

  /// Synthesizes [text] to an audio clip on disk and returns its metadata.
  Future<TtsClip> synthesize(String text, {String? voice}) async {
    final v = voice ?? _defaultVoice;
    final out = '${_workDir.path}/narration_${_clipIndex++}.aiff';
    final result = await _runner.run('say', ['-v', v, '-o', out, text]);
    if (!result.ok) {
      throw TtsException('say failed: ${result.stderr.trim()}');
    }
    final file = File(out);
    return TtsClip(
      path: out,
      voice: v,
      bytes: file.existsSync() ? file.lengthSync() : 0,
      seconds: await durationSeconds(_runner, out),
    );
  }

  /// Plays a previously synthesized clip through the speakers. Best-effort.
  Future<void> play(String path) async {
    _runner.spawn('afplay', [path]);
  }
}

/// Reads an audio file's estimated duration via `afinfo`.
Future<double> durationSeconds(CommandRunner runner, String path) async {
  try {
    final result = await runner.run('afinfo', [path]);
    final match = RegExp(
      r'estimated duration:\s*([\d.]+)',
    ).firstMatch(result.stdout);
    return match != null ? double.parse(match.group(1)!) : 0;
  } catch (_) {
    return 0;
  }
}

class TtsException implements Exception {
  const TtsException(this.message);
  final String message;
  @override
  String toString() => 'TtsException: $message';
}
