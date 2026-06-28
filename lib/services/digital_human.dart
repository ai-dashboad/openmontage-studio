import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A generated presenter clip (a lip-synced "digital human" speaking the
/// script), saved locally so it drops straight into a scene's clipPath and
/// renders through the same pipeline as uploaded UGC footage.
class PresenterClip {
  const PresenterClip({required this.path});
  final String path;
}

/// A pluggable source of digital-human / presenter video. Cloud sources are
/// BYOK (the user pastes their own key; generation is billed to their account);
/// the local source talks to an on-device lip-sync server for a free option.
/// All return a video file, so the editor reuses the UGC footage pipeline.
abstract class DigitalHumanSource {
  String get id;
  String get label;
  bool get needsKey;
  String? get keyHint => null;

  /// Generates a presenter clip speaking [script]. Returns null on no-op/failure.
  /// [pollInterval] is exposed so tests can drive the async job without waiting.
  Future<PresenterClip?> generate(
    String script, {
    String key = '',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 5),
  });
}

/// The "off" source — scenes use designed cards or uploaded footage instead.
class NoneDigitalHuman implements DigitalHumanSource {
  const NoneDigitalHuman();
  @override
  String get id => 'none';
  @override
  String get label => 'None';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => null;
  @override
  Future<PresenterClip?> generate(
    String script, {
    String key = '',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 5),
  }) async => null;
}

/// Saves downloaded video bytes to a temp file the editor/renderer can read.
Future<String> _savePresenterBytes(List<int> bytes) async {
  final dir = Directory('${Directory.systemTemp.path}/openmontage-media/presenter')
    ..createSync(recursive: true);
  final file = File('${dir.path}/presenter_${bytes.length}.mp4');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// HeyGen — high-quality cloud avatars (BYOK). Submits a generate job, polls for
/// completion, then downloads the finished MP4.
class HeyGenSource implements DigitalHumanSource {
  HeyGenSource({http.Client? httpClient, this.avatarId = 'default', this.voiceId = 'default'})
    : _http = httpClient ?? http.Client();
  final http.Client _http;
  final String avatarId;
  final String voiceId;

  @override
  String get id => 'heygen';
  @override
  String get label => 'HeyGen (cloud avatar)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at app.heygen.com — Settings › API';

  @override
  Future<PresenterClip?> generate(
    String script, {
    String key = '',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 5),
  }) async {
    if (key.isEmpty || script.trim().isEmpty) return null;
    final submit = await _http
        .post(
          Uri.parse('https://api.heygen.com/v2/video/generate'),
          headers: {'X-Api-Key': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'video_inputs': [
              {
                'character': {'type': 'avatar', 'avatar_id': avatarId},
                'voice': {'type': 'text', 'input_text': script, 'voice_id': voiceId},
              },
            ],
            'dimension': {'width': 1920, 'height': 1080},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (submit.statusCode != 200) {
      throw DigitalHumanException('HeyGen submit HTTP ${submit.statusCode}');
    }
    final videoId = ((jsonDecode(submit.body)['data'] as Map?)?['video_id']) as String?;
    if (videoId == null) return null;

    final deadline = maxWait.inMilliseconds;
    var waited = 0;
    while (waited <= deadline) {
      final st = await _http.get(
        Uri.parse('https://api.heygen.com/v1/video_status.get?video_id=$videoId'),
        headers: {'X-Api-Key': key},
      ).timeout(const Duration(seconds: 30));
      final data = (jsonDecode(st.body)['data'] as Map?) ?? const {};
      final status = data['status'] as String?;
      if (status == 'completed' || status == 'success') {
        final url = data['video_url'] as String?;
        if (url == null) return null;
        return PresenterClip(path: await _download(url));
      }
      if (status == 'failed') {
        throw const DigitalHumanException('HeyGen reported the job failed');
      }
      if (pollInterval > Duration.zero) await Future<void>.delayed(pollInterval);
      waited += pollInterval.inMilliseconds == 0 ? deadline + 1 : pollInterval.inMilliseconds;
    }
    throw const DigitalHumanException('HeyGen timed out');
  }

  Future<String> _download(String url) async {
    final res = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 120));
    return _savePresenterBytes(res.bodyBytes);
  }
}

