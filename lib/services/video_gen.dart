import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A generated video clip, saved locally so it drops into a scene's clipPath and
/// renders through the same pipeline as uploaded footage / digital humans.
class GeneratedVideo {
  const GeneratedVideo({required this.path});
  final String path;
}

/// A pluggable source of AI-generated video (text/image -> motion). Cloud
/// sources are BYOK; the local source talks to an on-device model server. All
/// return an mp4, so the editor reuses the UGC clip pipeline.
abstract class VideoSource {
  String get id;
  String get label;
  bool get needsKey;
  String? get keyHint => null;

  /// Generates a clip for [prompt]. [initImagePath] optionally seeds
  /// image-to-video. [pollInterval] is exposed so tests drive the async job.
  Future<GeneratedVideo?> generate(
    String prompt, {
    String key = '',
    String initImagePath = '',
    Duration pollInterval = const Duration(seconds: 6),
    Duration maxWait = const Duration(minutes: 8),
  });
}

class NoneVideoSource implements VideoSource {
  const NoneVideoSource();
  @override
  String get id => 'none';
  @override
  String get label => 'None';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => null;
  @override
  Future<GeneratedVideo?> generate(
    String prompt, {
    String key = '',
    String initImagePath = '',
    Duration pollInterval = const Duration(seconds: 6),
    Duration maxWait = const Duration(minutes: 8),
  }) async => null;
}

