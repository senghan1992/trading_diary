// Unit tests for UpdateService's pure logic: JSON parsing, version
// comparison, and the status decision. These don't need a network or
// package_info_plus so they run as fast unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/services/update_service.dart';

void main() {
  group('UpdateConfig.fromJson', () {
    test('parses a fully-populated payload', () {
      final config = UpdateConfig.fromJson({
        'latest_version': '1.2.3',
        'minimum_version': '1.0.0',
        'force_update': true,
        'update_message_ko': '한국어 메시지',
        'update_message_en': 'English message',
        'store_url_ios': 'https://apps.apple.com/app/id111',
        'store_url_android': 'https://play.google.com/store/apps/details?id=x',
      });

      expect(config.latestVersion, '1.2.3');
      expect(config.minimumVersion, '1.0.0');
      expect(config.forceUpdate, true);
      expect(config.messageKo, '한국어 메시지');
      expect(config.messageEn, 'English message');
      expect(config.storeUrlIos, 'https://apps.apple.com/app/id111');
      expect(config.storeUrlAndroid,
          'https://play.google.com/store/apps/details?id=x');
    });

    test('applies safe defaults when fields are missing', () {
      final config = UpdateConfig.fromJson(<String, dynamic>{});

      expect(config.latestVersion, '0.0.0');
      expect(config.minimumVersion, '0.0.0');
      expect(config.forceUpdate, false);
      expect(config.messageKo, isNull);
      expect(config.messageEn, isNull);
      expect(config.storeUrlIos, isNull);
      expect(config.storeUrlAndroid, isNull);
    });

    test('messageFor picks the right locale with sensible fallbacks', () {
      final config = UpdateConfig.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'force_update': false,
        'update_message_ko': '한국어',
        'update_message_en': 'English',
      });

      expect(config.messageFor('ko'), '한국어');
      expect(config.messageFor('en'), 'English');
      expect(config.messageFor('ja'), 'English'); // unknown locale → en
      expect(config.messageFor(null), 'English'); // null → en
    });

    test('messageFor falls back when only one language is supplied', () {
      final koOnly = UpdateConfig.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'force_update': false,
        'update_message_ko': '한국어',
      });
      expect(koOnly.messageFor('ko'), '한국어');
      expect(koOnly.messageFor('en'), '한국어');

      final enOnly = UpdateConfig.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'force_update': false,
        'update_message_en': 'English',
      });
      expect(enOnly.messageFor('ko'), 'English');
      expect(enOnly.messageFor('en'), 'English');
    });

    test('messageFor returns empty string when no message supplied', () {
      final config = UpdateConfig.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'force_update': false,
      });
      expect(config.messageFor('ko'), '');
      expect(config.messageFor('en'), '');
    });
  });

  group('UpdateService.checkStatus', () {
    UpdateConfig cfg({
      String latest = '1.2.0',
      String minimum = '1.0.0',
      bool force = false,
    }) {
      return UpdateConfig.fromJson({
        'latest_version': latest,
        'minimum_version': minimum,
        'force_update': force,
      });
    }

    test('current < minimum → required', () {
      final status =
          UpdateService.instance.checkStatus(cfg(), '0.9.0');
      expect(status, UpdateStatus.required);
    });

    test('current == minimum → not required', () {
      final status =
          UpdateService.instance.checkStatus(cfg(), '1.0.0');
      expect(status, isNot(UpdateStatus.required));
    });

    test('force_update flag overrides even when version is current', () {
      final status = UpdateService.instance.checkStatus(
        cfg(latest: '1.0.0', minimum: '1.0.0', force: true),
        '1.0.0',
      );
      expect(status, UpdateStatus.required);
    });

    test('current < latest (but >= minimum) → optional', () {
      final status =
          UpdateService.instance.checkStatus(cfg(), '1.1.0');
      expect(status, UpdateStatus.optional);
    });

    test('current == latest → upToDate', () {
      final status =
          UpdateService.instance.checkStatus(cfg(), '1.2.0');
      expect(status, UpdateStatus.upToDate);
    });

    test('current > latest → upToDate (no downgrade)', () {
      final status =
          UpdateService.instance.checkStatus(cfg(), '2.0.0');
      expect(status, UpdateStatus.upToDate);
    });

    test('semver ordering is numeric, not lexical', () {
      // Lexical compare would say "1.10.0" < "1.2.0" which is wrong.
      final status =
          UpdateService.instance.checkStatus(cfg(latest: '1.10.0'), '1.2.0');
      expect(status, UpdateStatus.optional);

      final newerStatus =
          UpdateService.instance.checkStatus(cfg(latest: '1.2.0'), '1.10.0');
      expect(newerStatus, UpdateStatus.upToDate);
    });

    test('handles missing patch/minor numbers ("1.0" vs "1.0.0")', () {
      final status = UpdateService.instance.checkStatus(
        cfg(latest: '1.0.0', minimum: '1.0.0'),
        '1.0',
      );
      expect(status, UpdateStatus.upToDate);
    });

    test('drops the "+N" build suffix from pubspec versions', () {
      // pubspec.yaml versions look like "1.0.0+1". PackageInfo returns them
      // already split, but if a caller passes the raw pubspec string, we
      // should still treat it as "1.0.0".
      final status = UpdateService.instance.checkStatus(
        cfg(latest: '1.0.0', minimum: '1.0.0'),
        '1.0.0+1',
      );
      expect(status, UpdateStatus.upToDate);
    });
  });
}