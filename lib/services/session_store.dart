import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth session token across launches. Only the opaque token is
/// stored locally; the account itself is re-fetched from the server.
class SessionStore {
  static const _key = 'session_token';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
