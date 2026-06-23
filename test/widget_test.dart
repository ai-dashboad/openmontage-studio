// Smoke tests for the studio-first shell: the app boots and the timeline drives
// the inspector, demonstrating the see -> tweak -> approve loop is wired.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelforge/main.dart';

// The studio shell targets a minimum desktop window of 1100x720, so tests
// render at a realistic desktop surface size.
const _desktop = Size(1280, 832);

void main() {
  testWidgets('app boots and shows the pipeline and capability menu',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReelforgeApp());

    // Brand and the awaiting stage are present.
    expect(find.text('Reelforge'), findsOneWidget);
    expect(find.text('scene_plan'), findsWidgets);

    // The capability rollup renders the configured composition family.
    expect(find.textContaining('Composition 3/3'), findsOneWidget);
  });

  testWidgets('selecting a scene updates the inspector',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReelforgeApp());

    // The default selection is the stat_card scene ("Population"); its type
    // shows in both the preview tag and the inspector field.
    expect(find.text('stat_card'), findsWidgets);
    expect(find.text('bar_chart'), findsNothing);

    // Tapping the "Megacities" scene block switches preview + inspector to
    // the bar_chart scene.
    await tester.tap(find.text('Megacities'));
    await tester.pumpAndSettle();

    expect(find.text('bar_chart'), findsWidgets);
    expect(find.text('stat_card'), findsNothing);
  });

  testWidgets('side panel shows agent chat and switches to asset gallery',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReelforgeApp());

    // The panel opens on the agent chat with the scene_plan artifact card.
    expect(find.text('Message the agent…'), findsOneWidget);
    expect(find.text('scene_plan · 5 scenes · 23s'), findsOneWidget);

    // Switching the rail to Images shows the asset gallery.
    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Megacity skyline'), findsOneWidget);
  });
}
