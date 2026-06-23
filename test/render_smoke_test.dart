import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmontage_studio/services/render_client.dart';

// Real end-to-end render checks through the production SystemCommandRunner
// (say + ffmpeg + npx remotion). Slow and host-dependent, so skipped by default;
// run with: RUN_RENDER_SMOKE=1 flutter test test/render_smoke_test.dart
final _skip = Platform.environment['RUN_RENDER_SMOKE'] != '1'
    ? 'set RUN_RENDER_SMOKE=1 to run the real render checks'
    : null;

void main() {
  const scenes = [
    {
      'title': 'hook',
      'type': 'hero_title',
      'headline': 'The Ocean',
      'subtitle': 'a short tour',
      'seconds': 2,
      'accent': '22D3EE',
    },
    {
      'title': 'stat',
      'type': 'stat_card',
      'headline': '71%',
      'subtitle': 'of Earth is water',
      'seconds': 2,
      'accent': 'A78BFA',
    },
    {
      'title': 'cities',
      'type': 'bar_chart',
      'headline': 'Biggest oceans',
      'subtitle': 'Pacific · Atlantic · Indian',
      'seconds': 3,
      'accent': '34D399',
    },
  ];

  test('ffmpeg runtime renders a real MP4', () async {
    final result = await RenderClient().render(scenes, runtime: 'ffmpeg');
    expect(File(result.path).existsSync(), isTrue);
    expect(result.bytes, greaterThan(5000));
    // ignore: avoid_print
    print('FFMPEG_OK ${result.path} ${result.bytes}B ${result.seconds}s');
  }, timeout: const Timeout(Duration(minutes: 3)), skip: _skip);

  test('remotion runtime renders a real cinematic MP4', () async {
    final client = RenderClient();
    final runtimes = await client.runtimes();
    if (!runtimes.contains('remotion')) {
      // ignore: avoid_print
      print('REMOTION_SKIPPED runtimes=$runtimes');
      return;
    }
    final result = await client.render(scenes, runtime: 'remotion');
    expect(File(result.path).existsSync(), isTrue);
    expect(result.bytes, greaterThan(5000));
    // ignore: avoid_print
    print('REMOTION_OK ${result.path} ${result.bytes}B ${result.seconds}s');
  }, timeout: const Timeout(Duration(minutes: 8)), skip: _skip);
}
