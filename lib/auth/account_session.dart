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
  });

  final Account account;
  final VoidCallback logout;
  final Future<void> Function(bool consent) setConsent;
  final Future<void> Function() resendVerification;
  final Future<void> Function(String current, String next) changePassword;
  final Future<void> Function() deleteAccount;
}
