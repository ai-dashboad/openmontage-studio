import 'dart:async';
import 'dart:io';

/// The result of running an external command.
class CommandResult {
  const CommandResult(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout;
  final String stderr;
  bool get ok => exitCode == 0;
}

/// Runs the local command-line tools the app drives directly (the voice engine,
/// `ffmpeg`/`ffprobe`, `npx`, and the OS "open" helper). Abstracted so the media
/// clients can be unit-tested with a fake runner instead of spawning real
/// processes — this is what lets the app drive tools in-process while staying
/// testable across macOS, Windows, and Linux.
abstract class CommandRunner {
  /// Runs [exe] with [args] and awaits completion.
  Future<CommandResult> run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Duration timeout,
  });

  /// Fire-and-forget launch (e.g. an audio player, the file manager).
  void spawn(String exe, List<String> args);

  /// Whether [exe] is resolvable on the PATH.
  Future<bool> exists(String exe);
}

/// The production runner, backed by `dart:io` [Process].
///
/// A GUI-launched app inherits a minimal PATH (no Homebrew on macOS, no user
/// tool dirs on Windows), so tools like `ffmpeg` and `npx` would be
/// unresolvable. Every spawn injects an augmented PATH with the common install
/// locations for the host OS.
class SystemCommandRunner implements CommandRunner {
  const SystemCommandRunner();

  // Per-OS directories appended to PATH so a double-clicked app still finds the
  // tools a developer installed in the usual places.
  static List<String> get _extraPaths {
    if (Platform.isMacOS) {
      return const [
        '/opt/homebrew/bin', // Apple Silicon Homebrew (ffmpeg, node/npx)
        '/usr/local/bin', // Intel Homebrew + many installers
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin',
      ];
    }
    if (Platform.isWindows) {
      final program = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final local = Platform.environment['LOCALAPPDATA'] ?? '';
      return [
        r'C:\Windows\System32', // powershell, where
        '$program\\nodejs', // node/npx (system install)
        if (local.isNotEmpty) '$local\\Programs\\nodejs',
        if (local.isNotEmpty) '$local\\Microsoft\\WinGet\\Links', // winget shims
        r'C:\ffmpeg\bin', // common manual ffmpeg location
      ];
    }
    return const ['/usr/local/bin', '/usr/bin', '/bin', '/snap/bin'];
  }

  String get _sep => Platform.isWindows ? ';' : ':';

  Map<String, String> get _env {
    final current = Platform.environment['PATH'] ?? '';
    final parts = <String>[
      ...current.split(_sep).where((p) => p.isNotEmpty),
      for (final p in _extraPaths) if (!current.contains(p)) p,
    ];
    return {'PATH': parts.join(_sep)};
  }

  @override
  Future<CommandResult> run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final result = await Process.run(
      exe,
      args,
      workingDirectory: workingDirectory,
      environment: _env,
      includeParentEnvironment: true,
      // PowerShell and npm are .cmd/.ps1 shims on Windows, which Process can
      // only launch through a shell. POSIX hosts keep the faster no-shell path.
      runInShell: Platform.isWindows,
    ).timeout(timeout);
    return CommandResult(
      result.exitCode,
      result.stdout?.toString() ?? '',
      result.stderr?.toString() ?? '',
    );
  }

  @override
  void spawn(String exe, List<String> args) {
    unawaited(
      Process.start(
        exe,
        args,
        mode: ProcessStartMode.detached,
        environment: _env,
        includeParentEnvironment: true,
        runInShell: Platform.isWindows,
      ).catchError((_) => throw ProcessException(exe, args)),
    );
  }

  @override
  Future<bool> exists(String exe) async {
    try {
      // `which` (POSIX) / `where` (Windows) resolve against our augmented PATH.
      final probe = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(
        probe,
        [exe],
        environment: _env,
        includeParentEnvironment: true,
        runInShell: Platform.isWindows,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// Estimates an audio/video file's duration in seconds. Uses `ffprobe` (which
/// ships with ffmpeg and is cross-platform) first, falling back to macOS
/// `afinfo` when ffprobe is unavailable. Returns 0 when it cannot be determined.
Future<double> mediaDurationSeconds(CommandRunner runner, String path) async {
  try {
    final r = await runner.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    final value = double.tryParse(r.stdout.trim());
    if (value != null && value > 0) return value;
  } catch (_) {
    // fall through to the macOS fallback
  }
  if (Platform.isMacOS) {
    try {
      final result = await runner.run('afinfo', [path]);
      final match = RegExp(
        r'estimated duration:\s*([\d.]+)',
      ).firstMatch(result.stdout);
      if (match != null) return double.parse(match.group(1)!);
    } catch (_) {
      // fall through
    }
  }
  return 0;
}
