import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_client.dart';
import '../theme/app_theme.dart';

/// Sign in / create account. On success, calls [onAuthed] with the session.
///
/// Registration optionally collects marketing/segmentation data, but only with
/// an explicit, unchecked-by-default opt-in. The consent is the lawful basis for
/// any later marketing; users can withdraw it from settings.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authClient,
    required this.onAuthed,
  });

  final AuthClient authClient;
  final ValueChanged<Session> onAuthed;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  bool _oauthBusy = false;
  String? _error;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _useCase = TextEditingController();
  final _invite = TextEditingController();
  String? _source;
  bool _consent = false;

  static const _sources = [
    'Search engine',
    'Social media',
    'Friend or colleague',
    'Blog or article',
    'Other',
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _useCase.dispose();
    _invite.dispose();
    super.dispose();
  }

  String? _locale() {
    try {
      return Platform.localeName; // e.g. en_US
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = _register
          ? await widget.authClient.register(
              email: _email.text.trim(),
              password: _password.text,
              name: _name.text.trim(),
              marketingConsent: _consent,
              marketingSource: _consent ? _source : null,
              useCase: _useCase.text.trim(),
              locale: _locale(),
              ref: _invite.text.trim(),
            )
          : await widget.authClient.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      widget.onAuthed(session);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not reach the server. Check your network.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email, then tap Forgot password.');
      return;
    }
    await widget.authClient.forgotPassword(email);
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        content: Text(
          'If that email has an account, a reset link is on its way.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  /// Opens the browser for [provider] sign-in and polls for the result.
  Future<void> _oauth(String provider) async {
    if (_busy || _oauthBusy) return;
    setState(() {
      _oauthBusy = true;
      _error = null;
    });
    final state = AuthClient.newOAuthState();
    try {
      final ok = await launchUrl(
        widget.authClient.oauthStartUri(provider, state),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        if (mounted) setState(() => _error = 'Could not open the browser.');
        return;
      }
      for (var i = 0; i < 60; i++) {
        if (!_oauthBusy || !mounted) return; // cancelled
        await Future.delayed(const Duration(seconds: 2));
        final session = await widget.authClient.pollOAuth(state);
        if (session != null) {
          widget.onAuthed(session);
          return;
        }
      }
      if (mounted) setState(() => _error = 'Sign-in timed out. Try again.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not complete sign-in.');
    } finally {
      if (mounted) setState(() => _oauthBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.blur_circular,
                        color: AppColors.accentCyan,
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'OpenMontage Studio',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _register ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    _field(_name, 'Name', Icons.person_outline),
                    const SizedBox(height: 10),
                  ],
                  _field(
                    _email,
                    'Email',
                    Icons.mail_outline,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _password,
                    'Password',
                    Icons.lock_outline,
                    obscure: true,
                  ),
                  if (_register) ...[
                    const SizedBox(height: 10),
                    _useCaseField(),
                    const SizedBox(height: 10),
                    _sourceField(),
                    const SizedBox(height: 10),
                    _field(_invite, 'Invite code (optional)',
                        Icons.card_giftcard),
                    const SizedBox(height: 12),
                    _consentTile(),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgot,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.accentAmber,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : Text(_register ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : "New here? Create an account",
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _socialSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      enabled: !_busy,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _useCaseField() {
    return _field(
      _useCase,
      'What do you want to make? (optional)',
      Icons.auto_awesome_outlined,
    );
  }

  Widget _sourceField() {
    return DropdownButtonFormField<String>(
      initialValue: _source,
      isExpanded: true,
      dropdownColor: AppColors.surfaceHigh,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.travel_explore,
          size: 18,
          color: AppColors.textMuted,
        ),
        hintText: 'How did you hear about us? (optional)',
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: [
        for (final s in _sources) DropdownMenuItem(value: s, child: Text(s)),
      ],
      onChanged: _busy ? null : (v) => setState(() => _source = v),
    );
  }

  Widget _consentTile() {
    return InkWell(
      onTap: _busy ? null : () => setState(() => _consent = !_consent),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _consent,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _consent = v ?? false),
              activeColor: AppColors.accentCyan,
              checkColor: AppColors.background,
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Send me product updates and tips. You can unsubscribe any '
                  'time in settings.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialSection() {
    if (_oauthBusy) {
      return Column(
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Waiting for the browser…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _oauthBusy = false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textFaint),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'or continue with',
                style: TextStyle(color: AppColors.textFaint, fontSize: 11),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _socialButton(
                'GitHub',
                Icons.code,
                () => _oauth('github'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _socialButton(
                'Google',
                Icons.g_mobiledata,
                () => _oauth('google'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 18, color: AppColors.textPrimary),
      label: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
