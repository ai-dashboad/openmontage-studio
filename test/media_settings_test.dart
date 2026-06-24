import 'package:flutter_test/flutter_test.dart';
import 'package:openmontage_studio/services/image_source.dart';
import 'package:openmontage_studio/services/media_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake source that echoes the query back as a fake URL, recording the key.
class _FakeSource implements ImageSource {
  String? lastKey;
  @override
  String get id => 'fake';
  @override
  String get label => 'Fake';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'fake';
  @override
  Future<SceneImage?> resolve(String query, {String key = ''}) async {
    lastKey = key;
    return SceneImage(url: 'https://img/${query.replaceAll(' ', '+')}');
  }
}

void main() {
  test('defaults to none and is inactive', () async {
    SharedPreferences.setMockInitialValues({});
    final media = MediaSettings(
      sources: [const NoneImageSource(), _FakeSource()],
      prefs: await SharedPreferences.getInstance(),
    );
    await media.load();
    expect(media.selectedId, 'none');
    expect(media.isActive, isFalse);
    expect(await media.resolve('ocean'), isNull); // none resolves to nothing
  });

  test('selected source resolves with its stored key and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeSource();
    final media = MediaSettings(
      sources: [const NoneImageSource(), fake],
      prefs: prefs,
    );
    await media.load();
    await media.setSource('fake');
    await media.setKey('fake', 'secret-key');

    expect(media.isActive, isTrue);
    final image = await media.resolve('ocean waves');
    expect(image, isNotNull);
    expect(image!.url, 'https://img/ocean+waves');
    expect(fake.lastKey, 'secret-key');

    // A fresh instance reads the persisted choice + key.
    final reloaded = MediaSettings(
      sources: [const NoneImageSource(), _FakeSource()],
      prefs: prefs,
    );
    await reloaded.load();
    expect(reloaded.selectedId, 'fake');
    expect(reloaded.keyFor('fake'), 'secret-key');
  });
}
