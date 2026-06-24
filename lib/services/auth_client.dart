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
    this.referralCode,
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

  /// The user's shareable referral code (null until first issued server-side).
  final String? referralCode;

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
    referralCode: json['referral_code'] as String?,
  );
}

/// A reward unlocked (or to be unlocked) by inviting friends.
class ReferralTier {
  const ReferralTier({required this.at, required this.key, required this.label});
  final int at;
  final String key;
  final String label;

  factory ReferralTier.fromJson(Map<String, dynamic> json) => ReferralTier(
    at: (json['at'] as num).toInt(),
    key: json['key'] as String,
    label: json['label'] as String,
  );
}

/// The signed-in user's referral standing: their code/link, how many people
/// they've brought in, and which rewards that unlocks.
class ReferralStatus {
  const ReferralStatus({
    required this.code,
    required this.link,
    required this.invited,
    required this.unlocks,
    required this.tiers,
    this.next,
  });

  final String code;
  final String link;
  final int invited;
  final List<String> unlocks;
  final List<ReferralTier> tiers;
  final ReferralTier? next;

  bool hasUnlock(String key) => unlocks.contains(key);

  factory ReferralStatus.fromJson(Map<String, dynamic> json) => ReferralStatus(
    code: json['code'] as String,
    link: json['link'] as String,
    invited: (json['invited'] as num?)?.toInt() ?? 0,
    unlocks: ((json['unlocks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    tiers: ((json['tiers'] as List?) ?? const [])
        .map((e) => ReferralTier.fromJson(e as Map<String, dynamic>))
        .toList(),
    next: json['next'] == null
        ? null
        : ReferralTier.fromJson(json['next'] as Map<String, dynamic>),
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

  static const String defaultBaseUrl = 'https://auth.opencli.ai';

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
    String? ref,
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
      if (ref != null && ref.trim().isNotEmpty) 'ref': ref.trim(),
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

  /// Fetches the signed-in user's referral status (code, invite count, unlocks).
  Future<ReferralStatus> referral(String token) async {
    final res = await _http
        .get(
          Uri.parse('$baseUrl/referral'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw AuthException((json['error'] as String?) ?? 'could not load referral');
    }
    return ReferralStatus.fromJson(json);
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

  /// Requests a password-reset email. Always succeeds (never reveals whether
  /// the address has an account).
  Future<void> forgotPassword(String email) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/auth/forgot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Swallow — we don't surface success/failure to avoid account probing.
    }
  }

  /// Changes the password for the signed-in user. [current] may be empty for
  /// accounts created via OAuth that have no password yet.
  Future<void> changePassword(
    String token, {
    required String current,
    required String next,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/auth/password'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'current': current, 'new': next}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      throw AuthException((json['error'] as String?) ?? 'could not change');
    }
  }

  /// Permanently deletes the signed-in user's account.
  Future<void> deleteAccount(String token) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/auth/delete'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw const AuthException('could not delete account');
    }
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
