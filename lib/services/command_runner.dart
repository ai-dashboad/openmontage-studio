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

/// Runs the local command-line tools the app drives directly (`say`, `ffmpeg`,
/// `afinfo`, `afplay`, `open`, `npx`). Abstracted so the media clients can be
/// unit-tested with a fake runner instead of spawning real processes — this is
/// what lets the app replace the old Python provider server with in-process
/// Dart while staying testable.
abstract class CommandRunner {
  /// Runs [exe] with [args] and awaits completion.
  Future<CommandResult> run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Duration timeout,
  });

  /// Fire-and-forget launch (e.g. `afplay`, `open`).
  void spawn(String exe, List<String> args);

  /// Whether [exe] is resolvable on the PATH.
  Future<bool> exists(String exe);
}

/// The production runner, backed by `dart:io` [Process].
///
/// A GUI-launched .app inherits launchd's minimal PATH (no Homebrew), so tools
/// like `ffmpeg` and `npx` would be unresolvable. Every spawn injects an
/// augmented PATH that includes the common install locations.
class SystemCommandRunner implements CommandRunner {
  const SystemCommandRunner();

  static const _extraPaths = [
    '/opt/homebrew/bin', // Apple Silicon Homebrew (ffmpeg, node/npx)
    '/usr/local/bin', // Intel Homebrew + many installers
    '/usr/bin',
    '/bin',
    '/usr/sbin',
    '/sbin',
  ];

  Map<String, String> get _env {
    final current = Platform.environment['PATH'] ?? '';
    final parts = <String>[
      ...current.split(':').where((p) => p.isNotEmpty),
      for (final p in _extraPaths) if (!current.contains(p)) p,
    ];
    return {'PATH': parts.join(':')};
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
      runInShell: false,
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
      ).catchError((_) => throw ProcessException(exe, args)),
    );
  }

  @override
  Future<bool> exists(String exe) async {
    try {
      // `which` resolves against the augmented PATH we pass through.
      final result = await Process.run(
        '/usr/bin/which',
        [exe],
        environment: _env,
        includeParentEnvironment: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
