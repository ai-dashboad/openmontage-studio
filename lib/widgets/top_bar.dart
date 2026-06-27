import 'package:flutter/material.dart';
import '../services/provider_manager.dart';
import '../theme/app_theme.dart';

/// Region A — the unified toolbar: project identity, live service status, the
/// render action, and an honest "runs locally, free" indicator.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.projectName = 'Untitled video',
    this.provider,
    this.onRetryServices,
    this.creditsLabel,
    this.focusMode = false,
    this.onToggleFocus,
    this.imagesEnabled = false,
    this.fetchingImages = false,
    this.onFetchImages,
    this.onHome,
    this.onOpenSettings,
    this.onRender,
  });

  final String projectName;
  final ProviderManager? provider;
  final VoidCallback? onRetryServices;

  /// Optional credit/plan chip (e.g. "5 free renders left" or "Pro").
  final String? creditsLabel;

  /// The Studio/Focus layout toggle (from the Open Montage editor design).
  final bool focusMode;
  final VoidCallback? onToggleFocus;
  final bool imagesEnabled;
  final bool fetchingImages;
  final VoidCallback? onFetchImages;
  final VoidCallback? onHome;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRender;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onHome,
            icon: const Icon(
              Icons.blur_circular,
              color: AppColors.accentCyan,
              size: 20,
            ),
            tooltip: 'Home',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          const Text(
            'OpenMontage',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 20),
          Flexible(child: _ProjectChip(name: projectName)),
          if (onToggleFocus != null) ...[
            const SizedBox(width: 14),
            _LayoutToggle(focus: focusMode, onToggle: onToggleFocus!),
          ],
          const Spacer(),
          if (provider != null) ...[
            _ServiceStatus(
              provider: provider!,
              onRetry: onRetryServices,
            ),
            const SizedBox(width: 16),
          ],
          const _LocalChip(),
          if (creditsLabel != null) ...[
            const SizedBox(width: 12),
            _CreditsChip(label: creditsLabel!),
          ],
          const SizedBox(width: 16),
          if (imagesEnabled) ...[
            OutlinedButton.icon(
              onPressed: fetchingImages ? null : onFetchImages,
              icon: fetchingImages
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPurple,
                      ),
                    )
                  : const Icon(Icons.image_outlined, size: 16),
              label: Text(fetchingImages ? 'Fetching…' : 'Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPurple,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: onRender,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Render'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            tooltip: 'Settings & providers',
          ),
        ],
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, color: AppColors.textMuted, size: 16),
        ],
      ),
    );
  }
}

/// Live status lights for the local services: the agent (Ollama) and the media
/// provider (ffmpeg + voice). Tapping retries — and starts the media provider
/// if it is down — so the user fixes "service offline" without a terminal.
class _ServiceStatus extends StatelessWidget {
  const _ServiceStatus({required this.provider, this.onRetry});
  final ProviderManager provider;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final starting = provider.mediaPhase == MediaPhase.starting;
        return Tooltip(
          message: starting
              ? 'Starting the media provider…'
              : 'Agent: ${provider.agentUp ? "online" : "offline"} · '
                    'Media: ${provider.mediaUp ? "online" : "offline"}'
                    '${provider.mediaUp ? "" : " — click to start"}',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot('agent', provider.agentUp),
                  const SizedBox(width: 12),
                  if (starting)
                    const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppColors.accentAmber,
                      ),
                    )
                  else
                    _dot('media', provider.mediaUp),
                  const SizedBox(width: 4),
                  const Text(
                    'media',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dot(String label, bool up) {
    final color = up ? AppColors.accentGreen : AppColors.accentAmber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

/// The Studio / Focus layout toggle from the Open Montage editor design.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.focus, required this.onToggle});
  final bool focus;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('Studio', Icons.view_sidebar_outlined, !focus,
              focus ? onToggle : null),
          _seg('Focus', Icons.crop_landscape_outlined, focus,
              focus ? null : onToggle),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool active, VoidCallback? onTap) {
    final color = active ? AppColors.textPrimary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.panel3 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Shows the user's remaining free renders, or "Pro". Amber when running low so
/// the paywall doesn't feel like an ambush.
class _CreditsChip extends StatelessWidget {
  const _CreditsChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isPro = label == 'Pro';
    final low = !isPro && label.startsWith('0');
    final color = isPro
        ? AppColors.accentCyan
        : low
        ? AppColors.accentAmber
        : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPro ? Icons.workspace_premium : Icons.bolt, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// An honest indicator: all generation runs on-device, at no cost.
class _LocalChip extends StatelessWidget {
  const _LocalChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Everything runs on your Mac — no cloud, no API keys, no cost',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.computer, color: AppColors.accentGreen, size: 14),
            SizedBox(width: 6),
            Text(
              'Local · free',
              style: TextStyle(color: AppColors.accentGreen, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
