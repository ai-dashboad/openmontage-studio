import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:openmontage_studio/services/digital_human.dart';

final _videoBytes = utf8.encode('FAKE-MP4-BYTES');

void main() {
  test('HeyGen submits, polls to completion, and downloads the clip', () async {
    var submitted = false, polled = false;
    final src = HeyGenSource(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/v2/video/generate')) {
          submitted = true;
          expect(req.headers['X-Api-Key'], 'hg-1');
          return http.Response(jsonEncode({'data': {'video_id': 'vid1'}}), 200);
        }
        if (req.url.path.contains('video_status')) {
          polled = true;
          return http.Response(
            jsonEncode({'data': {'status': 'completed', 'video_url': 'https://hg/v.mp4'}}),
            200,
          );
        }
        return http.Response.bytes(_videoBytes, 200); // download
      }),
    );
    final clip = await src.generate('Hello world', key: 'hg-1', pollInterval: Duration.zero);
    expect(submitted, isTrue);
    expect(polled, isTrue);
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('D-ID submits with Basic auth, polls done, downloads', () async {
    final src = DidSource(
      portraitUrl: 'https://face/p.jpg',
      httpClient: MockClient((req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/talks')) {
          expect(req.headers['Authorization'], startsWith('Basic '));
          return http.Response(jsonEncode({'id': 'talk1'}), 201);
        }
        if (req.method == 'GET' && req.url.path.contains('/talks/talk1')) {
          return http.Response(
            jsonEncode({'status': 'done', 'result_url': 'https://did/r.mp4'}),
            200,
          );
        }
        return http.Response.bytes(_videoBytes, 200);
      }),
    );
    final clip = await src.generate('Pitch', key: 'did-1', pollInterval: Duration.zero);
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('local lip-sync decodes a base64 video, no key', () async {
    final src = LocalLipSyncSource(
      httpClient: MockClient(
        (req) async => http.Response(
          jsonEncode({'video': base64Encode(_videoBytes)}),
          200,
        ),
      ),
    );
    expect(src.needsKey, isFalse);
    final clip = await src.generate('Hi');
    expect(clip, isNotNull);
    expect(File(clip!.path).existsSync(), isTrue);
  });

  test('a failed cloud job throws', () async {
    final src = HeyGenSource(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/v2/video/generate')) {
          return http.Response(jsonEncode({'data': {'video_id': 'v'}}), 200);
        }
        return http.Response(jsonEncode({'data': {'status': 'failed'}}), 200);
      }),
    );
    expect(
      () => src.generate('x', key: 'k', pollInterval: Duration.zero),
      throwsA(isA<DigitalHumanException>()),
    );
  });

  test('empty key or script is a no-op (no request)', () async {
    var called = false;
    final src = HeyGenSource(
      httpClient: MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    expect(await src.generate('hello', key: ''), isNull);
    expect(await src.generate('', key: 'k'), isNull);
    expect(called, isFalse);
  });
}
