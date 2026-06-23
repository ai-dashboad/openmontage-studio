import 'package:flutter/material.dart';
import '../models/catalog.dart';
import '../theme/app_theme.dart';

/// Providers settings: cloud APIs and local engines, grouped by capability. The
/// cloud/local split is what makes online vs offline "just which endpoint."
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Preserve catalog order while grouping by capability.
    final byCapability = <String, List<ProviderEntry>>{};
    for (final p in Catalog.providers) {
      byCapability.putIfAbsent(p.capability, () => []).add(p);
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            children: [
              _Header(onBack: onBack),
              const SizedBox(height: 24),
              for (final entry in byCapability.entries) ...[
                _CapabilitySection(
                  capability: entry.key,
                  providers: entry.value,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          tooltip: 'Back',
        ),
        const SizedBox(width: 4),
        const Text(
          'Providers',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const _LegendDot(color: AppColors.accentGreen, label: 'Configured'),
        const SizedBox(width: 12),
        const _LegendDot(color: AppColors.accentCyan, label: 'Local'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
        ),
      ],
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection({required this.capability, required this.providers});
  final String capability;
  final List<ProviderEntry> providers;

  @override
  Widget build(BuildContext context) {
    final configured = providers
        .where((p) => p.status != ProviderStatus.unavailable)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  capability,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$configured/${providers.length} ready',
                  style: AppTheme.mono.copyWith(
                    color: configured > 0
                        ? AppColors.accentGreen
                        : AppColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < providers.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _ProviderRow(provider: providers[i]),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});
  final ProviderEntry provider;

  @override
  Widget build(BuildContext context) {
    final isCloud = provider.kind == ProviderKind.cloud;
    final unavailable = provider.status == ProviderStatus.unavailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isCloud ? Icons.cloud_outlined : Icons.computer,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Text(
            provider.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: provider.status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            provider.status.label,
            style: TextStyle(color: provider.status.color, fontSize: 11),
          ),
          const Spacer(),
          Text(
            provider.hint,
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          if (unavailable)
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 30),
              ),
              child: Text(isCloud ? 'Add key' : 'Install'),
            )
          else
            const Icon(Icons.check, size: 16, color: AppColors.accentGreen),
        ],
      ),
    );
  }
}
