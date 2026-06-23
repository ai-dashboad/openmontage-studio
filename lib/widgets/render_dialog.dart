import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Shows the render progress dialog. The progress is simulated locally; in the
/// real app it is driven by the compose stage emitting frame/encode updates.
Future<void> showRenderDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _RenderDialog(),
  );
}

class _RenderDialog extends StatelessWidget {
  const _RenderDialog();

  static const int totalFrames = 690;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 2600),
          curve: Curves.easeInOut,
          builder: (context, t, _) {
            final done = t >= 1.0;
            final frame = (t * totalFrames).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.movie_creation_outlined,
                      color: done
                          ? AppColors.accentGreen
                          : AppColors.accentCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        done ? 'Render complete' : 'Rendering',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remotion · 1080p',
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono.copyWith(
                        color: AppColors.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: t,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(
                      done ? AppColors.accentGreen : AppColors.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  done
                      ? 'Encoded $totalFrames / $totalFrames frames'
                      : 'Rendered $frame / $totalFrames frames',
                  style: AppTheme.mono.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (done) ...[const SizedBox(height: 16), _OutputRow()],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: done
                      ? FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: AppColors.background,
                          ),
                          child: const Text('Done'),
                        )
                      : TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.movie_outlined,
            size: 16,
            color: AppColors.accentGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'renders/${MockProject.name.toLowerCase().replaceAll(' ', '-')}.mp4',
              style: AppTheme.mono.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${MockProject.totalSeconds.toStringAsFixed(0)}s · 4.1 MB',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
