import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared chrome for the Open Montage Flow screens (Pricing, Invite, …): the
/// eyebrow pill, gradient headings, the back header, and the gradient CTA.

/// The rounded eyebrow pill: a glowing cyan dot + a mono label.
class EyebrowPill extends StatelessWidget {
  const EyebrowPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.accentSky,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.accentSky, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTheme.mono.copyWith(
              color: AppColors.accent2,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A gradient-shimmer heading (Space Grotesk), centered.
class GradientHeading extends StatelessWidget {
  const GradientHeading(this.text, {super.key, this.fontSize = 44});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Color(0xFFF4F4F8),
          Color(0xFF8B8DF3),
          Color(0xFFA855F7),
          Color(0xFF38BDF8),
          Color(0xFFF4F4F8),
        ],
      ).createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.heading.copyWith(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.04,
          letterSpacing: -1.0,
        ),
      ),
    );
  }
}

/// The Flow logo lockup — gradient play tile + "Open Montage".
class FlowLogo extends StatelessWidget {
  const FlowLogo({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                colors: [AppColors.accent2, AppColors.accentViolet],
              ),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            'Open Montage',
            style: AppTheme.heading.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// A Flow screen's header bar: logo + a "Back to studio" button.
class FlowHeader extends StatelessWidget {
  const FlowHeader({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 14, 30, 8),
      child: Row(
        children: [
          FlowLogo(onTap: onBack),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Back to studio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.borderStrong),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's primary gradient CTA (indigo → violet).
class FlowGradientButton extends StatelessWidget {
  const FlowGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          colors: [AppColors.accent2, AppColors.accent, AppColors.accentViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
