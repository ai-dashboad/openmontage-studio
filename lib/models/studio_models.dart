import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Status of a pipeline stage or an individual scene, mapped to a status color.
enum WorkStatus {
  done,
  awaiting,
  pending;

  Color get color => switch (this) {
    WorkStatus.done => AppColors.statusDone,
    WorkStatus.awaiting => AppColors.statusAwaiting,
    WorkStatus.pending => AppColors.statusPending,
  };

  IconData get glyph => switch (this) {
    WorkStatus.done => Icons.check_circle,
    WorkStatus.awaiting => Icons.radio_button_checked,
    WorkStatus.pending => Icons.radio_button_unchecked,
  };
}

/// One stage of the OpenMontage Studio production pipeline.
class PipelineStage {
  const PipelineStage(this.name, this.status);
  final String name;
  final WorkStatus status;
}

/// One labelled value in a chart scene (bar/pie). Real, editable data — not
/// values synthesized from the subtitle.
class ChartDatum {
  const ChartDatum({required this.label, required this.value});
  final String label;
  final double value;

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  static ChartDatum fromJson(Map<String, dynamic> j) => ChartDatum(
    label: j['label'] as String? ?? '',
    value: (j['value'] as num?)?.toDouble() ?? 0,
  );

  ChartDatum copyWith({String? label, double? value}) =>
      ChartDatum(label: label ?? this.label, value: value ?? this.value);
}

/// A single scene inside the current stage's plan, carrying just enough of the
/// `scene_plan` artifact to drive the preview and inspector.
class Scene {
  const Scene({
    required this.id,
    required this.type,
    required this.title,
    required this.startSeconds,
    required this.endSeconds,
    required this.accent,
    this.headline = '',
    this.subtitle = '',
    this.chartData = const [],
  });

  final String id;
  final String type;
  final String title;
  final double startSeconds;
  final double endSeconds;
  final Color accent;
  final String headline;
  final String subtitle;

  /// Data points for chart scenes (`bar_chart` / `pie_chart`). Empty otherwise.
  final List<ChartDatum> chartData;

  double get durationSeconds => endSeconds - startSeconds;