/// D-ID — talking-head from a portrait (BYOK). Submits a talk, polls, downloads.
class DidSource implements DigitalHumanSource {
  DidSource({http.Client? httpClient, this.portraitUrl})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  /// The presenter face. D-ID requires a source portrait URL; a sensible default
  /// can be overridden so the user brings their own face.
  final String? portraitUrl;

  @override
  String get id => 'did';
  @override
  String get label => 'D-ID (talking portrait)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at studio.d-id.com — API';

  @override
  Future<PresenterClip?> generate(
    String script, {
    String key = '',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 5),
  }) async {
    if (key.isEmpty || script.trim().isEmpty) return null;
    final auth = 'Basic ${base64Encode(utf8.encode(key))}';
    final submit = await _http
        .post(
          Uri.parse('https://api.d-id.com/talks'),
          headers: {'Authorization': auth, 'Content-Type': 'application/json'},
          body: jsonEncode({
            if (portraitUrl != null) 'source_url': portraitUrl,
            'script': {'type': 'text', 'input': script},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (submit.statusCode != 200 && submit.statusCode != 201) {
      throw DigitalHumanException('D-ID submit HTTP ${submit.statusCode}');
    }
    final id = jsonDecode(submit.body)['id'] as String?;
    if (id == null) return null;

    final deadline = maxWait.inMilliseconds;
    var waited = 0;
    while (waited <= deadline) {
      final st = await _http.get(
        Uri.parse('https://api.d-id.com/talks/$id'),
        headers: {'Authorization': auth},
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(st.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status == 'done') {
        final url = body['result_url'] as String?;
        if (url == null) return null;
        final res = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 120));
        return PresenterClip(path: await _savePresenterBytes(res.bodyBytes));
      }
      if (status == 'error' || status == 'rejected') {
        throw const DigitalHumanException('D-ID reported the job failed');
      }
      if (pollInterval > Duration.zero) await Future<void>.delayed(pollInterval);
      waited += pollInterval.inMilliseconds == 0 ? deadline + 1 : pollInterval.inMilliseconds;
    }
    throw const DigitalHumanException('D-ID timed out');
  }
}

/// Local lip-sync via an on-device server (SadTalker / Wav2Lip / LivePortrait
/// behind a small HTTP wrapper). Free, no key, GPU-dependent. Returns the video
/// as base64 or a URL.
class LocalLipSyncSource implements DigitalHumanSource {
  LocalLipSyncSource({http.Client? httpClient, String? endpoint})
    : _http = httpClient ?? http.Client(),
      _endpoint = endpoint ?? 'http://127.0.0.1:8190';
  final http.Client _http;
  final String _endpoint;

  @override
  String get id => 'local_lipsync';
  @override
  String get label => 'Local lip-sync (free, GPU)';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => 'Runs against a local lip-sync server on :8190';

  @override
  Future<PresenterClip?> generate(
    String script, {
    String key = '',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 5),
  }) async {
    if (script.trim().isEmpty) return null;
    final res = await _http
        .post(
          Uri.parse('$_endpoint/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'script': script}),
        )
        .timeout(maxWait);
    if (res.statusCode != 200) {
      throw DigitalHumanException('Local lip-sync HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final b64 = body['video'] as String?;
    if (b64 != null) {
      return PresenterClip(path: await _savePresenterBytes(base64Decode(b64)));
    }
    final url = body['url'] as String?;
    if (url == null) return null;
    final v = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 120));
    return PresenterClip(path: await _savePresenterBytes(v.bodyBytes));
  }
}

class DigitalHumanException implements Exception {
  const DigitalHumanException(this.message);
  final String message;
  @override
  String toString() => 'DigitalHumanException: $message';
}
