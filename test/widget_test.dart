// Widget tests covering navigation (home -> studio -> settings), the render
// dialog, the studio wiring, and the live agent chat (backed by a mock Ollama).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:openmontage_studio/main.dart';
import 'package:openmontage_studio/services/agent_service.dart';
import 'package:openmontage_studio/services/auth_client.dart';
import 'package:openmontage_studio/services/command_runner.dart';
import 'package:openmontage_studio/services/ollama_client.dart';
import 'package:openmontage_studio/services/provider_manager.dart';
import 'package:openmontage_studio/services/render_client.dart';
import 'package:openmontage_studio/services/tts_client.dart';
import 'package:openmontage_studio/services/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake command runner so the media clients exercise their real logic without
/// spawning say/ffmpeg. `npx` is reported absent so Remotion isn't offered.
class _FakeRunner implements CommandRunner {
  @override
  Future<CommandResult> run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    if (exe == 'afinfo') {
      return const CommandResult(0, 'estimated duration: 2.30', '');
    }
    if (exe == 'say' && args.contains('?')) {
      return const CommandResult(
        0,
        'Samantha            en_US    # hi\nAlex                en_US    # hi',
        '',
      );
    }
    return const CommandResult(0, '', '');
  }

  @override
  void spawn(String exe, List<String> args) {}

  @override
  Future<bool> exists(String exe) async => exe == 'say' || exe == 'ffmpeg';
}

const _testAccount = Account(
  id: 'tester',
  email: 'tester@example.com',
  emailVerified: true,
);

// The shell targets a minimum desktop window of 1100x720.
const _desktop = Size(1280, 832);

