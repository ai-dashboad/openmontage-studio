import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Where a provider runs.
enum ProviderKind { cloud, local }

/// Configuration state of a provider on this machine.
enum ProviderStatus {
  configured, // cloud key present, ready
  available, // local engine installed/reachable
  unavailable; // needs a key or an install

  Color get color => switch (this) {
    ProviderStatus.configured => AppColors.accentGreen,
    ProviderStatus.available => AppColors.accentCyan,
    ProviderStatus.unavailable => AppColors.textFaint,
  };

  String get label => switch (this) {
    ProviderStatus.configured => 'Configured',
    ProviderStatus.available => 'Available',
    ProviderStatus.unavailable => 'Not set up',
  };
}

/// One concrete provider behind a capability (cloud API or local engine).
class ProviderEntry {
  const ProviderEntry({
    required this.name,
    required this.capability,
    required this.kind,
    required this.status,
    required this.hint,
  });

  final String name;
  final String capability;
  final ProviderKind kind;
  final ProviderStatus status;

  /// Setup hint — an env var for cloud, an engine/runtime for local.
  final String hint;
}

/// A recently opened production, shown on the home launcher.
class RecentProject {
  const RecentProject({
    required this.name,
    required this.accent,
    required this.stagesDone,
    required this.updated,
  });

  final String name;
  final Color accent;
  final int stagesDone; // out of 7 pipeline stages
  final String updated;
}

/// Static catalog backing the home and settings screens.
class Catalog {
  static const int pipelineStages = 7;

  static const List<RecentProject> recents = [
    RecentProject(
      name: 'The World in Numbers',
      accent: AppColors.accentCyan,
      stagesDone: 2,
      updated: '2 minutes ago',
    ),
    RecentProject(
      name: 'How Music Rewires the Brain',
      accent: AppColors.accentPurple,
      stagesDone: 6,
      updated: 'yesterday',
    ),
    RecentProject(
      name: 'Launch Reel — Q3',
      accent: AppColors.accentAmber,
      stagesDone: 7,
      updated: 'last week',
    ),
  ];

  static const List<ProviderEntry> providers = [
    // Composition (always local).
    ProviderEntry(
      name: 'Remotion',
      capability: 'Composition',
      kind: ProviderKind.local,
      status: ProviderStatus.available,
      hint: 'Node runtime',
    ),
    ProviderEntry(
      name: 'FFmpeg',
      capability: 'Composition',
      kind: ProviderKind.local,
      status: ProviderStatus.available,
      hint: 'system binary',
    ),
    // Voiceover.
    ProviderEntry(
      name: 'System Voice',
      capability: 'Voiceover',
      kind: ProviderKind.local,
      status: ProviderStatus.available,
      hint: 'macOS say · :8765',
    ),
    ProviderEntry(
      name: 'Piper',
      capability: 'Voiceover',
      kind: ProviderKind.local,
      status: ProviderStatus.available,
      hint: 'offline TTS',
    ),
    ProviderEntry(
      name: 'ElevenLabs',
      capability: 'Voiceover',
      kind: ProviderKind.cloud,
      status: ProviderStatus.unavailable,
      hint: 'ELEVENLABS_API_KEY',
    ),
    // Image.
    ProviderEntry(
      name: 'FLUX',
      capability: 'Image',
      kind: ProviderKind.cloud,
      status: ProviderStatus.unavailable,
      hint: 'FAL_KEY',
    ),
    ProviderEntry(
      name: 'Local Diffusion',
      capability: 'Image',
      kind: ProviderKind.local,
      status: ProviderStatus.unavailable,
      hint: 'MLX / Metal',
    ),
    // Video.
    ProviderEntry(
      name: 'Seedance',
      capability: 'Video',
      kind: ProviderKind.cloud,
      status: ProviderStatus.unavailable,
      hint: 'FAL_KEY',
    ),
    // Agent brain.
    ProviderEntry(
      name: 'Claude',
      capability: 'Agent',
      kind: ProviderKind.cloud,
      status: ProviderStatus.unavailable,
      hint: 'ANTHROPIC_API_KEY',
    ),
    ProviderEntry(
      name: 'Ollama',
      capability: 'Agent',
      kind: ProviderKind.local,
      status: ProviderStatus.unavailable,
      hint: 'local LLM',
    ),
  ];
}
