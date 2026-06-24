import 'package:flutter/material.dart';
import '../screens/auth_screen.dart';
import '../services/auth_client.dart';
import '../services/session_store.dart';
import '../theme/app_theme.dart';
import 'account_session.dart';

/// Gates the app behind authentication. On launch it restores a saved session
/// (token -> /auth/me); if there's none or it's invalid, it shows [AuthScreen].
/// Once authenticated, it builds the app via [appBuilder], passing the account
/// and a logout callback.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authClient,
    required this.sessionStore,
    required this.appBuilder,
    this.initialAccount,
  });

  final AuthClient authClient;
  final SessionStore sessionStore;
  final Widget Function(AccountSession session) appBuilder;

  /// When provided, the gate starts authenticated (used by tests).
  final Account? initialAccount;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Account? _account;
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialAccount != null) {
      _account = widget.initialAccount;
      _loading = false;
    } else {
      _restore();
    }
  }

  Future<void> _restore() async {
    try {
      final token = await widget.sessionStore.readToken();
      if (token != null) {
        final account = await widget.authClient.me(token);
        if (account != null) {
          _token = token;
          _account = account;
        } else {
          await widget.sessionStore.clear();
        }
      }
    } catch (_) {
      // Offline or server unreachable — fall through to the sign-in screen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAuthed(Session session) async {
    await widget.sessionStore.saveToken(session.token);
    if (!mounted) return;
    setState(() {
      _token = session.token;
      _account = session.account;
    });
  }

  Future<void> _logout() async {
    final token = _token;
    await widget.sessionStore.clear();
    if (token != null) await widget.authClient.logout(token);
    if (!mounted) return;
    setState(() {
      _token = null;
      _account = null;
    });
  }

  /// Persists a marketing-consent change (the opt-out path) and updates the
  /// in-memory account.
  Future<void> _setConsent(bool value) async {
    final token = _token;
    if (token == null) return;
    final updated = await widget.authClient.updateProfile(
      token,
      marketingConsent: value,
    );
    if (mounted) setState(() => _account = updated);
  }

  Future<void> _resendVerification() async {
    final token = _token;
    if (token != null) await widget.authClient.resendVerification(token);
  }

  Future<void> _changePassword(String current, String next) async {
    final token = _token;
    if (token == null) return;
    await widget.authClient.changePassword(token, current: current, next: next);
  }

  Future<void> _deleteAccount() async {
    final token = _token;
    if (token != null) await widget.authClient.deleteAccount(token);
    await widget.sessionStore.clear();
    if (!mounted) return;
    setState(() {
      _token = null;
      _account = null;
    });
  }

  Future<ReferralStatus> _referral() async {
    final token = _token;
    if (token == null) throw const AuthException('not signed in');
    return widget.authClient.referral(token);
  }

  Future<CreditStatus> _credits() async {
    final token = _token;
    if (token == null) throw const AuthException('not signed in');
    return widget.authClient.credits(token);
  }

  Future<CreditConsumeResult> _consumeCredit() async {
    final token = _token;
    if (token == null) throw const AuthException('not signed in');
    return widget.authClient.consumeCredit(token);
  }

  Future<CreditStatus> _shareUnlock() async {
    final token = _token;
    if (token == null) throw const AuthException('not signed in');
    return widget.authClient.shareUnlock(token);
  }

  Future<String?> _checkoutUrl() async {
    final token = _token;
    if (token == null) throw const AuthException('not signed in');
    return widget.authClient.billingCheckoutUrl(token);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }
    if (_account == null) {
      return AuthScreen(authClient: widget.authClient, onAuthed: _onAuthed);
    }
    return widget.appBuilder(
      AccountSession(
        account: _account!,
        logout: _logout,
        setConsent: _setConsent,
        resendVerification: _resendVerification,
        changePassword: _changePassword,
        deleteAccount: _deleteAccount,
        referral: _referral,
        credits: _credits,
        consumeCredit: _consumeCredit,
        shareUnlock: _shareUnlock,
        checkoutUrl: _checkoutUrl,
      ),
    );
  }
}
