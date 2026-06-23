import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_version.dart';

/// The result of an update check.
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.latest,
    required this.url,
    this.notes,
  });

  final bool available;
  final String latest;
  final String url;
  final String? notes;
}

/// Checks a published version manifest (`version.json`) against the running
/// app version. The manifest looks like:
///   { "version": "1.1.0", "url": "https://.../OpenMontageStudio.dmg",
///     "notes": "What's new" }
class UpdateChecker {
  UpdateChecker({
    this.manifestUrl = 'https://get.opencli.ai/version.json',
    this.currentVersion = kAppVersion,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String manifestUrl;
  final String currentVersion;
  final http.Client _http;

  /// Returns update info, or null if the check failed (offline, etc.).
  Future<UpdateInfo?> check() async {
    try {
      final res = await _http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = j['version'] as String? ?? currentVersion;
      return UpdateInfo(
        available: isNewer(latest, currentVersion),
        latest: latest,
        url: j['url'] as String? ?? '',
        notes: j['notes'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether [a] is a newer semver than [b] (compares major.minor.patch).
  static bool isNewer(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