  bool get isChart => type == 'bar_chart' || type == 'pie_chart';

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'start': startSeconds,
    'end': endSeconds,
    'accent': accent.toARGB32(),
    'headline': headline,
    'subtitle': subtitle,
    if (chartData.isNotEmpty)
      'chartData': [for (final d in chartData) d.toJson()],
  };

  static Scene fromJson(Map<String, dynamic> j) => Scene(
    id: j['id'] as String? ?? 'scene',
    type: j['type'] as String? ?? 'text_card',
    title: j['title'] as String? ?? 'Scene',
    startSeconds: (j['start'] as num?)?.toDouble() ?? 0,
    endSeconds: (j['end'] as num?)?.toDouble() ?? 4,
    accent: Color((j['accent'] as num?)?.toInt() ?? 0xFF22D3EE),
    headline: j['headline'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    chartData: ((j['chartData'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChartDatum.fromJson)
        .toList(),
  );

  /// Returns a copy with the given fields replaced. Editing the inspector flows
  /// through this so the preview and timeline update from the same scene value.
  Scene copyWith({
    String? type,
    String? title,
    double? startSeconds,
    double? endSeconds,
    Color? accent,
    String? headline,
    String? subtitle,
    List<ChartDatum>? chartData,
  }) {
    return Scene(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      accent: accent ?? this.accent,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      chartData: chartData ?? this.chartData,
    );
  }
}

/// One capability family in the provider menu (the "X of Y configured" rollup).
class Capability {
  const Capability({
    required this.label,
    required this.configured,
    required this.total,
    required this.detail,
    required this.isLocalReady,
  });

  final String label;
  final int configured;
  final int total;

  /// Short note, e.g. "Piper (offline ready)" or "unlock biggest upgrade".
  final String detail;

  /// Whether at least one provider works fully offline on this machine.
  final bool isLocalReady;

  bool get isConfigured => configured > 0;
}

/// Static fixture data modelling a sample data-explainer project so the shell
/// shows a realistic production mid-flight without any backend.
class MockProject {
  static const String name = 'The World in Numbers';

  static const String renderRuntime = 'remotion';

  static const double totalSeconds = 23.0;

  static const double spentUsd = 0.0;
  static const double budgetUsd = 5.0;

  static const List<PipelineStage> stages = [
    PipelineStage('idea', WorkStatus.done),
    PipelineStage('script', WorkStatus.done),
    PipelineStage('scene_plan', WorkStatus.awaiting),
    PipelineStage('assets', WorkStatus.pending),
    PipelineStage('edit', WorkStatus.pending),
    PipelineStage('compose', WorkStatus.pending),
    PipelineStage('publish', WorkStatus.pending),
  ];

  static const List<Scene> scenes = [
    Scene(
      id: 'world-hook',
      type: 'hero_title',
      title: 'Hook',
      startSeconds: 0,
      endSeconds: 3.5,
      accent: AppColors.accentCyan,
      headline: 'The World in Numbers',
      subtitle: 'A zero-key showcase built from Remotion components only',
    ),
    Scene(
      id: 'world-population',
      type: 'stat_card',
      title: 'Population',
      startSeconds: 3.5,
      endSeconds: 7.5,
      accent: AppColors.accentCyan,
      headline: '8.1B',
      subtitle: 'People sharing one connected planet',
    ),
    Scene(
      id: 'world-cities',
      type: 'bar_chart',
      title: 'Megacities',
      startSeconds: 7.5,
      endSeconds: 13,
      accent: AppColors.accentPurple,
      headline: 'Largest megacities',
      subtitle: 'Population, millions',
      chartData: [
        ChartDatum(label: 'Tokyo', value: 37),
        ChartDatum(label: 'Delhi', value: 32),
        ChartDatum(label: 'Shanghai', value: 29),
        ChartDatum(label: 'Sao Paulo', value: 22),
      ],
    ),
    Scene(
      id: 'world-energy',
      type: 'pie_chart',
      title: 'Energy mix',
      startSeconds: 13,
      endSeconds: 18,
      accent: AppColors.accentAmber,
      headline: 'Global energy mix',
      subtitle: 'Share by source',
      chartData: [
        ChartDatum(label: 'Renewables', value: 30),
        ChartDatum(label: 'Gas', value: 28),
        ChartDatum(label: 'Coal', value: 25),
        ChartDatum(label: 'Nuclear', value: 17),
      ],
    ),
    Scene(
      id: 'world-close',
      type: 'text_card',
      title: 'Close',
      startSeconds: 18,
      endSeconds: 23,
      accent: AppColors.accentGreen,
      headline: 'Told entirely in data',
      subtitle: 'The story of our world',
    ),
  ];

  static const List<Capability> capabilities = [
    Capability(
      label: 'Composition',
      configured: 1,
      total: 1,
      detail: 'ffmpeg · on-device',
      isLocalReady: true,
    ),
    Capability(
      label: 'Voiceover',
      configured: 1,
      total: 1,
      detail: 'macOS say · on-device',
      isLocalReady: true,
    ),
    Capability(
      label: 'Image',
      configured: 0,
      total: 0,
      detail: 'roadmap',
      isLocalReady: false,
    ),
    Capability(
      label: 'Video',
      configured: 0,
      total: 0,
      detail: 'roadmap',
      isLocalReady: false,
    ),
    Capability(
      label: 'Music',
      configured: 0,
      total: 0,
      detail: 'roadmap',
      isLocalReady: false,
    ),
  ];

  static const List<ChatMessage> conversation = [
    ChatMessage(
      role: ChatRole.user,
      text: 'Make a short, punchy explainer about the world in numbers.',
    ),
    ChatMessage(
      role: ChatRole.agent,
      text:
          'Locked the brief: 23s, social pacing, data-forward. I split it into '
          'five beats — hook, population, megacities, energy mix, and a close. '
          'Runtime is Remotion so the stat and chart cards animate.',
    ),
    ChatMessage(
      role: ChatRole.agent,
      text: 'Here is the scene plan for your review.',
      artifact: 'scene_plan · 5 scenes · 23s',
    ),
  ];

  /// Mock candidate assets for the image family, with provenance.
  static const List<AssetItem> imageAssets = [
    AssetItem(
      label: 'Megacity skyline',
      provider: 'FLUX',
      seed: 4471,
      costUsd: 0.03,
      accent: AppColors.accentCyan,
    ),
    AssetItem(
      label: 'Energy grid',
      provider: 'FLUX',
      seed: 9120,
      costUsd: 0.03,
      accent: AppColors.accentAmber,
    ),
    AssetItem(
      label: 'Connected planet',
      provider: 'Imagen',
      seed: 2025,
      costUsd: 0.04,
      accent: AppColors.accentPurple,
    ),
  ];
}

enum ChatRole { user, agent }

/// One turn in the agent conversation. [artifact] optionally tags the message
/// as carrying a pipeline artifact the user can open in the inspector.
class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.artifact});
  final ChatRole role;
  final String text;
  final String? artifact;
}

/// A generated candidate asset shown in an asset-family gallery.
class AssetItem {
  const AssetItem({
    required this.label,
    required this.provider,
    required this.seed,
    required this.costUsd,
    required this.accent,
  });
  final String label;
  final String provider;
  final int seed;
  final double costUsd;
  final Color accent;
}
