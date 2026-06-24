import 'package:flutter_test/flutter_test.dart';
import 'package:openmontage_studio/services/command_runner.dart';
import 'package:openmontage_studio/services/voice_settings.dart';
import 'package:openmontage_studio/services/voice_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the commands it is asked to run, returning success with a canned
/// `afinfo` duration so synthesis logic can be exercised without real engines.
class _FakeRunner implements CommandRunner {
  final List<String> calls = [];
  @override
  Future<CommandResult> run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    calls.add('$exe ${args.join(' ')}');
    if (exe == 'afinfo') {
      return const CommandResult(0, 'estimated duration: 1.50', '');
    }
    return const CommandResult(0, '', '');
  }

  @override
  void spawn(String exe, List<String> args) => calls.add('spawn:$exe');

  @override
  Future<bool> exists(String exe) async => true;
}

/// A fake voice source that echoes its inputs, so routing/fallback is testable.
class _FakeVoice implements VoiceSource {
  _FakeVoice({this.fail = false});
  final bool fail;
  String? lastKey;
  String? lastVoice;

  @override
  String get id => 'fake';
  @override
  String get label => 'Fake';
  @override
  bool get needsKey => true;
  @override
  String? get keyHint => 'fake';
  @override
  bool get isLocal => false;
  @override
  String get outputExtension => 'mp3';
  @override
  String get defaultVoice => 'Echo';

  @override
  Future<bool> health(CommandRunner runner, {String key = ''}) async => !fail;

  @override
  Future<List<String>> voices(CommandRunner runner, {String key = ''}) async {
    lastKey = key;
    return const ['Echo', 'Nova'];
  }

  @override
  Future<VoiceClip?> synthesize(
    CommandRunner runner,
    String text, {
    String? voice,
    required String outPathBase,
    String key = '',
  }) async {
    if (fail) throw const VoiceException('forced failure');
    lastKey = key;
    lastVoice = voice;
    return VoiceClip(
      path: '$outPathBase.$outputExtension',
      voice: voice ?? defaultVoice,
      bytes: 10,
      seconds: 2,
    );
  }
}

void main() {
  test('defaults to the system source', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = VoiceSettings(
      sources: [const SystemVoiceSource(), _FakeVoice()],
      prefs: await SharedPreferences.getInstance(),
    );
    await settings.load();
    expect(settings.selectedId, 'system');
  });

  test('persists the selected source, key, and voice name', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = VoiceSettings(
      sources: [const SystemVoiceSource(), _FakeVoice()],
      prefs: prefs,
    );
    await settings.load();
    await settings.setSource('fake');
    await settings.setKey('fake', 'k-123');
    await settings.setVoiceName('Nova');

    expect(settings.selectedId, 'fake');
    expect(settings.voiceName, 'Nova');

    final reloaded = VoiceSettings(
      sources: [const SystemVoiceSource(), _FakeVoice()],
      prefs: prefs,
    );
    await reloaded.load();
    expect(reloaded.selectedId, 'fake');
    expect(reloaded.keyFor('fake'), 'k-123');
    expect(reloaded.voiceName, 'Nova');
  });

  test('synthesizes through the selected source with its key and voice',
      () async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeVoice();
    final settings = VoiceSettings(
      sources: [const SystemVoiceSource(), fake],
      prefs: await SharedPreferences.getInstance(),
    );
    await settings.load();
    await settings.setSource('fake');
    await settings.setKey('fake', 'secret');

    final clip = await settings.synthesize(
      _FakeRunner(),
      'hello world',
      outPathBase: '/tmp/x',
      voice: 'Nova',
    );
    expect(clip, isNotNull);
    expect(fake.lastKey, 'secret');
    expect(fake.lastVoice, 'Nova');
    expect(clip!.path, '/tmp/x.mp3');
  });

  test('falls back to the system voice when a cloud source fails', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = VoiceSettings(
      sources: [const SystemVoiceSource(), _FakeVoice(fail: true)],
      prefs: await SharedPreferences.getInstance(),
    );
    await settings.load();
    await settings.setSource('fake');

    final runner = _FakeRunner();
    final clip = await settings.synthesize(
      runner,
      'narration',
      outPathBase: '/tmp/y',
    );
    // The cloud source threw; the system voice produced the clip instead.
    expect(clip, isNotNull);
    // On macOS the system engine is `say`; on other hosts it is the OS engine.
    expect(runner.calls.any((c) => c.startsWith('say ') ||
        c.startsWith('powershell ') || c.startsWith('espeak-ng ')), isTrue);
  });
}
