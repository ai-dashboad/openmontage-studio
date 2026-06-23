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
  });

  final String id;
  final String type;
  final String title;
  final double startSeconds;
  final double endSeconds;
  final Color accent;
  final String headline;
  final String subtitle;

  double get durationSeconds => endSeconds - startSeconds;
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
      headline: 'Illustrative megacity population',
      subtitle: 'Tokyo · Delhi · Shanghai · Sao Paulo',
    ),
    Scene(
      id: 'world-energy',
      type: 'pie_chart',
      title: 'Energy mix',
      startSeconds: 13,
      endSeconds: 18,
      accent: AppColors.accentAmber,
      headline: 'Illustrative energy mix',
      subtitle: 'Renewables claiming a bigger share each year',
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
      configured: 3,
      total: 3,
      detail: 'Remotion · HyperFrames · FFmpeg',
      isLocalReady: true,
    ),
    Capability(
      label: 'Voiceover',
      configured: 1,
      total: 3,
      detail: 'Piper (offline ready)',
      isLocalReady: true,
    ),
    Capability(
      label: 'Image',
      configured: 0,
      total: 9,
      detail: 'Set FAL_KEY to unlock',
      isLocalReady: false,
    ),
    Capability(
      label: 'Video',
      configured: 0,
      total: 13,
      detail: 'Unlock the biggest upgrade',
      isLocalReady: false,
    ),
    Capability(
      label: 'Music',
      configured: 0,
      total: 2,
      detail: 'ElevenLabs · Suno',
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
