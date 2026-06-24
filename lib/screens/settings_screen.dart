import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/account_session.dart';
import '../models/catalog.dart';
import '../services/auth_client.dart'
    show AuthException, ReferralStatus, ReferralTier;
import '../services/media_settings.dart';
import '../services/voice_settings.dart';
import '../theme/app_theme.dart';

/// Providers settings: cloud APIs and local engines, grouped by capability. The
/// cloud/local split is what makes online vs offline "just which endpoint."
/// Also hosts the account section (sign out + marketing opt-out).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onBack,
    this.session,
    this.mediaSettings,
    this.voiceSettings,
  });

  final VoidCallback onBack;
  final AccountSession? session;
  final MediaSettings? mediaSettings;
  final VoiceSettings? voiceSettings;

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
              if (session != null) ...[
                _AccountCard(session: session!),
                const SizedBox(height: 20),
                _InviteCard(session: session!),
                const SizedBox(height: 20),
              ],
              if (voiceSettings != null) ...[
                _VoiceSourceCard(voice: voiceSettings!),
                const SizedBox(height: 20),
              ],
              if (mediaSettings != null) ...[
                _MediaSourceCard(media: mediaSettings!),
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
  const _AccountCard({required this.session});
  final AccountSession session;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  late bool _consent = widget.session.account.marketingConsent;
  bool _saving = false;
  String? _verifyMsg;

  Future<void> _resend() async {
    setState(() => _verifyMsg = 'Sending…');
    try {
      await widget.session.resendVerification();
      if (mounted) setState(() => _verifyMsg = 'Verification email sent.');
    } catch (_) {
      if (mounted) setState(() => _verifyMsg = 'Could not send — try later.');
    }
  }

  Future<void> _setConsent(bool value) async {
    if (_saving) return;
    setState(() {
      _consent = value;
      _saving = true;
    });
    try {
      await widget.session.setConsent(value);
    } catch (_) {
      if (mounted) setState(() => _consent = !value); // revert on failure
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(session: widget.session),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete account?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This permanently removes your account and data. This cannot be undone.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.session.deleteAccount();
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
    final a = widget.session.account;
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
                onPressed: widget.session.logout,
                icon: const Icon(Icons.logout, size: 15),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          if (!a.emailVerified) _verifyBanner(),
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
          const Divider(height: 24, color: AppColors.border),
          Row(
            children: [
              TextButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.password, size: 15),
                label: const Text('Change password'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Delete account'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small dialog to change (or, for OAuth-only accounts, set) the password.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.session});
  final AccountSession session;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_next.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is AuthException
              ? e.message
              : 'Could not change password.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Change password',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Current password (leave blank if none)',
              hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _next,
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'New password (min 8 chars)',
              hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.accentAmber,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Update'),
        ),
      ],
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

/// Picks the background-image source (free stock / cloud AI / off) and stores
/// its API key. The chosen source resolves every scene's image at fetch time.
class _MediaSourceCard extends StatefulWidget {
  const _MediaSourceCard({required this.media});
  final MediaSettings media;

  @override
  State<_MediaSourceCard> createState() => _MediaSourceCardState();
}

class _MediaSourceCardState extends State<_MediaSourceCard> {
  final TextEditingController _key = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.media.load().then((_) {
      if (!mounted) return;
      _key.text = widget.media.keyFor(widget.media.selectedId);
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final selected = _ready ? media.selected : media.sources.first;
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
            children: const [
              Icon(Icons.image_outlined, size: 16, color: AppColors.accentPurple),
              SizedBox(width: 8),
              Text(
                'Background images',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Where each scene’s background image comes from.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected.id,
                isExpanded: true,
                dropdownColor: AppColors.surfaceHigh,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                items: [
                  for (final s in media.sources)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                onChanged: (id) async {
                  if (id == null) return;
                  await media.setSource(id);
                  if (!mounted) return;
                  _key.text = media.keyFor(id);
                  setState(() {});
                },
              ),
            ),
          ),
          if (selected.needsKey) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _key,
              obscureText: true,
              onChanged: (v) => media.setKey(selected.id, v.trim()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'API key',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                helperText: selected.keyHint,
                helperStyle: const TextStyle(color: AppColors.textFaint),
                filled: true,
                fillColor: AppColors.background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentPurple),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Invite to unlock" card: shows the user's referral link, how many friends
/// have joined, and the rewards each milestone unlocks. Sharing is the growth
/// loop — every invite that signs up moves the bar and unlocks features.
class _InviteCard extends StatefulWidget {
  const _InviteCard({required this.session});
  final AccountSession session;

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  ReferralStatus? _status;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    widget.session.referral().then((s) {
      if (mounted) setState(() => _status = s);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Could not load your invite status.');
    });
  }

  Future<void> _copy() async {
    final link = _status?.link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withValues(alpha: 0.10),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.card_giftcard, size: 18, color: AppColors.accentPurple),
              SizedBox(width: 8),
              Text(
                'Invite friends, unlock rewards',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Share your link. When a friend installs and signs up, you both win '
            '— each milestone unlocks a feature.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AppColors.accentAmber, fontSize: 12),
            )
          else if (s == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentPurple,
                ),
              ),
            )
          else ...[
            // The shareable link + copy button.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _copy,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 15),
                    label: Text(_copied ? 'Copied' : 'Copy'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      foregroundColor: AppColors.background,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _progressLine(s),
            const SizedBox(height: 12),
            for (final tier in s.tiers) _tierRow(tier, s),
          ],
        ],
      ),
    );
  }

  Widget _progressLine(ReferralStatus s) {
    final next = s.next;
    final target = next?.at ?? (s.tiers.isEmpty ? 1 : s.tiers.last.at);
    final fraction = target == 0 ? 1.0 : (s.invited / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${s.invited} ${s.invited == 1 ? "friend" : "friends"} joined',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (next != null)
              Text(
                '${next.at - s.invited} more → ${next.label}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              )
            else
              const Text(
                'All rewards unlocked 🎉',
                style: TextStyle(color: AppColors.accentGreen, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: const AlwaysStoppedAnimation(AppColors.accentPurple),
          ),
        ),
      ],
    );
  }

  Widget _tierRow(ReferralTier tier, ReferralStatus s) {
    final unlocked = s.unlocks.contains(tier.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: unlocked ? AppColors.accentGreen : AppColors.textFaint,
          ),
          const SizedBox(width: 8),
          Text(
            tier.label,
            style: TextStyle(
              color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '${tier.at} ${tier.at == 1 ? "invite" : "invites"}',
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

/// Picks the narration engine (OS-native / cloud neural) and stores its API key.
/// The system voice is always available and free, so narration works with no
/// setup on macOS, Windows, and Linux; cloud voices are an opt-in upgrade.
class _VoiceSourceCard extends StatefulWidget {
  const _VoiceSourceCard({required this.voice});
  final VoiceSettings voice;

  @override
  State<_VoiceSourceCard> createState() => _VoiceSourceCardState();
}

class _VoiceSourceCardState extends State<_VoiceSourceCard> {
  final TextEditingController _key = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.voice.load().then((_) {
      if (!mounted) return;
      _key.text = widget.voice.keyFor(widget.voice.selectedId);
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.voice;
    final selected = _ready ? voice.selected : voice.sources.first;
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
            children: const [
              Icon(Icons.record_voice_over_outlined,
                  size: 16, color: AppColors.accentCyan),
              SizedBox(width: 8),
              Text(
                'Narration voice',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Which engine speaks the narration. The system voice is free and '
            'runs offline on every platform.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected.id,
                isExpanded: true,
                dropdownColor: AppColors.surfaceHigh,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                items: [
                  for (final s in voice.sources)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                onChanged: (id) async {
                  if (id == null) return;
                  await voice.setSource(id);
                  if (!mounted) return;
                  _key.text = voice.keyFor(id);
                  setState(() {});
                },
              ),
            ),
          ),
          if (selected.needsKey) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _key,
              obscureText: true,
              onChanged: (v) => voice.setKey(selected.id, v.trim()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'API key',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                helperText: selected.keyHint,
                helperStyle: const TextStyle(color: AppColors.textFaint),
                filled: true,
                fillColor: AppColors.background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.check_circle_outline,
                    size: 14, color: AppColors.accentGreen),
                SizedBox(width: 6),
                Text(
                  'No setup needed — free & offline.',
                  style: TextStyle(color: AppColors.accentGreen, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
