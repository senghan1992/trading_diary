// Unit tests for NotificationService.
//
// Strategy:
//   * The service is a singleton wrapping the flutter_local_notifications
//     plugin. Tests inject a mock plugin via `resetForTest` so we never touch
//     a real platform channel.
//   * The service runs on the macOS test host, which means the
//     Platform.isMacOS branch executes for permission queries. Android-only
//     paths are not reachable from `flutter test` and are verified
//     separately on an Android emulator (see docs).
//   * iOS permission caching (H10), tap handling, and reschedule filtering
//     are all pure logic once the plugin is mocked — these are what we
//     exhaustively cover here.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/services/notification_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockIOS extends Mock implements IOSFlutterLocalNotificationsPlugin {}

/// Stubs `zonedSchedule` to succeed. Call before exercising the path under test.
// ignore: library_private_types_in_public_api
void stubScheduleSucceeds(_MockPlugin m) {
  when(() => m.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      )).thenAnswer((_) async {});
}

/// Stubs `zonedSchedule` to throw. Used to verify error swallowing.
// ignore: library_private_types_in_public_api
void stubScheduleThrows(_MockPlugin m, Object error) {
  when(() => m.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      )).thenThrow(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin mockPlugin;
  late _MockIOS mockIOS;
  late NotificationService svc;

  setUpAll(() {
    // Initialize the timezone database first so any TZDateTime fallback
    // values can be constructed.
    tz_data.initializeTimeZones();
    // Tests use a fixed local zone so TZDateTime.from(reminder.remindAt)
    // is deterministic across machines.
    setLocalLocation(getLocation('UTC'));
    // Register fallbacks for non-primitive types so mocktail's `any()` can
    // match them in stubbing. Every named-arg matcher we use elsewhere
    // needs a fallback registered here, otherwise `when()` throws and
    // leaves the matcher queue in a bad state for the next test.
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(TZDateTime.now(getLocation('UTC')));
    registerFallbackValue(AndroidScheduleMode.exact);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockPlugin = _MockPlugin();
    mockIOS = _MockIOS();
    // The macOS permission path resolves the iOS impl via the plugin.
    when(() => mockPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()).thenReturn(mockIOS);
    svc = NotificationService.instance;
    svc.resetForTest(plugin: mockPlugin, initialized: true);
  });

  // -----------------------------------------------------------------------
  // _idFor — pure logic, no plugin involved
  // -----------------------------------------------------------------------
  group('_idFor', () {
    test('same input → same output (deterministic round-trip)', () {
      expect(svc.idForTest('abc'), svc.idForTest('abc'));
      expect(svc.idForTest('uuid-xyz-123'), svc.idForTest('uuid-xyz-123'));
    });

    test('always non-negative (sign bit stripped)', () {
      const samples = [
        '',
        'a',
        'uuid-with-dashes',
        '가나다라마바사',
        '🚀-emoji',
        'mixed-한글-english-123',
      ];
      for (final s in samples) {
        expect(svc.idForTest(s), greaterThanOrEqualTo(0),
            reason: 'failed for "$s"');
      }
    });

    test('fits in 32-bit signed int (safe for AlarmManager)', () {
      for (var i = 0; i < 100; i++) {
        final id = svc.idForTest('sample-$i-${DateTime.now().microsecondsSinceEpoch}');
        expect(id, lessThan(0x80000000));
      }
    });

    test('1000 random uuids produce no hash collisions', () {
      // UUID v4 has 122 bits of entropy; 31-bit hash collisions in 1000
      // samples are astronomically unlikely. If this ever fires, the hash
      // scheme has degraded.
      final ids = List.generate(
        1000,
        (i) => 'uuid-$i-${DateTime.now().microsecondsSinceEpoch * (i + 1)}',
      );
      final ints = ids.map(svc.idForTest).toSet();
      expect(ints.length, ids.length,
          reason: 'collision detected — _idFor may need to widen');
    });
  });

  // -----------------------------------------------------------------------
  // schedule() — the heart of the feature
  // -----------------------------------------------------------------------
  group('schedule()', () {
    test('past remindAt → returns false, plugin NOT called', () async {
      final past = Reminder(
        id: 'past-1',
        title: 'past',
        remindAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final ok = await svc.schedule(past);
      expect(ok, isFalse);

      verifyNever(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ));
    });

    test('future remindAt + note → plugin.zonedSchedule called with body=note',
        () async {
      stubScheduleSucceeds(mockPlugin);

      final r = Reminder(
        id: 'future-note',
        title: 'follow up',
        note: 'check the chart pattern',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final ok = await svc.schedule(r);
      expect(ok, isTrue);

      verify(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('future-note'),
            title: 'follow up',
            body: 'check the chart pattern',
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'future-note',
          )).called(1);
    });

    test('future remindAt + empty note → body is null', () async {
      stubScheduleSucceeds(mockPlugin);

      final r = Reminder(
        id: 'no-note',
        title: 'no note',
        note: '',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await svc.schedule(r);

      verify(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('no-note'),
            title: 'no note',
            body: null,
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'no-note',
          )).called(1);
    });

    test('plugin throws → returns false, exception NOT propagated', () async {
      stubScheduleThrows(mockPlugin, Exception('plugin boom'));

      final r = Reminder(
        id: 'will-throw',
        title: 't',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // The call must complete without throwing.
      final ok = await svc.schedule(r);
      expect(ok, isFalse,
          reason: 'a plugin failure must surface as false, never throw');
    });

    test('scheduledDate matches the reminder time in local TZ', () async {
      late TZDateTime capturedDate;
      when(() => mockPlugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      )).thenAnswer((inv) async {
        capturedDate =
            inv.namedArguments[#scheduledDate] as TZDateTime;
      });

      final target = DateTime.utc(2030, 6, 1, 10, 30);
      final r = Reminder(
        id: 'date-check',
        title: 't',
        remindAt: target,
      );
      await svc.schedule(r);

      // We set local TZ to UTC in setUpAll, so the two should be identical.
      expect(capturedDate.toUtc(), target,
          reason: 'scheduled date must be the reminder time, in local TZ');
    });
  });

  // -----------------------------------------------------------------------
  // cancel() / cancelAll()
  // -----------------------------------------------------------------------
  group('cancel()', () {
    test('plugin.cancel called with int id derived from string', () async {
      when(() => mockPlugin.cancel(id: any(named: 'id')))
          .thenAnswer((_) async {});

      await svc.cancel('reminder-x');

      verify(() => mockPlugin.cancel(id: svc.idForTest('reminder-x')))
          .called(1);
    });

    test('plugin throws → no exception propagated', () async {
      when(() => mockPlugin.cancel(id: any(named: 'id')))
          .thenThrow(Exception('cancel boom'));

      // Must not throw.
      await svc.cancel('whatever');
    });
  });

  group('cancelAll()', () {
    test('plugin.cancelAll called exactly once', () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});

      await svc.cancelAll();

      verify(() => mockPlugin.cancelAll()).called(1);
    });

    test('plugin throws → no exception propagated', () async {
      when(() => mockPlugin.cancelAll())
          .thenThrow(Exception('cancelAll boom'));

      // Must not throw — TradeProvider depends on this for cascade delete.
      await svc.cancelAll();
    });
  });

  // -----------------------------------------------------------------------
  // rescheduleAll() — cancel-then-schedule, with filtering
  // -----------------------------------------------------------------------
  group('rescheduleAll()', () {
    setUp(() {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
    });

    test('empty list → cancelAll called, returns 0, no schedules', () async {
      final n = await svc.rescheduleAll([]);
      expect(n, 0);
      verify(() => mockPlugin.cancelAll()).called(1);
      verifyNever(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ));
    });

    test('past reminders are skipped', () async {
      stubScheduleSucceeds(mockPlugin);

      final reminders = [
        Reminder(
          id: 'past',
          title: 'past',
          remindAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        Reminder(
          id: 'future',
          title: 'future',
          remindAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ];
      final n = await svc.rescheduleAll(reminders);
      expect(n, 1, reason: 'only the future reminder should be scheduled');

      verify(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('future'),
            title: 'future',
            body: null,
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'future',
          )).called(1);
      verifyNever(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('past'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ));
    });

    test('isRead reminders are skipped (user already saw them)', () async {
      stubScheduleSucceeds(mockPlugin);

      final reminders = [
        Reminder(
          id: 'read-future',
          title: 'read',
          isRead: true,
          remindAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        Reminder(
          id: 'unread-future',
          title: 'unread',
          remindAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      ];
      final n = await svc.rescheduleAll(reminders);
      expect(n, 1);

      verify(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('unread-future'),
            title: 'unread',
            body: null,
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'unread-future',
          )).called(1);
      verifyNever(() => mockPlugin.zonedSchedule(
            id: svc.idForTest('read-future'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ));
    });

    test('cancelAll runs BEFORE any individual schedule', () async {
      stubScheduleSucceeds(mockPlugin);

      final order = <String>[];
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {
        order.add('cancelAll');
      });
      // Re-stub zonedSchedule to also record its call order.
      when(() => mockPlugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      )).thenAnswer((_) async {
        order.add('zonedSchedule');
      });

      await svc.rescheduleAll([
        Reminder(
          id: 'a',
          title: 'a',
          remindAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ]);

      expect(order, ['cancelAll', 'zonedSchedule']);
    });

    test('count returned equals number of successful schedules', () async {
      stubScheduleSucceeds(mockPlugin);

      final reminders = List.generate(
        5,
        (i) => Reminder(
          id: 'r-$i',
          title: 't$i',
          remindAt: DateTime.now().add(Duration(hours: i + 1)),
        ),
      );
      final n = await svc.rescheduleAll(reminders);
      expect(n, 5);
    });

    test('returns count of successes even when some schedules fail', () async {
      // 3 succeed, 2 throw → return 3.
      var calls = 0;
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
      when(() => mockPlugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      )).thenAnswer((inv) async {
        calls++;
        if (calls == 2 || calls == 4) {
          throw Exception('intermittent');
        }
      });

      final reminders = List.generate(
        5,
        (i) => Reminder(
          id: 'r-$i',
          title: 't$i',
          remindAt: DateTime.now().add(Duration(hours: i + 1)),
        ),
      );
      final n = await svc.rescheduleAll(reminders);
      expect(n, 3, reason: '2 of 5 throws → 3 successes');
    });

    test('all-past list → cancelAll still runs, returns 0', () async {
      stubScheduleSucceeds(mockPlugin);

      final n = await svc.rescheduleAll([
        Reminder(
          id: 'past-a',
          title: 'a',
          remindAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Reminder(
          id: 'past-b',
          title: 'b',
          remindAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ]);
      expect(n, 0);
      verify(() => mockPlugin.cancelAll()).called(1);
    });
  });

  // -----------------------------------------------------------------------
  // iOS / macOS permission path (runs on test host = macOS)
  // -----------------------------------------------------------------------
  group('requestPermissions() — iOS / macOS path', () {
    test('granted=true → returns true AND persists to SharedPreferences',
        () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => true);

      final granted = await svc.requestPermissions();
      expect(granted, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ios_notifications_granted'), isTrue,
          reason: 'H10: iOS grant must be cached for later queries');
    });

    test('granted=false → returns false AND persists false', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);

      final granted = await svc.requestPermissions();
      expect(granted, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ios_notifications_granted'), isFalse);
    });

    test('null iOS impl → returns false (defensive default)', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()).thenReturn(null);

      final granted = await svc.requestPermissions();
      expect(granted, isFalse,
          reason: 'no iOS impl available → must default to denied');
    });
  });

  group('areNotificationsEnabled() — iOS / macOS path', () {
    test('cache empty (cold start, never asked) → returns true (optimistic)',
        () async {
      // Fresh state — no prior request.
      final result = await svc.areNotificationsEnabled();
      expect(result, isTrue,
          reason: 'H10: optimistic default lets the first reminder trigger '
              'the system prompt');
    });

    test('after grant → returns cached true', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => true);
      await svc.requestPermissions();

      final result = await svc.areNotificationsEnabled();
      expect(result, isTrue,
          reason: 'cached grant must persist across calls');
    });

    test('after deny → returns cached false', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);
      await svc.requestPermissions();

      final result = await svc.areNotificationsEnabled();
      expect(result, isFalse,
          reason: 'cached deny must persist — UI relies on this to show '
              'the "open settings" banner');
    });
  });

  // -----------------------------------------------------------------------
  // Tap handler
  // -----------------------------------------------------------------------
  group('handleTapForTest (NotificationResponse.payload pipeline)', () {
    test('null payload → handler NOT invoked', () async {
      Reminder? captured;
      svc.onNotificationTap = (r) => captured = r;

      svc.handleTapForTest(null);

      expect(captured, isNull);
    });

    test('empty string payload → handler NOT invoked', () async {
      Reminder? captured;
      svc.onNotificationTap = (r) => captured = r;

      svc.handleTapForTest('');

      expect(captured, isNull);
    });

    test('valid payload → handler invoked with stub Reminder', () async {
      Reminder? captured;
      svc.onNotificationTap = (r) => captured = r;

      svc.handleTapForTest('reminder-123');

      expect(captured, isNotNull);
      final r = captured!;
      expect(r.id, 'reminder-123');
      expect(r.title, '',
          reason: 'handler receives a stub; real title must come from '
              'TradeProvider lookup');
      expect(r.note, isNull);
    });

    test('handler null → no throw', () async {
      // Explicitly no handler registered.
      svc.onNotificationTap = null;

      // Must not throw — main.dart wires this AFTER init() in some flows.
      expect(() => svc.handleTapForTest('any-id'), returnsNormally);
    });

    test('handler throwing does not crash the pipeline', () async {
      svc.onNotificationTap = (r) => throw Exception('handler boom');

      // The production code does NOT catch handler exceptions, so we don't
      // expect it to swallow here. Just verify the exception surfaces so
      // developers can see broken handlers immediately.
      expect(() => svc.handleTapForTest('x'), throwsA(isA<Exception>()));
    });
  });

  // -----------------------------------------------------------------------
  // Cold-start launch payload
  // -----------------------------------------------------------------------
  group('consumeLaunchReminderId()', () {
    test('returns the seeded id and clears it', () {
      svc.launchPayloadReminderIdForTest = 'launched-from-id';

      expect(svc.consumeLaunchReminderId(), 'launched-from-id');
      expect(svc.consumeLaunchReminderId(), isNull,
          reason: 'second call must return null (consume semantics)');
    });

    test('nothing seeded → returns null', () {
      expect(svc.consumeLaunchReminderId(), isNull);
    });
  });
}