import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmontage_studio/models/studio_models.dart';

void main() {
  Scene base() => const Scene(
    id: 's1',
    type: 'text_card',
    title: 'Hook',
    startSeconds: 0,
    endSeconds: 4,
    accent: Colors.indigo,
    headline: 'Buy now',
  );

  test('a scene has no clip by default', () {
    final s = base();
    expect(s.hasClip, isFalse);
    expect(s.clipPath, isEmpty);
    expect(s.toJson().containsKey('clipPath'), isFalse);
  });

  test('attaching an uploaded clip is reflected and survives a round-trip', () {
    final s = base().copyWith(clipPath: '/tmp/me.mp4', type: 'footage_clip');
    expect(s.hasClip, isTrue);
    expect(s.clipPath, '/tmp/me.mp4');
    expect(s.toJson()['clipPath'], '/tmp/me.mp4');

    final restored = Scene.fromJson(s.toJson());
    expect(restored.clipPath, '/tmp/me.mp4');
    expect(restored.type, 'footage_clip');
    expect(restored.hasClip, isTrue);
  });

  test('copyWith preserves an existing clip when other fields change', () {
    final s = base().copyWith(clipPath: '/tmp/me.mp4');
    final edited = s.copyWith(headline: 'New headline');
    expect(edited.clipPath, '/tmp/me.mp4');
    expect(edited.headline, 'New headline');
  });
}
