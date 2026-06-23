import 'package:flutter/material.dart';
import '../models/catalog.dart';
import '../services/auth_client.dart';
import '../theme/app_theme.dart';

/// Providers settings: cloud APIs and local engines, grouped by capability. The
/// cloud/local split is what makes online vs offline "just which endpoint."
/// Also hosts the account section (sign out + marketing opt-out).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onBack,
    this.account,
    this.onLogout,
    this.onSetConsent,
    this.onResendVerification,
  });

  final VoidCallback onBack;
  final Account? account;
  final VoidCallback? onLogout;
  final Future<void> Function(bool)? onSetConsent;
  final Future<void> Function()? onResendVerification;

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
              if (account != null) ...[
                _AccountCard(
                  account: account!,
                  onLogout: onLogout,
                  onSetConsent: onSetConsent,
                  onResendVerification: onResendVerification,
                ),
                const SizedBox(height: 20),
              ],
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

/// Account card: identity, sign out, and a marketing-email toggle that writes
/// the consent change back to the server (the opt-out path).
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.account,
    this.onLogout,
    this.onSetConsent,
    this.onResendVerification,
  });
  final Account account;
  final VoidCallback? onLogout;
  final Future<void> Function(bool)? onSetConsent;
  final Future<void> Function()? onResendVerification;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  late bool _consent = widget.account.marketingConsent;
  bool _saving = false;
  String? _verifyMsg;

  Future<void> _resend() async {
    final resend = widget.onResendVerification;
    if (resend == null) return;
    setState(() => _verifyMsg = 'Sending…');
    try {
      await resend();
      if (mounted) setState(() => _verifyMsg = 'Verification email sent.');
    } catch (_) {
      if (mounted) setState(() => _verifyMsg = 'Could not send — try later.');
    }
  }

  Future<void> _setConsent(bool value) async {
    final update = widget.onSetConsent;
    if (update == null || _saving) {
      setState(() => _consent = value);
      return;
    }
    setState(() {
      _consent = value;
      _saving = true;
    });
    try {
      await update(value); // persisted server-side by the auth gate
    } catch (_) {
      if (mounted) setState(() => _consent = !value); // revert on failure
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _verifyBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 16,
            color: AppColors.accentAmber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _verifyMsg ?? 'Your email isn\'t verified yet.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _resend,
            child: const Text(
              'Resend',
              style: TextStyle(color: AppColors.accentCyan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                color: AppColors.accentCyan,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name?.isNotEmpty == true ? a.name! : a.email,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      a.country != null ? '${a.email} · ${a.country}' : a.email,
                      style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 15),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          if (!widget.account.emailVerified) _verifyBanner(),
          const Divider(height: 24, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product updates & marketing emails',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: _saving ? FontWeight.w400 : FontWeight.w400,
                  ),
                ),
              ),
              Switch(
                value: _consent,
                onChanged: _saving ? null : _setConsent,
                activeThumbColor: AppColors.accentCyan,
              ),
            ],
          ),
        ],
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
