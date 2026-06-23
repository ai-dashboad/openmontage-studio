import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region C — the preview stage. In the real app this hosts the Remotion player;
/// here it renders a faithful placeholder of the selected scene so the
/// timeline/inspector wiring is visible end to end.
class PreviewStage extends StatelessWidget {
  const PreviewStage({
    super.key,
    required this.scene,
    required this.playheadSeconds,
    required this.totalSeconds,
    required this.onScrub,
  });

  final Scene scene;
  final double playheadSeconds;
  final double totalSeconds;
  final ValueChanged<double> onScrub;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _ScenePreview(scene: scene),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Transport(
            playheadSeconds: playheadSeconds,
            totalSeconds: totalSeconds,
            onScrub: onScrub,
          ),
        ],
      ),
    );
  }
}

class _ScenePreview extends StatelessWidget {
  const _ScenePreview({required this.scene});
  final Scene scene;

  double _headlineSize() {
    if (scene.type == 'stat_card') return 64;
    if (scene.headline.length > 26) return 30;
    if (scene.headline.length > 16) return 40;
    return 48;
  }

  @override
  Widget build(BuildContext context) {
    final isStat = scene.type == 'stat_card';
    final headlineColor = isStat ? scene.accent : AppColors.textPrimary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [scene.accent.withValues(alpha: 0.14), AppColors.surface],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 14,
            child: _TypeTag(type: scene.type, accent: scene.accent),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kicker — the scene title, mirroring the rendered output.
                  if (scene.title.isNotEmpty)
                    Text(
                      scene.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTheme.mono.copyWith(
                        color: scene.accent,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Accent bar, like the rendered headline rule.
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      color: scene.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (scene.headline.isNotEmpty)
                    Text(
                      scene.headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: _headlineSize(),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  if (scene.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      scene.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 14,
            child: Text(
              '1920 × 1080 · live preview',
              style: AppTheme.mono.copyWith(
                color: AppColors.textFaint,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, required this.accent});
  final String type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: AppTheme.mono.copyWith(color: accent, fontSize: 11),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playheadSeconds,
    required this.totalSeconds,
    required this.onScrub,
  });
  final double playheadSeconds;
  final double totalSeconds;
  final ValueChanged<double> onScrub;

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(1, '0');
    final sec = (s % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.play_circle_fill,
          color: AppColors.accentCyan,
          size: 28,
        ),
        const SizedBox(width: 12),
        Text(
          _fmt(playheadSeconds),
          style: AppTheme.mono.copyWith(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.accentCyan,
              inactiveTrackColor: AppColors.surfaceHigh,
              thumbColor: AppColors.accentCyan,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: playheadSeconds.clamp(0, totalSeconds),
              max: totalSeconds,
              onChanged: onScrub,
            ),
          ),
        ),
        Text(
          _fmt(totalSeconds),
          style: AppTheme.mono.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        const Icon(
          Icons.volume_up_outlined,
          color: AppColors.textMuted,
          size: 18,
        ),
      ],
    );
  }
}
