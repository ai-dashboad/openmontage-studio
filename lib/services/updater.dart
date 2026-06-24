import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

/// One-click auto-update via the `auto_updater` plugin — Sparkle on macOS and
/// WinSparkle on Windows. Points at the platform's appcast feed and lets the
/// framework check, download, verify (EdDSA), install, and relaunch. Wrapped so
/// it never breaks startup or tests, and a no-op on unsupported hosts.
class Updater {
  static const String _macFeed = 'https://get.opencli.ai/appcast.xml';
  static const String _winFeed = 'https://get.opencli.ai/appcast-win.xml';

  /// The appcast feed for the current platform, or null when unsupported.
  static String? get feedUrl {
    if (Platform.isMacOS) return _macFeed;
    if (Platform.isWindows) return _winFeed;
    return null;
  }

  bool get _supported => Platform.isMacOS || Platform.isWindows;

  /// Sets the feed and schedules background checks. Call once at launch.
  Future<void> init() async {
    final feed = feedUrl;
    if (!_supported || feed == null) return;
    try {
      await autoUpdater.setFeedURL(feed);
      // Sparkle's minimum is 1h; check a few times a day.
      await autoUpdater.setScheduledCheckInterval(3600 * 6);
    } catch (_) {
      // Updates are a nicety; never let this block startup.
    }
  }

  /// Manually checks now, showing the native update prompt.
  Future<void> checkNow() async {
    if (!_supported) return;
    try {
      await autoUpdater.checkForUpdates();
    } catch (_) {}
  }
}
