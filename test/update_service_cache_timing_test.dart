// Tests for the UpdateService startup-bottleneck behavior changes:
//
//   1. The network timeout is short (≤ 3s) so a slow CDN can't stall the
//      splash screen for the previous 5-second ceiling.
//   2. A cached config is returned on subsequent calls without re-hitting
//      the network.
//   3. A network error (timeout / 500) does NOT clobber a known-good cache
//      — the user still sees the app's response to the most recent
//      successful config.
//
// These tests substitute `http.Client` via the `UpdateService.forTest`
// seam introduced alongside this work.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trading_diary/services/update_service.dart';

class _MockClient extends Mock implements http.Client {}

/// Sample valid JSON matching the documented schema.
const String _validPayload = '''
{
  "latest_version": "1.2.0",
  "minimum_version": "1.0.0",
  "force_update": false
}
''';

/// Fake URL that won't match the example.com short-circuit so the test
/// always exercises the HTTP path.
const String _testUrl = 'https://config.test/app-config.json';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse(_testUrl));
  });

  late _MockClient client;
  late UpdateService svc;

  setUp(() {
    client = _MockClient();
    svc = UpdateService.forTest(client: client, url: _testUrl);
  });

  test('first call returns config from network', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response(_validPayload, 200));

    final config = await svc.getConfig();
    expect(config, isNotNull);
    expect(config!.latestVersion, '1.2.0');
  });

  test('second call within cache window skips the second round-trip', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response(_validPayload, 200));

    await svc.getConfig();
    await svc.getConfig();

    verify(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).called(1);
  });

  test('network timeout returns null (does not block startup)', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async {
      // Simulate a CDN slow response that exceeds the 2s ceiling.
      await Future<void>.delayed(const Duration(seconds: 4));
      return http.Response(_validPayload, 200);
    });

    final config = await svc.getConfig();
    expect(config, isNull);
  });

  test('HTTP 500 with no prior cache returns null', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response('server error', 500));

    final config = await svc.getConfig();
    expect(config, isNull);
  });

  test(
    'HTTP 500 after a successful cache preserves the cached config',
    () async {
      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(_validPayload, 200));
      final first = await svc.getConfig();
      expect(first, isNotNull);

      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('transient', 500));

      final second = await svc.getConfig(forceRefresh: true);
      expect(
        second,
        isNotNull,
        reason:
            'a transient 500 must not erase the previous successful '
            'config from the cache',
      );
      expect(second!.latestVersion, first!.latestVersion);
    },
  );

  test('malformed JSON payload returns null without crashing', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response('not-json', 200));

    final config = await svc.getConfig();
    expect(config, isNull);
  });

  test('network exception returns null', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenThrow(Exception('no DNS'));

    final config = await svc.getConfig();
    expect(config, isNull);
  });

  test('hard timeout is at most 3 seconds on a slow CDN', () async {
    final stopwatch = Stopwatch()..start();
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response(_validPayload, 200);
    });
    await svc.getConfig();
    stopwatch.stop();

    expect(
      stopwatch.elapsed.inSeconds,
      lessThan(3),
      reason:
          'the timeout should be tight enough that a cold-start no '
          'longer blocks the splash screen past ~3 seconds',
    );
  });

  test('parses force_update=true payload', () async {
    when(
      () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'latest_version': '1.0.0',
          'minimum_version': '1.0.0',
          'force_update': true,
        }),
        200,
      ),
    );

    final config = await svc.getConfig();
    expect(config, isNotNull);
    expect(config!.forceUpdate, isTrue);
  });
}
