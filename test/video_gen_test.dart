import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:openmontage_studio/services/video_gen.dart';

final _bytes = utf8.encode('FAKE-MP4');

void main() {
  test('Veo submits a long-running op, polls done, downloads the mp4', () async {
    var submitted = false;
    final src = VeoVideoSource(
      httpClient: MockClient((req) async {
        if (req.url.path.contains(':predictLongRunning')) {
          submitted = true;
          expect(req.url.queryParameters['key'], 'g-1');
          return http.Response(jsonEncode({'name': 'operations/op1'}), 200);
        }
        if (req.url.path.contains('operations/op1')) {
          return http.Response(
            jsonEncode({
              'done': true,
              'response': {
                'generateVideoResponse': {
                  'generatedSamples': [
                    {'video': {'uri': 'https://gen/file.mp4'}},
                  ],
                },
              },
            }),
            200,
          );
        }
        return http.Response.bytes(_bytes, 200); // download
      }),
    );
    final clip = await src.generate('a neon city flythrough', key: 'g-1', pollInterval: Duration.zero);
    expect(submitted, isTrue);
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('Runway submits, polls SUCCEEDED, downloads', () async {
    final src = RunwayVideoSource(
      httpClient: MockClient((req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/text_to_video')) {
          expect(req.headers['Authorization'], 'Bearer rw-1');
          expect(req.headers['X-Runway-Version'], isNotNull);
          return http.Response(jsonEncode({'id': 'task1'}), 200);
        }
        if (req.url.path.contains('/tasks/task1')) {
          return http.Response(
            jsonEncode({'status': 'SUCCEEDED', 'output': ['https://rw/out.mp4']}),
            200,
          );
        }
        return http.Response.bytes(_bytes, 200);
      }),
    );
    final clip = await src.generate('a product spinning', key: 'rw-1', pollInterval: Duration.zero);
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('Runway uses image_to_video when a first frame is supplied', () async {
    final img = File('${Directory.systemTemp.path}/om_test_init.png')
      ..writeAsBytesSync(_bytes);
    String? postedPath;
    final src = RunwayVideoSource(
      httpClient: MockClient((req) async {
        if (req.method == 'POST') {
          postedPath = req.url.path;
          final b = jsonDecode(req.body) as Map<String, dynamic>;
          expect(b['promptImage'], startsWith('data:image/png;base64,'));
          return http.Response(jsonEncode({'id': 't'}), 200);
        }
        if (req.url.path.contains('/tasks/t')) {
          return http.Response(
            jsonEncode({'status': 'SUCCEEDED', 'output': ['https://x/o.mp4']}),
            200,
          );
        }
        return http.Response.bytes(_bytes, 200);
      }),
    );
    final clip = await src.generate('animate her',
        key: 'k', initImagePath: img.path, pollInterval: Duration.zero);
    expect(postedPath, endsWith('/image_to_video'));
    expect(clip, isNotNull);
  });

  test('local video decodes a base64 clip, no key', () async {
    final src = LocalVideoSource(
      httpClient: MockClient(
        (req) async => http.Response(jsonEncode({'video': base64Encode(_bytes)}), 200),
      ),
    );
    expect(src.needsKey, isFalse);
    final clip = await src.generate('a forest');
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('a failed Veo job throws', () async {
    final src = VeoVideoSource(
      httpClient: MockClient((req) async {
        if (req.url.path.contains(':predictLongRunning')) {
          return http.Response(jsonEncode({'name': 'operations/x'}), 200);
        }
        return http.Response(jsonEncode({'done': true, 'error': {'message': 'boom'}}), 200);
      }),
    );
    expect(
      () => src.generate('x', key: 'k', pollInterval: Duration.zero),
      throwsA(isA<VideoSourceException>()),
    );
  });

  test('empty key or prompt is a no-op (no request)', () async {
    var called = false;
    final src = RunwayVideoSource(
      httpClient: MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    expect(await src.generate('hi', key: ''), isNull);
    expect(await src.generate('', key: 'k'), isNull);
    expect(called, isFalse);
  });
}
