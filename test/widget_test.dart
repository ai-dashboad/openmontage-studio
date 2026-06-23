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
import 'package:openmontage_studio/services/ollama_client.dart';
import 'package:openmontage_studio/services/render_client.dart';
import 'package:openmontage_studio/services/tts_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// A mock TTS provider that reports a synthesized clip without touching disk.
TtsClient _mockTts() {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/health')) {
      return http.Response(jsonEncode({'ok': true}), 200);
    }
    if (request.url.path.endsWith('/tts/play')) {
      return http.Response(jsonEncode({'ok': true}), 200);
    }
    if (request.url.path.endsWith('/tts')) {
      return http.Response(
        jsonEncode({
          'path': '/tmp/narration_1.aiff',
          'voice': 'Samantha',
          'bytes': 104142,
          'seconds': 2.3,
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
  return TtsClient(httpClient: client);
}

/// A mock render provider that reports a finished MP4 without touching ffmpeg.
RenderClient _mockRender() {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/render')) {
      return http.Response(
        jsonEncode({
          'path': '/tmp/openmontage-tts/render/render.mp4',
          'scenes': 5,
          'seconds': 23.0,
          'bytes': 73853,
        }),
        200,
      );
    }
    if (request.url.path.endsWith('/open')) {
      return http.Response(jsonEncode({'ok': true}), 200);
    }
    return http.Response('not found', 404);
  });
  return RenderClient(httpClient: client);
}

/// Boots the app at desktop size with mock-backed local providers.
Future<void> _boot(
  WidgetTester tester, {
  AgentService? agent,
  TtsClient? tts,
  RenderClient? render,
}) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OpenMontageStudioApp(
      agentService: agent ?? _mockAgent(),
      ttsClient: tts ?? _mockTts(),
      renderClient: render ?? _mockRender(),
      initialAccount: _testAccount, // bypass the auth gate
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterStudio(WidgetTester tester) async {
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to the home launcher with capabilities', (tester) async {
    await _boot(tester);

    expect(find.text('OpenMontage Studio'), findsOneWidget);
    expect(find.text('Start a new video'), findsOneWidget);
    expect(find.text('Composition'), findsOneWidget);
  });

  testWidgets('home opens the studio and shows the pipeline', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('scene_plan'), findsWidgets);
    expect(find.textContaining('Composition 3/3'), findsOneWidget);
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
    await tester.tap(find.text('Create'));
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

    await tester.enterText(find.byType(TextField).last, 'Plan it');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Hook, body, payoff.'), findsOneWidget);
  });

  testWidgets('generate narration calls the TTS provider', (tester) async {
    await _boot(tester);
    await _enterStudio(tester);

    await tester.tap(find.text('Generate narration'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Narration ready'), findsOneWidget);
    expect(find.textContaining('Samantha'), findsOneWidget);
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

  testWidgets('unauthenticated shows sign-in; login enters the app', (
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

    // No session -> the sign-in screen, not the app.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Start a new video'), findsNothing);
    // Third-party sign-in options are offered.
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'x@y.com');
    await tester.enterText(find.byType(TextField).at(1), 'supersecret1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Authenticated -> the home launcher.
    expect(find.text('Start a new video'), findsOneWidget);
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

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    // The consent is opt-in (a checkbox the user must tick) and explained.
    expect(find.textContaining('Send me product updates'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