/// A mock Ollama that reports one model and echoes a canned reply, so the agent
/// path is exercised without touching the network.
AgentService _mockAgent({String reply = 'Here is a three-beat plan.'}) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/api/tags')) {
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'qwen2.5:latest'},
          ],
        }),
        200,
      );
    }
    if (request.url.path.endsWith('/api/chat')) {
      return http.Response(
        jsonEncode({
          'message': {'role': 'assistant', 'content': reply},
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
  return AgentService(ollama: OllamaClient(httpClient: client));
}

/// Media clients backed by the fake runner — exercise real client logic with no
/// real processes.
TtsClient _mockTts() => TtsClient(runner: _FakeRunner());
RenderClient _mockRender() => RenderClient(runner: _FakeRunner());

/// A mock update checker that reports the given latest [version] (default the
/// current one, i.e. no update), without hitting the network.
UpdateChecker _mockUpdate({String version = '1.0.0'}) {
  final client = MockClient(
    (req) async => http.Response(
      jsonEncode({
        'version': version,
        'url': 'https://x/app.dmg',
        'notes': 'New',
      }),
      200,
    ),
  );
  return UpdateChecker(httpClient: client, currentVersion: '1.0.0');
}

/// Boots the app at desktop size with mock-backed local providers.
Future<void> _boot(
  WidgetTester tester, {
  AgentService? agent,
  TtsClient? tts,
  RenderClient? render,
  UpdateChecker? update,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final a = agent ?? _mockAgent();
  final t = tts ?? _mockTts();
  final r = render ?? _mockRender();
  await tester.pumpWidget(
    OpenMontageStudioApp(
      agentService: a,
      ttsClient: t,
      renderClient: r,
      updateChecker: update ?? _mockUpdate(),
      providerManager: ProviderManager(agent: a, media: t, runner: _FakeRunner()),
      initialAccount: _testAccount, // bypass the auth gate
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterStudio(WidgetTester tester) async {
  await tester.tap(find.text('Generate ad'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to the home launcher with the prompt hero', (tester) async {
    await _boot(tester);

    expect(find.text('OpenMontage Studio'), findsOneWidget);
    expect(find.text('What ad are we making today?'), findsOneWidget);
    expect(find.text('Generate ad'), findsOneWidget);
  });

  testWidgets('home shows an update banner when a newer version exists', (
    tester,
  ) async {
    await _boot(tester, update: _mockUpdate(version: '2.0.0'));
    expect(find.textContaining('Version 2.0.0 is available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('home opens the studio and shows the pipeline', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('scene_plan'), findsWidgets);
    expect(find.textContaining('Composition · ready'), findsOneWidget);
  });

  testWidgets('a brief generates a plan that drives the studio', (
    tester,
  ) async {
    const planJson =
        '[{"title":"Cosmic Hook","type":"hero_title","seconds":4,'
        '"headline":"Black Holes","subtitle":"intro"},'
        '{"title":"Event Horizon","type":"text_card","seconds":6,'
        '"headline":"The point of no return","subtitle":"why"},'
        '{"title":"Close","type":"text_card","seconds":4,'
        '"headline":"Look up","subtitle":"end"}]';
    await _boot(tester, agent: _mockAgent(reply: planJson));

    await tester.enterText(
      find.byType(TextField).first,
      'a 30s explainer on black holes',
    );
    await tester.tap(find.text('Generate ad'));
    await tester.pumpAndSettle();

    // The studio is driven by the agent's generated scenes, not the sample.
    expect(find.text('Cosmic Hook'), findsWidgets);
    expect(find.text('Megacities'), findsNothing);
  });

  testWidgets('selecting a scene updates the inspector', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('stat_card'), findsWidgets);
    expect(find.text('bar_chart'), findsNothing);

    await tester.tap(find.text('Megacities'));
    await tester.pumpAndSettle();

    expect(find.text('bar_chart'), findsWidgets);
    expect(find.text('stat_card'), findsNothing);
  });

  testWidgets('agent chat shows the model and replies to a message', (
    tester,
  ) async {
    await _boot(tester, agent: _mockAgent(reply: 'Hook, body, payoff.'));
    await _enterStudio(tester);

    // The live status bar shows the connected local model.
    expect(find.text('qwen2.5:latest'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('agentComposer')),
      'Plan it',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Hook, body, payoff.'), findsOneWidget);
  });

  testWidgets('generate narration calls the TTS provider', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    await tester.tap(find.text('Generate narration'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Narration ready · Samantha'), findsOneWidget);
  });

  testWidgets('a chart scene renders its data in the preview', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    await tester.tap(find.text('Megacities'));
    await tester.pumpAndSettle();

    // The mini chart in the preview reflects the scene's real data.
    expect(find.text('Tokyo'), findsWidgets);
    expect(find.text('37'), findsWidgets);
  });

  testWidgets('adding and deleting scenes changes the plan length', (
    tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    // The sample opens with 5 scenes, selection on the 2nd.
    expect(find.text('SCENE 2 / 5'), findsOneWidget);

    // Add a scene after the selection -> 6 scenes, selection moves to it.
    await tester.tap(find.byTooltip('Add scene'));
    await tester.pumpAndSettle();
    expect(find.text('SCENE 3 / 6'), findsOneWidget);

    // Delete it -> back to 5.
    await tester.tap(find.byTooltip('Delete scene'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ 5'), findsOneWidget);
  });

  testWidgets('approving walks the pipeline forward to compose', (
    tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    // Opens on scene_plan: one approve button, and only the top-bar Render.
    expect(find.text('Approve & continue'), findsOneWidget);
    expect(find.text('Render'), findsOneWidget);

    // Approve scene_plan -> assets -> edit -> compose.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Approve & continue'));
      await tester.pumpAndSettle();
    }

    // At compose the inspector's action becomes Render (now two Render labels).
    expect(find.text('Approve & continue'), findsNothing);
    expect(find.text('Render'), findsNWidgets(2));
  });

  testWidgets('render button renders an MP4 via the provider', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    await tester.tap(find.text('Render'));
    await tester.pumpAndSettle();

    expect(find.text('Render complete'), findsOneWidget);
    expect(find.textContaining('render.mp4'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Render complete'), findsNothing);
  });

  testWidgets('editing the headline updates the preview and undo reverts it', (
    tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);
    // A taller window so the inspector's scroll list lays out the headline
    // field (the voice picker pushes it down in the default height).
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    await tester.pumpAndSettle();

    // The sample opens on the Population scene ("8.1B").
    expect(find.text('8.1B'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('inspectorHeadline')),
      'Twelve',
    );
    await tester.pumpAndSettle();
    expect(find.text('Twelve'), findsWidgets); // preview reflects the edit
    expect(find.text('8.1B'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('8.1B'), findsWidgets);
    expect(find.text('Twelve'), findsNothing);

    await tester.tap(find.text('Redo'));
    await tester.pumpAndSettle();
    expect(find.text('Twelve'), findsWidgets);
  });

  testWidgets('the preview play button toggles playback', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('revise asks the agent and updates the scene', (tester) async {
    await _boot(
      tester,
      agent: _mockAgent(reply: '{"headline":"Revised line","subtitle":"new"}'),
    );
    await _enterStudio(tester);

    await tester.tap(find.text('Revise with agent'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reviseInput')), 'punchier');
    await tester.tap(find.widgetWithText(FilledButton, 'Revise'));
    await tester.pumpAndSettle();

    expect(find.text('Revised line'), findsWidgets);
  });

  testWidgets('a completed render advances the pipeline to export', (
    tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    // Walk scene_plan -> assets -> edit -> compose.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Approve & continue'));
      await tester.pumpAndSettle();
    }
    // At compose the inspector action is Render (last of top-bar + inspector).
    await tester.tap(find.widgetWithText(FilledButton, 'Render').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // A successful render advances to the publish stage: action becomes Export.
    expect(find.text('Export video'), findsOneWidget);
  });

  testWidgets('settings opens the providers screen', (tester) async {
    await _boot(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsOneWidget);
    // The account card sits above the providers; scroll the Agent section in.
    await tester.scrollUntilVisible(
      find.text('Claude'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });

  testWidgets('unauthenticated enters as guest; sign-in is reachable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthClient(
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'tok',
              'user': {'id': 'u', 'email': 'x@y.com'},
            }),
            200,
          );
        }
        return http.Response('no', 404);
      }),
    );

    await tester.pumpWidget(
      OpenMontageStudioApp(
        authClient: auth,
        agentService: _mockAgent(),
        ttsClient: _mockTts(),
        renderClient: _mockRender(),
      ),
    );
    await tester.pumpAndSettle();

    // No session -> straight into the app as a guest (no wall).
    expect(find.text('What ad are we making today?'), findsOneWidget);
    // A guest can reach sign-in from the header.
    expect(find.widgetWithText(TextButton, 'Sign in'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();

    // The sign-in screen is presented on demand, with third-party options.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'x@y.com');
    await tester.enterText(find.byType(TextField).at(1), 'supersecret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Back to the home launcher, now signed in.
    expect(find.text('What ad are we making today?'), findsOneWidget);
  });

  testWidgets('register mode shows the marketing consent opt-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OpenMontageStudioApp(
        authClient: AuthClient(
          httpClient: MockClient((req) async => http.Response('{}', 404)),
        ),
        agentService: _mockAgent(),
        ttsClient: _mockTts(),
        renderClient: _mockRender(),
      ),
    );
    await tester.pumpAndSettle();

    // Guest -> open sign-in from the header, then switch to register.
    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    // The consent is opt-in (a checkbox the user must tick) and explained.
    expect(find.textContaining('Send me product updates'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
