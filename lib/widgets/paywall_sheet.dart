import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/account_session.dart';
import '../services/auth_client.dart';
import '../theme/app_theme.dart';

/// Shows the paywall when a free user runs out of render credits. Returns true
/// if the user earned credits (e.g. via the "share on X" reward) and the render
/// should be retried; false/null otherwise.
Future<bool?> showPaywallSheet(
  BuildContext context, {
  required AccountSession session,
  required CreditStatus status,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PaywallSheet(session: session, status: status),
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({required this.session, required this.status});
  final AccountSession session;
  final CreditStatus status;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  late CreditStatus _status = widget.status;
  bool _busy = false;
  String? _note;

  // The pre-written post for the "share to unlock" reward.
  static const _tweetText =
      "I'm making videos just by describing them with OpenMontage Studio — "
      'a free, local AI video studio for Mac & Windows. ⚡';
  static const _tweetUrl = 'https://get.opencli.ai';

  Future<void> _subscribe() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final url = await widget.session.checkoutUrl();
      if (url == null) {
        setState(() => _note = 'Pro checkout is coming soon — hang tight!');
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (mounted) {
          setState(
            () => _note = 'Finish checkout in your browser, then render again.',
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Could not start checkout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final intent = Uri.parse(
        'https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent(_tweetText)}'
        '&url=${Uri.encodeComponent(_tweetUrl)}',
      );
      await launchUrl(intent, mode: LaunchMode.externalApplication);
      // We can't verify the post, so claim the (capped) reward on return.
      final updated = await widget.session.shareUnlock();
      if (!mounted) return;
      setState(() => _status = updated);
      // Credits granted — let the caller retry the render.
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _note = 'Reward unavailable right now.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "You've used your ${s.freeAllowance} free renders",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Go Pro for unlimited renders — or earn more for free.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Pro upgrade.
          _OptionCard(
            accent: AppColors.accentCyan,
            icon: Icons.workspace_premium,
            title: 'OpenMontage Pro',
            subtitle: 'Unlimited renders · no end card · premium voices',
            actionLabel: 'Upgrade',
            onAction: _busy ? null : _subscribe,
          ),
          const SizedBox(height: 12),

          // Share on X for credits.
          if (s.canShareUnlock)
            _OptionCard(
              accent: AppColors.accentPurple,
              icon: Icons.ios_share,
              title: 'Share on X for +${s.shareReward} renders',
              subtitle:
                  'Post about OpenMontage '
                  '(${s.shareUnlocksUsed}/${s.shareUnlocksMax} used)',
              actionLabel: 'Share',
              onAction: _busy ? null : _share,
            )
          else
            const _MutedLine(
              icon: Icons.ios_share,
              text: 'Share reward already claimed — thank you!',
            ),
          const SizedBox(height: 12),

          const _MutedLine(
            icon: Icons.card_giftcard,
            text: 'Invite friends in Settings — +3 renders each.',
          ),

          if (_note != null) ...[
            const SizedBox(height: 14),
            Text(
              _note!,
              style: const TextStyle(color: AppColors.accentAmber, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text(
                'Maybe later',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppColors.background,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
