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

  test('pollOAuth is null while pending and a session when ready', () async {
    var pending = true;
    final client = AuthClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/oauth/exchange')) {
          if (pending) {
            pending = false;
            return http.Response('{"pending":true}', 202);
          }
          return http.Response(
            jsonEncode({
              'token': 't2',
              'user': {'id': 'u2', 'email': 'g@h.com'},
            }),
            200,
          );
        }
        return http.Response('no', 404);
      }),
    );

    expect(await client.pollOAuth('state'), isNull);
    final session = await client.pollOAuth('state');
    expect(session?.token, 't2');
    expect(session?.account.email, 'g@h.com');
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

  test('register forwards an invite code as ref', () async {
    Map<String, dynamic>? sent;
    final client = AuthClient(
      httpClient: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'token': 't',
            'user': {'id': 'u', 'email': 'a@b.com'},
          }),
          200,
        );
      }),
    );
    await client.register(
      email: 'a@b.com',
      password: 'supersecret1',
      ref: '5qbt83',
    );
    expect(sent?['ref'], '5qbt83');
  });

  test('referral parses code, invite count, and unlocks', () async {
    final client = AuthClient(
      httpClient: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok');
        return http.Response(
          jsonEncode({
            'code': '5QBT83',
            'link': 'https://get.opencli.ai/?ref=5QBT83',
            'invited': 1,
            'unlocks': ['premium_voices'],
            'next': {'at': 3, 'key': 'no_branding', 'label': 'Remove the end card'},
            'tiers': [
              {'at': 1, 'key': 'premium_voices', 'label': 'Premium cloud voices'},
              {'at': 3, 'key': 'no_branding', 'label': 'Remove the end card'},
            ],
          }),
          200,
        );
      }),
    );
    final status = await client.referral('tok');
    expect(status.code, '5QBT83');
    expect(status.invited, 1);
    expect(status.hasUnlock('premium_voices'), isTrue);
    expect(status.hasUnlock('no_branding'), isFalse);
    expect(status.next?.label, 'Remove the end card');
    expect(status.tiers.length, 2);
  });
}
