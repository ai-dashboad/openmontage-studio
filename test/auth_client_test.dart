import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmontage_studio/services/auth_client.dart';

void main() {
  test('register returns a session with token and account', () async {
    final client = AuthClient(
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth/register') {
          return http.Response(
            jsonEncode({
              'token': 'tok123',
              'user': {
                'id': 'u1',
                'email': 'a@b.com',
                'name': 'A',
                'created_at': '2026',
              },
            }),
            200,
          );
        }
        return http.Response('nope', 404);
      }),
    );

    final session = await client.register(
      email: 'a@b.com',
      password: 'supersecret1',
      name: 'A',
    );
    expect(session.token, 'tok123');
    expect(session.account.email, 'a@b.com');
    expect(session.account.name, 'A');
  });

  test('a failed login throws AuthException with the server message', () async {
    final client = AuthClient(
      httpClient: MockClient(
        (req) async => http.Response(
          jsonEncode({'error': 'invalid email or password'}),
          401,
        ),
      ),
    );

    expect(
      () => client.login(email: 'a@b.com', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('me returns null for an invalid session', () async {
    final client = AuthClient(
      httpClient: MockClient(
        (req) async =>
            http.Response(jsonEncode({'error': 'invalid session'}), 401),
      ),
    );
    expect(await client.me('bad-token'), isNull);
  });
}
