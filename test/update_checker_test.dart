import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmontage_studio/services/update_checker.dart';

void main() {
  test('isNewer compares semver parts', () {
    expect(UpdateChecker.isNewer('1.1.0', '1.0.0'), isTrue);
    expect(UpdateChecker.isNewer('2.0.0', '1.9.9'), isTrue);
    expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(UpdateChecker.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateChecker.isNewer('1.0.0', '1.1.0'), isFalse);
  });

  test('check reports availability against the current version', () async {
    UpdateChecker make(String version) => UpdateChecker(
      currentVersion: '1.0.0',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'version': version, 'url': 'https://x/app.dmg'}),
          200,
        ),
      ),
    );

    final newer = await make('1.2.0').check();
    expect(newer!.available, isTrue);
    expect(newer.url, 'https://x/app.dmg');

    final same = await make('1.0.0').check();
    expect(same!.available, isFalse);
  });

  test('check returns null on failure', () async {
    final checker = UpdateChecker(
      httpClient: MockClient((_) async => http.Response('nope', 500)),
    );
    expect(await checker.check(), isNull);
  });
}
