// Widget tests covering navigation (home -> studio -> settings), the render
// dialog, and the studio's see -> tweak -> approve wiring.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openmontage_studio/main.dart';

// The shell targets a minimum desktop window of 1100x720.
const _desktop = Size(1280, 832);

/// Boots the app at desktop size and returns once the first frame settles.
Future<void> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const OpenMontageStudioApp());
  await tester.pumpAndSettle();
}

/// Navigates from the home launcher into the studio editor.
Future<void> _enterStudio(WidgetTester tester) async {
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to the home launcher with capabilities', (
    WidgetTester tester,
  ) async {
    await _boot(tester);

    expect(find.text('OpenMontage Studio'), findsOneWidget);
    expect(find.text('Start a new video'), findsOneWidget);
    expect(find.text('Composition'), findsOneWidget);
  });

  testWidgets('home opens the studio and shows the pipeline', (
    WidgetTester tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('scene_plan'), findsWidgets);
    expect(find.textContaining('Composition 3/3'), findsOneWidget);
  });

  testWidgets('selecting a scene updates the inspector', (
    WidgetTester tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('stat_card'), findsWidgets);
    expect(find.text('bar_chart'), findsNothing);

    await tester.tap(find.text('Megacities'));
    await tester.pumpAndSettle();

    expect(find.text('bar_chart'), findsWidgets);
    expect(find.text('stat_card'), findsNothing);
  });

  testWidgets('side panel shows agent chat and switches to asset gallery', (
    WidgetTester tester,
  ) async {
    await _boot(tester);
    await _enterStudio(tester);

    expect(find.text('Message the agent…'), findsOneWidget);
    expect(find.text('scene_plan · 5 scenes · 23s'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Megacity skyline'), findsOneWidget);
  });

  testWidgets('render button opens the progress dialog and completes', (
    WidgetTester tester,
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

  testWidgets('settings opens the providers screen', (
    WidgetTester tester,
  ) async {
    await _boot(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });
}
