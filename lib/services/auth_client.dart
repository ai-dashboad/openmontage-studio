import 'dart:convert';
import 'package:http/http.dart' as http;

/// An authenticated account.
class Account {
  const Account({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? createdAt;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    createdAt: json['created_at'] as String?,
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
  }) {
    return _session('/auth/register', {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  Future<Session> login({required String email, required String password}) {
    return _session('/auth/login', {'email': email, 'password': password});
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
