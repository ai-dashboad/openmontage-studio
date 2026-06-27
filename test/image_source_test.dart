import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:openmontage_studio/services/image_source.dart';

/// A 1x1 PNG, base64 — stands in for a generated image.
const _pngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9'
    'awAAAABJRU5ErkJggg==';

void main() {
  test('FAL returns the generated image URL and sends a Key header', () async {
    String? auth;
    Map<String, dynamic>? sent;
    final src = FalImageSource(
      httpClient: MockClient((req) async {
        auth = req.headers['Authorization'];
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'images': [
              {'url': 'https://fal/out.png'},
            ],
          }),
          200,
        );
      }),
    );
    final img = await src.resolve('a neon city', key: 'k123');
    expect(img?.url, 'https://fal/out.png');
    expect(auth, 'Key k123');
    // The query is shaped into an ad-ready prompt.
    expect(sent!['prompt'], contains('a neon city'));
    expect(sent!['prompt'], contains('no text'));
  });

  test('OpenAI DALL·E returns the hosted URL', () async {
    final src = OpenAiImageSource(
      httpClient: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer sk-1');
        return http.Response(
          jsonEncode({
            'data': [
              {'url': 'https://oai/img.png'},
            ],
          }),
          200,
        );
      }),
    );
    final img = await src.resolve('mountain sunrise', key: 'sk-1');
    expect(img?.url, 'https://oai/img.png');
  });

  test('Grok returns the hosted URL', () async {
    final src = GrokImageSource(
      httpClient: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'data': [
              {'url': 'https://xai/g.png'},
            ],
          }),
          200,
        ),
      ),
    );
    final img = await src.resolve('a fox', key: 'xai-1');
    expect(img?.url, 'https://xai/g.png');
  });

  test('Gemini decodes inline base64 to a local file', () async {
    final src = GeminiImageSource(
      httpClient: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {'mimeType': 'image/png', 'data': _pngB64},
                    },
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    final img = await src.resolve('a calm lake', key: 'g-1');
    expect(img, isNotNull);
    final file = File(img!.url);
    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), base64Decode(_pngB64));
  });

  test('Local SD decodes the returned base64 image to a file, no key', () async {
    final src = LocalDiffusionImageSource(
      httpClient: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'images': [_pngB64],
          }),
          200,
        ),
      ),
    );
    expect(src.needsKey, isFalse);
    final img = await src.resolve('forest path');
    expect(img, isNotNull);
    expect(File(img!.url).existsSync(), isTrue);
  });

  test('a generative source surfaces HTTP errors', () async {
    final src = FalImageSource(
      httpClient: MockClient((req) async => http.Response('nope', 401)),
    );
    expect(
      () => src.resolve('x', key: 'bad'),
      throwsA(isA<ImageSourceException>()),
    );
  });

  test('empty key or query resolves to null without a request', () async {
    var called = false;
    final src = OpenAiImageSource(
      httpClient: MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    expect(await src.resolve('something', key: ''), isNull);
    expect(await src.resolve('', key: 'sk-1'), isNull);
    expect(called, isFalse);
  });
}
