import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmontage_studio/models/studio_models.dart';
import 'package:openmontage_studio/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  StudioProject sample(String id, {String name = 'Demo'}) => StudioProject(
    id: id,
    name: name,
    scenes: const [
      Scene(
        id: 's1',
        type: 'hero_title',
        title: 'Hook',
        startSeconds: 0,
        endSeconds: 4,
        accent: Color(0xFF22D3EE),
        headline: 'Hello',
        subtitle: 'world',
      ),
    ],
    stageIndex: 3,
    updatedAtIso: '2026-06-23T10:00:00.000Z',
  );

  test('saves and reloads a project, preserving scenes and stage', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore(prefs: await SharedPreferences.getInstance());

    await store.save(sample('p1'));
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.first.name, 'Demo');
    expect(loaded.first.stageIndex, 3);
    expect(loaded.first.scenes.single.headline, 'Hello');
    expect(loaded.first.scenes.single.accent, const Color(0xFF22D3EE));
  });

  test('chart data survives a save/reload roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore(prefs: await SharedPreferences.getInstance());

    await store.save(
      StudioProject(
        id: 'chart',
        name: 'Charted',
        scenes: const [
          Scene(
            id: 'c',
            type: 'bar_chart',
            title: 'Cities',
            startSeconds: 0,
            endSeconds: 4,
            accent: Color(0xFFA78BFA),
            headline: 'Megacities',
            subtitle: 'millions',
            chartData: [
              ChartDatum(label: 'Tokyo', value: 37),
              ChartDatum(label: 'Delhi', value: 32),
            ],
          ),
        ],
        stageIndex: 2,
        updatedAtIso: '2026-06-24T00:00:00.000Z',
      ),
    );
    final scene = (await store.load()).single.scenes.single;
    expect(scene.isChart, isTrue);
    expect(scene.chartData.map((d) => d.label), ['Tokyo', 'Delhi']);
    expect(scene.chartData.first.value, 37);
  });

  test('save by id updates in place rather than duplicating', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore(prefs: await SharedPreferences.getInstance());

    await store.save(sample('p1', name: 'First'));
    await store.save(sample('p1', name: 'Renamed'));
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.first.name, 'Renamed');
  });

  test('load returns newest-updated first', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore(prefs: await SharedPreferences.getInstance());

    await store.save(
      StudioProject(
        id: 'old',
        name: 'Old',
        scenes: const [],
        stageIndex: 2,
        updatedAtIso: '2026-06-01T00:00:00.000Z',
      ),
    );
    await store.save(
      StudioProject(
        id: 'new',
        name: 'New',
        scenes: const [],
        stageIndex: 2,
        updatedAtIso: '2026-06-23T00:00:00.000Z',
      ),
    );
    final loaded = await store.load();

    expect(loaded.map((p) => p.name), ['New', 'Old']);
  });
}
