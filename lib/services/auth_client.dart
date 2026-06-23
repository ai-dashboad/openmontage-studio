import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// An authenticated account.
class Account {
  const Account({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
    this.marketingConsent = false,
    this.marketingSource,
    this.useCase,
    this.country,
    this.emailVerified = false,
  });

  final String id;
  final String email;
  final String? name;
  final String? createdAt;

  /// Whether the user opted in to marketing communications.
  final bool marketingConsent;
  final String? marketingSource;
  final String? useCase;
  final String? country;

  /// Whether the email address has been confirmed.
  final bool emailVerified;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    createdAt: json['created_at'] as String?,
    marketingConsent: json['marketing_consent'] == true,
    marketingSource: json['marketing_source'] as String?,
    useCase: json['use_case'] as String?,
    country: json['country'] as String?,
    emailVerified: json['email_verified'] == true,
  );
}

/// A session: the account plus its bearer token.
class Session {
  const Session({required this.token, required this.account});
  final String token;
  final Account account;
}

/// Client for the OpenMontage Studio auth Worker (Cloudflare). Registration,
/// login, and session lookup over HTTPS. Injectable for tests.
class AuthClient {
  AuthClient({this.baseUrl = defaultBaseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const String defaultBaseUrl =
      'https://openmontage-auth.272876047.workers.dev';

  final String baseUrl;
  final http.Client _http;

  Future<Session> register({
    required String email,
    required String password,
    String? name,
    bool marketingConsent = false,
    String? marketingSource,
    String? useCase,
    String? locale,
  }) {
    return _session('/auth/register', {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
      'marketing_consent': marketingConsent,
      if (marketingSource != null && marketingSource.isNotEmpty)
        'marketing_source': marketingSource,
      if (useCase != null && useCase.isNotEmpty) 'use_case': useCase,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
    });
  }

  Future<Session> login({required String email, required String password}) {
    return _session('/auth/login', {'email': email, 'password': password});
  }

  /// Updates the account's name and marketing fields. Pass
  /// [marketingConsent] = false to opt out. Returns the updated account.
  Future<Account> updateProfile(
    String token, {
    String? name,
    bool? marketingConsent,
    String? marketingSource,
    String? useCase,
  }) async {
    final res = await _http
        .patch(
          Uri.parse('$baseUrl/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': ?name,
            'marketing_consent': ?marketingConsent,
            'marketing_source': ?marketingSource,
            'use_case': ?useCase,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw AuthException((json['error'] as String?) ?? 'update failed');
    }
    return Account.fromJson(json['user'] as Map<String, dynamic>);
  }

  // ---- third-party (OAuth) sign-in ----

  /// A fresh random state to tie a browser flow to this app instance.
  static String newOAuthState() {
    final r = Random.secure();
    return List.generate(
      24,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// The URL to open in the system browser to start [provider] sign-in.
  Uri oauthStartUri(String provider, String state) =>
      Uri.parse('$baseUrl/auth/oauth/$provider/start?state=$state');

  /// Polls for the OAuth result. Returns the [Session] once the browser flow
  /// completes, or null while it's still pending.
  Future<Session?> pollOAuth(String state) async {
    final res = await _http
        .get(Uri.parse('$baseUrl/auth/oauth/exchange?state=$state'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 202) return null; // pending
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw AuthException((json['error'] as String?) ?? 'sign-in failed');
    }
    return Session(
      token: json['token'] as String,
      account: Account.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Resolves the account for a session token, or null if it's invalid.
  Future<Account?> me(String token) async {
    final res = await _http
        .get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Account.fromJson(body['user'] as Map<String, dynamic>);
  }

  /// Asks the server to re-send the verification email for this session.
  Future<void> resendVerification(String token) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/auth/verify/resend'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      throw AuthException((json['error'] as String?) ?? 'could not resend');
    }
  }

  Future<void> logout(String token) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort; the local session is cleared regardless.
    }
  }

  Future<Session> _session(String path, Map<String, dynamic> body) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw AuthException((json['error'] as String?) ?? 'request failed');
    }
    return Session(
      token: json['token'] as String,
      account: Account.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}
