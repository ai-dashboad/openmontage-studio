import 'package:flutter/foundation.dart';
import '../services/auth_client.dart';

/// The signed-in account plus the actions the app can take on it. Built by the
/// auth gate (which holds the session token) and handed to the app, so screens
/// don't need the raw token.
class AccountSession {
  const AccountSession({
    required this.account,
    required this.logout,
    required this.setConsent,
    required this.resendVerification,
    required this.changePassword,
    required this.deleteAccount,
    required this.referral,
    required this.credits,
    required this.consumeCredit,
    required this.shareUnlock,
    required this.checkoutUrl,
  });

  final Account account;
  final VoidCallback logout;
  final Future<void> Function(bool consent) setConsent;
  final Future<void> Function() resendVerification;
  final Future<void> Function(String current, String next) changePassword;
  final Future<void> Function() deleteAccount;

  /// Fetches the user's referral status (code, invite count, unlocked rewards).
  final Future<ReferralStatus> Function() referral;

  /// Fetches the current credit balance and plan.
  final Future<CreditStatus> Function() credits;

  /// Consumes one credit for a render; the result says whether it was allowed.
  final Future<CreditConsumeResult> Function() consumeCredit;

  /// Claims the "share on X" reward (+credits), returning the new balance.
  final Future<CreditStatus> Function() shareUnlock;

  /// Starts Pro checkout; returns the URL, or null if billing isn't configured.
  final Future<String?> Function() checkoutUrl;
}
