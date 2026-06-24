import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

/// One-click auto-update via Sparkle (the `auto_updater` plugin). Points at the
/// appcast feed and lets Sparkle check, download, verify (EdDSA), install, and
/// relaunch. Guarded to macOS and wrapped so it never breaks startup or tests.
class Updater {
  static const String feedUrl = 'https://get.opencli.ai/appcast.xml';

  /// Sets the feed and schedules background checks. Call once at launch.
  Future<void> init() async {
    if (!Platform.isMacOS) return;
    try {
      await autoUpdater.setFeedURL(feedUrl);
      // Sparkle's minimum is 1h; check a few times a day.
      await autoUpdater.setScheduledCheckInterval(3600 * 6);
    } catch (_) {
      // Updates are a nicety; never let this block startup.
    }
  }

  /// Manually checks now, showing Sparkle's native update prompt.
  Future<void> checkNow() async {
    if (!Platform.isMacOS) return;
    try {
      await autoUpdater.checkForUpdates();
    } catch (_) {}
  }
}
