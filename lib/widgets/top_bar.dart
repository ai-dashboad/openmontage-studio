import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region A — the unified toolbar: project identity, online/offline state, the
/// render action, and a live budget meter.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.isOnline,
    required this.onToggleOnline,
    this.onHome,
    this.onOpenSettings,
    this.onRender,
  });

  final bool isOnline;
  final VoidCallback onToggleOnline;
  final VoidCallback? onHome;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRender;

  @override
  Widget build(BuildContext context) {
    final spentFraction = (MockProject.spentUsd / MockProject.budgetUsd).clamp(
      0.0,
      1.0,
    );

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
          Flexible(child: _ProjectChip(name: MockProject.name)),
          const Spacer(),
          _OnlineToggle(isOnline: isOnline, onTap: onToggleOnline),
          const SizedBox(width: 16),
          _BudgetMeter(fraction: spentFraction),
          const SizedBox(width: 16),
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

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({required this.isOnline, required this.onTap});
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.accentCyan : AppColors.accentAmber;
    return Tooltip(
      message: isOnline
          ? 'Online — cloud providers available'
          : 'Offline — local providers only',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_outlined : Icons.computer,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetMeter extends StatelessWidget {
  const _BudgetMeter({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.textMuted,
          size: 15,
        ),
        const SizedBox(width: 6),
        Text(
          '\$${MockProject.spentUsd.toStringAsFixed(2)} / \$${MockProject.budgetUsd.toStringAsFixed(0)}',
          style: AppTheme.mono.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction == 0 ? 0.02 : fraction,
              minHeight: 4,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen),
            ),
          ),
        ),
      ],
    );
  }
}
