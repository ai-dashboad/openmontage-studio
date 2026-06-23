// Widget tests covering navigation (home -> studio -> settings), the render
// dialog, the studio wiring, and the live agent chat (backed by a mock Ollama).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:openmontage_studio/main.dart';
import 'package:openmontage_studio/services/agent_service.dart';
import 'package:openmontage_studio/services/ollama_client.dart';
import 'package:openmontage_studio/services/tts_client.dart';

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

/// Boots the app at desktop size with mock-backed local providers.
Future<void> _boot(
  WidgetTester tester, {
  AgentService? agent,
  TtsClient? tts,
}) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OpenMontageStudioApp(
      agentService: agent ?? _mockAgent(),
      ttsClient: tts ?? _mockTts(),
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

  testWidgets('render button opens the progress dialog and completes', (
    tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    await tester.tap(find.text('Render'));
    await tester.pump();
    expect(find.text('Rendering'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Render complete'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Render complete'), findsNothing);
  });

  testWidgets('settings opens the providers screen', (tester) async {
    await _boot(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });
}