Future<String> _saveVideoBytes(List<int> bytes) async {
  final dir = Directory('${Directory.systemTemp.path}/openmontage-media/aivideo')
    ..createSync(recursive: true);
  final file = File('${dir.path}/clip_${bytes.length}.mp4');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Drives a "wait until done" loop with a hard deadline; tests pass
/// pollInterval: zero to run a single pass.
Future<T?> _pollUntil<T>(
  Duration pollInterval,
  Duration maxWait,
  Future<T?> Function() attempt,
) async {
  final deadline = maxWait.inMilliseconds;
  var waited = 0;
  while (waited <= deadline) {
    final r = await attempt();
    if (r != null) return r;
    if (pollInterval > Duration.zero) await Future<void>.delayed(pollInterval);
    waited += pollInterval.inMilliseconds == 0 ? deadline + 1 : pollInterval.inMilliseconds;
  }
  return null;
}

/// Google Veo via the Gemini API (BYOK). Real generative video incl. people and
/// audio (Veo 3). Submits a long-running op, polls it, downloads the mp4.
/// Requires a billing-enabled key — the free tier has no Veo quota.
class VeoVideoSource implements VideoSource {
  VeoVideoSource({http.Client? httpClient, this.model = 'veo-3.0-fast-generate-001'})
    : _http = httpClient ?? http.Client();
  final http.Client _http;
  final String model;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  String get id => 'veo';
  @override
  String get label => 'Google Veo (AI video, needs billing)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Gemini key with billing on — aistudio.google.com';

  @override
  Future<GeneratedVideo?> generate(
    String prompt, {
    String key = '',
    String initImagePath = '',
    Duration pollInterval = const Duration(seconds: 6),
    Duration maxWait = const Duration(minutes: 8),
  }) async {
    if (key.isEmpty || prompt.trim().isEmpty) return null;
    // Image-to-video: seed the first frame from the supplied photo.
    final initB64 = initImagePath.isNotEmpty && File(initImagePath).existsSync()
        ? base64Encode(await File(initImagePath).readAsBytes())
        : null;
    final submit = await _http
        .post(
          Uri.parse('$_base/models/$model:predictLongRunning?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'instances': [
              {
                'prompt': prompt,
                if (initB64 != null)
                  'image': {
                    'bytesBase64Encoded': initB64,
                    'mimeType': 'image/png',
                  },
              },
            ],
            'parameters': {'aspectRatio': '16:9'},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (submit.statusCode != 200) {
      throw VideoSourceException('Veo submit HTTP ${submit.statusCode}');
    }
    final opName = jsonDecode(submit.body)['name'] as String?;
    if (opName == null) return null;

    final uri = await _pollUntil<String>(pollInterval, maxWait, () async {
      final st = await _http
          .get(Uri.parse('$_base/$opName?key=$key'))
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(st.body) as Map<String, dynamic>;
      if (body['error'] != null) {
        throw VideoSourceException('Veo job failed');
      }
      if (body['done'] != true) return null;
      final resp = body['response'] as Map<String, dynamic>?;
      final samples = ((resp?['generateVideoResponse']
              as Map<String, dynamic>?)?['generatedSamples'] as List?) ??
          (resp?['generatedSamples'] as List?) ??
          const [];
      if (samples.isEmpty) return null;
      final video = (samples.first as Map<String, dynamic>)['video'] as Map?;
      return video?['uri'] as String?;
    });
    if (uri == null) return null;

    // The file URI needs the key appended to download.
    final dl = uri.contains('key=') ? uri : '$uri${uri.contains('?') ? '&' : '?'}key=$key';
    final res = await _http.get(Uri.parse(dl)).timeout(const Duration(seconds: 180));
    return GeneratedVideo(path: await _saveVideoBytes(res.bodyBytes));
  }
}

/// Runway Gen-4 (BYOK). Text/image-to-video; submits a task, polls, downloads.
class RunwayVideoSource implements VideoSource {
  RunwayVideoSource({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;

  static const _base = 'https://api.dev.runwayml.com/v1';
  static const _version = '2024-11-06';

  @override
  String get id => 'runway';
  @override
  String get label => 'Runway Gen-4 (AI video)';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'Key at dev.runwayml.com';

  @override
  Future<GeneratedVideo?> generate(
    String prompt, {
    String key = '',
    String initImagePath = '',
    Duration pollInterval = const Duration(seconds: 6),
    Duration maxWait = const Duration(minutes: 8),
  }) async {
    if (key.isEmpty || prompt.trim().isEmpty) return null;
    final headers = {
      'Authorization': 'Bearer $key',
      'X-Runway-Version': _version,
      'Content-Type': 'application/json',
    };
    // Image-to-video (Gen-4) when a first frame is supplied, else text-to-video.
    final hasInit = initImagePath.isNotEmpty && File(initImagePath).existsSync();
    final endpoint = hasInit ? 'image_to_video' : 'text_to_video';
    final body = <String, dynamic>{
      'promptText': prompt,
      'model': 'gen4_turbo',
      'ratio': '1280:720',
    };
    if (hasInit) {
      final b64 = base64Encode(await File(initImagePath).readAsBytes());
      body['promptImage'] = 'data:image/png;base64,$b64';
    }
    final submit = await _http
        .post(
          Uri.parse('$_base/$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (submit.statusCode != 200 && submit.statusCode != 201) {
      throw VideoSourceException('Runway submit HTTP ${submit.statusCode}');
    }
    final id = jsonDecode(submit.body)['id'] as String?;
    if (id == null) return null;

    final url = await _pollUntil<String>(pollInterval, maxWait, () async {
      final st = await _http
          .get(Uri.parse('$_base/tasks/$id'), headers: headers)
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(st.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status == 'FAILED') throw VideoSourceException('Runway job failed');
      if (status != 'SUCCEEDED') return null;
      final output = body['output'] as List?;
      return (output != null && output.isNotEmpty) ? output.first as String : null;
    });
    if (url == null) return null;
    final res = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 180));
    return GeneratedVideo(path: await _saveVideoBytes(res.bodyBytes));
  }
}

/// Local text-to-video via an on-device model server (ComfyUI/WAN/Hunyuan behind
/// a small HTTP wrapper). Free, no key, GPU-dependent.
class LocalVideoSource implements VideoSource {
  LocalVideoSource({http.Client? httpClient, String? endpoint})
    : _http = httpClient ?? http.Client(),
      _endpoint = endpoint ?? 'http://127.0.0.1:8200';
  final http.Client _http;
  final String _endpoint;

  @override
  String get id => 'local_video';
  @override
  String get label => 'Local AI video (free, GPU)';
  @override
  bool get needsKey => false;
  @override
  String? get keyHint => 'Runs against a local text-to-video server on :8200';

  @override
  Future<GeneratedVideo?> generate(
    String prompt, {
    String key = '',
    String initImagePath = '',
    Duration pollInterval = const Duration(seconds: 6),
    Duration maxWait = const Duration(minutes: 8),
  }) async {
    if (prompt.trim().isEmpty) return null;
    final initB64 = initImagePath.isNotEmpty && File(initImagePath).existsSync()
        ? base64Encode(await File(initImagePath).readAsBytes())
        : null;
    final res = await _http
        .post(
          Uri.parse('$_endpoint/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': prompt, 'init_image': ?initB64}),
        )
        .timeout(maxWait);
    if (res.statusCode != 200) {
      throw VideoSourceException('Local video HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final b64 = body['video'] as String?;
    if (b64 != null) {
      return GeneratedVideo(path: await _saveVideoBytes(base64Decode(b64)));
    }
    final url = body['url'] as String?;
    if (url == null) return null;
    final v = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 180));
    return GeneratedVideo(path: await _saveVideoBytes(v.bodyBytes));
  }
}

class VideoSourceException implements Exception {
  const VideoSourceException(this.message);
  final String message;
  @override
  String toString() => 'VideoSourceException: $message';
}
