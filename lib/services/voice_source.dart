import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'command_runner.dart';

/// A synthesized narration clip on disk.
class VoiceClip {
  const VoiceClip({
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

/// A pluggable narration engine. The user picks one in Settings; the renderer
/// synthesizes each scene's narration through the active source. Implementations
/// cover the OS-native engine (free, offline) and cloud neural voices — all
/// behind this one seam, so the renderer doesn't care where the audio came from.
abstract class VoiceSource {
  /// Stable id persisted in settings (e.g. 'system', 'elevenlabs').
  String get id;

  /// Human label shown in Settings.
  String get label;

  /// Whether this source needs an API key.
  bool get needsKey;

  /// Short hint for the key field (where to get it), or null.
  String? get keyHint => null;

  /// Whether synthesis runs on-device for free (no network, no cost).
  bool get isLocal;

  /// File extension (no dot) this engine writes.
  String get outputExtension;

  /// A reasonable default voice name for this source/host.
  String get defaultVoice;

  /// Whether the engine is usable on this machine right now.
  Future<bool> health(CommandRunner runner, {String key = ''});

  /// Lists selectable voice names, best-quality first. Empty when unavailable.
  Future<List<String>> voices(CommandRunner runner, {String key = ''});

  /// Synthesizes [text] to `<outPathBase>.<outputExtension>` and returns the
  /// clip's metadata, or null when nothing was produced (empty text / failure).
  Future<VoiceClip?> synthesize(
    CommandRunner runner,
    String text, {
    String? voice,
    required String outPathBase,
    String key = '',
  });
}

/// The OS-native voice engine: macOS `say`, Windows SAPI (via PowerShell
/// `System.Speech`), and Linux `espeak-ng`. Free, offline, always available as
/// the default so the product works with zero setup on every platform.
class SystemVoiceSource implements VoiceSource {
  const SystemVoiceSource();

  @override
  String get id => 'system';
  @override
  String get label {
    if (Platform.isMacOS) return 'System voice (macOS, free & offline)';
    if (Platform.isWindows) return 'System voice (Windows, free & offline)';
    return 'System voice (Linux espeak-ng, free & offline)';
  }

  @override
  bool get needsKey => false;
  @override
  String? get keyHint => null;
  @override
  bool get isLocal => true;

  @override
  String get outputExtension => Platform.isMacOS ? 'aiff' : 'wav';

  @override
  String get defaultVoice => Platform.isMacOS ? 'Samantha' : '';

  @override
  Future<bool> health(CommandRunner runner, {String key = ''}) {
    if (Platform.isMacOS) return runner.exists('say');
    if (Platform.isWindows) return runner.exists('powershell');
    return runner.exists('espeak-ng');
  }

  @override
  Future<List<String>> voices(CommandRunner runner, {String key = ''}) async {
    if (Platform.isMacOS) return _macVoices(runner);
    if (Platform.isWindows) return _windowsVoices(runner);
    return _linuxVoices(runner);
  }

  @override
  Future<VoiceClip?> synthesize(
    CommandRunner runner,
    String text, {
    String? voice,
    required String outPathBase,
    String key = '',
  }) async {
    if (text.trim().isEmpty) return null;
    final v = (voice == null || voice.isEmpty) ? defaultVoice : voice;
    final out = '$outPathBase.$outputExtension';

    final CommandResult result;
    if (Platform.isMacOS) {
      final args = ['-o', out, if (v.isNotEmpty) ...['-v', v], text];
      result = await runner.run('say', args);
    } else if (Platform.isWindows) {
      result = await _windowsSpeak(runner, text, v, out, outPathBase);
    } else {
      // espeak-ng reads the text from a file (-f) to avoid shell quoting.
      final txt = '$outPathBase.txt';
      File(txt).writeAsStringSync(text);
      final args = ['-w', out, if (v.isNotEmpty) ...['-v', v], '-f', txt];
      result = await runner.run('espeak-ng', args);
    }

    if (!result.ok) {
      throw VoiceException('System voice failed: ${result.stderr.trim()}');
    }
    final file = File(out);
    return VoiceClip(
      path: out,
      voice: v,
      bytes: file.existsSync() ? file.lengthSync() : 0,
      seconds: await mediaDurationSeconds(runner, out),
    );
  }

  Future<List<String>> _macVoices(CommandRunner runner) async {
    final result = await runner.run('say', ['-v', '?']);
    if (!result.ok) return const [];
    final names = <String>[];
    final pattern = RegExp(r'^(.*?)\s+([a-z]{2}[-_][A-Z]{2})\s');
    for (final line in result.stdout.split(RegExp(r'\r?\n'))) {
      final match = pattern.firstMatch(line);
      if (match != null && match.group(2)!.startsWith('en')) {
        names.add(match.group(1)!.trim());
      }
    }
    if (names.isEmpty) return const ['Samantha'];
    const preferred = ['Samantha', 'Alex', 'Daniel', 'Karen', 'Moira', 'Tessa'];
    final ordered = [for (final p in preferred) if (names.contains(p)) p];
    ordered.addAll(names.where((n) => !ordered.contains(n)));
    return ordered;
  }

  Future<List<String>> _windowsVoices(CommandRunner runner) async {
    const script =
        'Add-Type -AssemblyName System.Speech; '
        '(New-Object System.Speech.Synthesis.SpeechSynthesizer)'
        '.GetInstalledVoices() | ForEach-Object { \$_.VoiceInfo.Name }';
    final result = await runner.run('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
    if (!result.ok) return const [];
    final names = [
      for (final line in result.stdout.split(RegExp(r'\r?\n')))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return names;
  }

  Future<List<String>> _linuxVoices(CommandRunner runner) async {
    final result = await runner.run('espeak-ng', ['--voices=en']);
    if (!result.ok) return const ['en-us'];
    final names = <String>[];
    for (final line in result.stdout.split(RegExp(r'\r?\n')).skip(1)) {
      final cols = line.trim().split(RegExp(r'\s+'));
      // Columns: Pty Language Age/Gender VoiceName File ...
      if (cols.length >= 4) names.add(cols[3]);
    }
    return names.isEmpty ? const ['en-us'] : names;
  }

  /// Drives Windows SAPI through PowerShell. The narration text is passed via a
  /// temp file (read with `Get-Content -Raw`) to sidestep shell-quoting issues.
  Future<CommandResult> _windowsSpeak(
    CommandRunner runner,
    String text,
    String voice,
    String out,
    String outPathBase,
  ) async {
    final txt = '$outPathBase.txt';
    File(txt).writeAsStringSync(text);
    final selectVoice = voice.isEmpty
        ? ''
        : "\$s.SelectVoice('${voice.replaceAll("'", "''")}'); ";
    final script =
        'Add-Type -AssemblyName System.Speech; '
        '\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
        '$selectVoice'
        "\$s.SetOutputToWaveFile('$out'); "
        "\$t = Get-Content -Raw -LiteralPath '$txt'; "
        '\$s.Speak(\$t); \$s.Dispose()';
    return runner.run('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
  }
}

/// Cloud neural voices via ElevenLabs (a free tier exists at elevenlabs.io).
/// Higher quality than the OS engine; needs a key and a network connection.
class ElevenLabsVoiceSource implements VoiceSource {
  ElevenLabsVoiceSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  static const _base = 'https://api.elevenlabs.io/v1';

  // Resolved name -> voice_id, cached from the last voices() call so synthesis
  // can map a selected name back to the id the API requires.
  final Map<String, String> _idByName = {};

  @override
  String get id => 'elevenlabs';
  @override
  String get label => 'ElevenLabs (cloud neural voices)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Free key at elevenlabs.io';
  @override
  bool get isLocal => false;
  @override
  String get outputExtension => 'mp3';
  @override
  String get defaultVoice => 'Rachel';

  @override
  Future<bool> health(CommandRunner runner, {String key = ''}) async {
    if (key.isEmpty) return false;
    try {
      final res = await _http
          .get(Uri.parse('$_base/voices'), headers: {'xi-api-key': key})
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> voices(CommandRunner runner, {String key = ''}) async {
    if (key.isEmpty) return const [];
    final res = await _http
        .get(Uri.parse('$_base/voices'), headers: {'xi-api-key': key})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['voices'] as List?) ?? const [];
    _idByName.clear();
    final names = <String>[];
    for (final v in list) {
      final m = v as Map<String, dynamic>;
      final name = m['name'] as String?;
      final voiceId = m['voice_id'] as String?;
      if (name != null && voiceId != null) {
        _idByName[name] = voiceId;
        names.add(name);
      }
    }
    return names;
  }

  @override
  Future<VoiceClip?> synthesize(
    CommandRunner runner,
    String text, {
    String? voice,
    required String outPathBase,
    String key = '',
  }) async {
    if (text.trim().isEmpty) return null;
    if (key.isEmpty) {
      throw const VoiceException('ElevenLabs needs an API key');
    }
    // Resolve the voice id, fetching the catalog once if needed.
    if (_idByName.isEmpty) await voices(runner, key: key);
    final name = (voice == null || voice.isEmpty) ? defaultVoice : voice;
    final voiceId =
        _idByName[name] ?? (_idByName.isEmpty ? null : _idByName.values.first);
    if (voiceId == null) {
      throw const VoiceException('No ElevenLabs voices available for this key');
    }

    final res = await _http
        .post(
          Uri.parse('$_base/text-to-speech/$voiceId'),
          headers: {
            'xi-api-key': key,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': 'eleven_multilingual_v2',
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw VoiceException('ElevenLabs returned HTTP ${res.statusCode}');
    }
    final out = '$outPathBase.$outputExtension';
    final file = File(out);
    await file.writeAsBytes(res.bodyBytes);
    return VoiceClip(
      path: out,
      voice: name,
      bytes: res.bodyBytes.length,
      seconds: await mediaDurationSeconds(runner, out),
    );
  }
}

class VoiceException implements Exception {
  const VoiceException(this.message);
  final String message;
  @override
  String toString() => 'VoiceException: $message';
}
