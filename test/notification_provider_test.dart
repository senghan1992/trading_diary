// Unit tests for NotificationProvider.
//
// NotificationProvider is the user-facing toggle that persists to
// SharedPreferences and drives NotificationService.rescheduleAll /
// cancelAll. The plugin is mocked at the NotificationService layer via
// the @visibleForTesting resetForTest seam.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/providers/notification_provider.dart';
import 'package:trading_diary/services/notification_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockIOS extends Mock implements IOSFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin mockPlugin;
  late _MockIOS mockIOS;
  late NotificationProvider provider;

  setUpAll(() {
    tz_data.initializeTimeZones();
    setLocalLocation(getLocation('UTC'));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(TZDateTime.now(getLocation('UTC')));
    registerFallbackValue(AndroidScheduleMode.exact);
  });

  void stubZonedSchedule() {
    when(() => mockPlugin.zonedSchedule(
      id: any(named: 'id'),
      title: any(named: 'title'),
      body: any(named: 'body'),
      scheduledDate: any(named: 'scheduledDate'),
      notificationDetails: any(named: 'notificationDetails'),
      androidScheduleMode: any(named: 'androidScheduleMode'),
      payload: any(named: 'payload'),
    )).thenAnswer((_) async {});
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPlugin = _MockPlugin();
    mockIOS = _MockIOS();
    when(() => mockPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()).thenReturn(mockIOS);
    // Default iOS impl answers `true` — tests that want `false` override.
    when(() => mockIOS.requestPermissions(
      alert: any(named: 'alert'),
      badge: any(named: 'badge'),
      sound: any(named: 'sound'),
    )).thenAnswer((_) async => true);
    when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
    stubZonedSchedule();

    // Reset the singleton's state, then construct the provider so its
    // _bootstrap() reads the (now mocked) plugin.
    NotificationService.instance.resetForTest(
      plugin: mockPlugin,
      initialized: true,
    );
    provider = NotificationProvider();
    // _bootstrap runs async in the constructor — drain the microtask queue
    // so load preference / refresh permission have completed.
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> drainMicrotasks() => Future<void>.delayed(Duration.zero);

  // -----------------------------------------------------------------------
  // Default / persisted state
  // -----------------------------------------------------------------------
  group('default state', () {
    test('no prefs → enabled=true (default-on UX)', () {
      expect(provider.isEnabled, isTrue);
    });

    test('willFire true when both toggle and OS grant are true', () {
      expect(provider.willFire, isTrue);
    });

    test('isLoaded=true after bootstrap', () {
      expect(provider.isLoaded, isTrue);
    });
  });

  group('persisted state', () {
    test('saved "true" → isEnabled=true on next launch', () async {
      SharedPreferences.setMockInitialValues({'app_notifications_enabled': 'true'});
      final p = NotificationProvider();
      await drainMicrotasks();
      expect(p.isEnabled, isTrue);
    });

    test('saved "false" → isEnabled=false on next launch', () async {
      SharedPreferences.setMockInitialValues({'app_notifications_enabled': 'false'});
      final p = NotificationProvider();
      await drainMicrotasks();
      expect(p.isEnabled, isFalse,
          reason: 'user must remain opted-out after a restart');
    });
  });

  // -----------------------------------------------------------------------
  // setEnabled() — toggle wiring
  // -----------------------------------------------------------------------
  group('setEnabled()', () {
    final futureReminders = [
      Reminder(
        id: 'r1',
        title: 'follow up',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      Reminder(
        id: 'r2',
        title: 'check chart',
        remindAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    ];

    test('false → cancelAll called (existing alarms wiped)', () async {
      await provider.setEnabled(false, reminders: futureReminders);

      verify(() => mockPlugin.cancelAll()).called(1);
    });

    test('false → does NOT schedule anything', () async {
      await provider.setEnabled(false, reminders: futureReminders);

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

    test('true → cancelAll called first, then zonedSchedule per future reminder',
        () async {
      // Pre-condition: provider starts as enabled=true.
      expect(provider.isEnabled, isTrue);

      // Flip OFF then ON to drive both code paths.
      await provider.setEnabled(false, reminders: futureReminders);
      await provider.setEnabled(true, reminders: futureReminders);

      // cancelAll twice (one per flip), and 2 schedules for the 2 future
      // reminders.
      verify(() => mockPlugin.cancelAll()).called(2);
      verify(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: any(named: 'payload'),
          )).called(2);
    });

    test('same value as current → no plugin calls (idempotency)', () async {
      // Provider is enabled=true by default. setEnabled(true) again
      // must NOT touch the plugin.
      await provider.setEnabled(true, reminders: futureReminders);

      verifyNever(() => mockPlugin.cancelAll());
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

    test('persistence: setEnabled(false) writes "false" to prefs', () async {
      await provider.setEnabled(false, reminders: []);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_notifications_enabled'), 'false');
    });

    test('persistence: setEnabled(true) writes "true" to prefs', () async {
      // Flip OFF first so the next call has a real state change.
      await provider.setEnabled(false, reminders: []);
      await provider.setEnabled(true, reminders: []);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_notifications_enabled'), 'true');
    });
  });

  // -----------------------------------------------------------------------
  // requestPermission() — gated reschedule
  // -----------------------------------------------------------------------
  group('requestPermission()', () {
    final reminders = [
      Reminder(
        id: 'perm-r',
        title: 'after grant',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    ];

    test('granted=true → isOsGranted=true, returns true', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => true);

      final ok = await provider.requestPermission(reminders: reminders);
      expect(ok, isTrue);
      expect(provider.isOsGranted, isTrue);
    });

    test('granted=true + toggle on → rescheduleAll called', () async {
      // Provider starts enabled=true.
      expect(provider.isEnabled, isTrue);

      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => true);

      await provider.requestPermission(reminders: reminders);

      // The reschedule path cancels everything then re-schedules the
      // single future reminder.
      verify(() => mockPlugin.cancelAll()).called(1);
      verify(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('granted=true + toggle OFF → no reschedule (toggle is off)',
        () async {
      await provider.setEnabled(false, reminders: []);
      // Clear the cancelAll call from the setEnabled above so we can
      // distinguish the requestPermission() call.
      clearInteractions(mockPlugin);

      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => true);

      await provider.requestPermission(reminders: reminders);

      // Should NOT reschedule because the user has the global toggle off.
      verifyNever(() => mockPlugin.cancelAll());
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

    test('granted=false → isOsGranted=false, returns false', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);

      final ok = await provider.requestPermission(reminders: reminders);
      expect(ok, isFalse);
      expect(provider.isOsGranted, isFalse);
    });

    test('granted=false → rescheduleAll NOT called', () async {
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);

      await provider.requestPermission(reminders: reminders);

      verifyNever(() => mockPlugin.cancelAll());
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

    test('willFire mirrors enabled AND osGranted', () async {
      // Initially both true → willFire true.
      expect(provider.willFire, isTrue);

      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);

      await provider.requestPermission(reminders: []);

      expect(provider.willFire, isFalse,
          reason: 'OS deny must flip willFire even though toggle is on — '
              'this is what the settings screen banner reacts to');
    });
  });

  // -----------------------------------------------------------------------
  // refreshOsPermission()
  // -----------------------------------------------------------------------
  group('refreshOsPermission()', () {
    test('reflects the in-memory cache populated by requestPermission',
        () async {
      // Initially the cache is empty → optimistic true.
      expect(provider.isOsGranted, isTrue);

      // Simulate the user denying the system prompt — cache becomes false.
      when(() => mockIOS.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      )).thenAnswer((_) async => false);
      await provider.requestPermission(reminders: []);
      expect(provider.isOsGranted, isFalse);

      // refreshOsPermission must observe the same cached deny — this is
      // what the settings screen relies on when it remounts after the
      // user returns from the system settings page.
      await provider.refreshOsPermission();
      expect(provider.isOsGranted, isFalse,
          reason: 'refresh re-queries the service cache, which is false');
    });

    test('notifies listeners after refresh (always — production emits '
        'unconditionally for the "returned from settings" remount path)',
        () async {
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.refreshOsPermission();
      expect(notified, 1,
          reason: 'refresh always calls notifyListeners, even when state '
              'is unchanged — the settings screen relies on this to refresh '
              'after the user returns from the system settings page');
    });
  });
}