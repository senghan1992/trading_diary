import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/trade_entry.dart';

/// Bridge for taps on a delivered notification. Implemented in main.dart
/// to switch tabs / navigate. Set via [NotificationService.onNotificationTap].
typedef NotificationTapHandler = void Function(Reminder reminder);

/// Singleton wrapping the flutter_local_notifications plugin.
///
/// Responsibilities:
///   * Initialize the plugin and timezone DB at app start.
///   * Request OS permissions (Android 13+ POST_NOTIFICATIONS, iOS, exact alarm).
///   * Schedule / cancel / re-sync Reminder entities to the OS scheduler.
///   * Re-schedule all pending reminders on app launch (covers device reboot,
///     app reinstall, and clear-data scenarios).
///   * Surface tap events via [onNotificationTap] so the app can navigate.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _androidChannelId = 'trading_diary_reminders';
  static const String _androidChannelName = '매매 알림';
  static const String _androidChannelDescription =
      '거래 일지에서 설정한 리마인더 알림 채널';

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _launchPayloadReminderId;

  /// H10: iOS notification permission has no queryable API, so we persist
  /// the answer we got from [requestPermissions] so subsequent
  /// [areNotificationsEnabled] calls can return a truthful value rather
  /// than always guessing "true".
  ///
  /// True = granted. False = denied. Null = the user has never been asked
  /// yet (optimistically report true on iOS so the first reminder triggers
  /// the system prompt).
  bool? _iosNotifGrantedCache;
  SharedPreferences? _prefs;

  static const String _kIosNotifGrantedKey = 'ios_notifications_granted';

  /// Set this from main.dart so taps can navigate (e.g. switch to Journal tab).
  NotificationTapHandler? onNotificationTap;

  /// True after [init] has completed successfully.
  bool get isInitialized => _initialized;

  /// Initialize the plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;

    // H10: restore the cached iOS notification choice from the previous run
    // so [areNotificationsEnabled] returns accurate data on cold-start.
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        if (_prefs!.containsKey(_kIosNotifGrantedKey)) {
          _iosNotifGrantedCache =
              _prefs!.getBool(_kIosNotifGrantedKey) ?? false;
        }
      }
    } catch (e) {
      debugPrint('NotificationService: prefs load failed (continuing): $e');
    }

    tz_data.initializeTimeZones();
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone));
    } catch (e) {
      debugPrint('NotificationService: timezone detection failed, falling back: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // We request permissions explicitly via [requestPermissions].
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // If the app was launched by tapping a notification (cold start),
    // remember the payload so the app can act on it once UI is ready.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      _launchPayloadReminderId =
          launchDetails.notificationResponse?.payload;
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _createAndroidChannel();
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannel() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidImpl?.createNotificationChannel(channel);
  }

  /// Returns the launch reminder id (set when the app was cold-started by a
  /// notification tap) and clears it. Call once after the navigator is ready.
  String? consumeLaunchReminderId() {
    final id = _launchPayloadReminderId;
    _launchPayloadReminderId = null;
    return id;
  }

  /// Test-only: reset the singleton's mutable state between tests.
  ///
  /// Pass [plugin] to inject a mock implementation. Pass [initialized] = true
  /// when the test has already arranged the plugin state and wants to skip
  /// [init] (which would otherwise hit platform channels for the timezone
  /// and the plugin itself).
  @visibleForTesting
  void resetForTest({
    FlutterLocalNotificationsPlugin? plugin,
    bool initialized = false,
  }) {
    _plugin = plugin ?? FlutterLocalNotificationsPlugin();
    _initialized = initialized;
    _launchPayloadReminderId = null;
    _iosNotifGrantedCache = null;
    _prefs = null;
    onNotificationTap = null;
  }

  /// Test-only: expose [_idFor] so unit tests can verify hash stability
  /// and the non-negative guarantee without exercising the full schedule path.
  @visibleForTesting
  int idForTest(String reminderId) => _idFor(reminderId);

  /// Test-only: seed the launch-payload id so [consumeLaunchReminderId] can
  /// be exercised without faking the full plugin [init] flow.
  @visibleForTesting
  set launchPayloadReminderIdForTest(String? id) => _launchPayloadReminderId = id;

  /// Asks the OS for notification permissions. Idempotent. Returns the granted
  /// state (true/false) or null when the platform has no permission concept
  /// (older Android, web).
  Future<bool?> requestPermissions() async {
    if (!_initialized) await init();

    if (!kIsWeb && Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      // On Android 14+ exact alarms also need explicit permission.
      // We declared USE_EXACT_ALARM, so this usually auto-grants, but ask anyway
      // to cover devices that fell back to SCHEDULE_EXACT_ALARM only.
      await androidImpl?.requestExactAlarmsPermission();
      return granted;
    }

    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
      // H10: persist iOS choice so subsequent areNotificationsEnabled queries
      // return the truthful cached value (iOS exposes no query API).
      try {
        _prefs ??= await SharedPreferences.getInstance();
        await _prefs!.setBool(_kIosNotifGrantedKey, granted);
        _iosNotifGrantedCache = granted;
      } catch (e) {
        debugPrint('NotificationService: prefs persist failed: $e');
      }
      return granted;
    }

    return true;
  }

  /// Returns the current OS-level "are notifications enabled" state.
  Future<bool?> areNotificationsEnabled() async {
    if (!_initialized) await init();
    if (!kIsWeb && Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.areNotificationsEnabled();
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      // H10: cached value from the previous requestPermission() call.
      // Until the user has actually been asked, we optimistically return
      // true (the first reminder will trigger the system prompt and the
      // result will be cached for next time).
      return _iosNotifGrantedCache ?? true;
    }
    return true;
  }

  /// Schedules a single [reminder]. No-op if it has already passed.
  /// Returns true on success.
  Future<bool> schedule(Reminder reminder) async {
    if (!_initialized) await init();
    if (reminder.remindAt.isBefore(DateTime.now())) {
      // Don't schedule reminders in the past.
      return false;
    }

    final scheduled = tz.TZDateTime.from(reminder.remindAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: _idFor(reminder.id),
        title: reminder.title,
        body: reminder.note?.isNotEmpty == true ? reminder.note : null,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.id,
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService.schedule failed for ${reminder.id}: $e');
      return false;
    }
  }

  /// Cancels the OS-scheduled notification for [reminderId]. Safe to call for
  /// ids that were never scheduled.
  Future<void> cancel(String reminderId) async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(id: _idFor(reminderId));
    } catch (e) {
      debugPrint('NotificationService.cancel failed for $reminderId: $e');
    }
  }

  /// Cancels every scheduled reminder this app owns.
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll failed: $e');
    }
  }

  /// Re-syncs the OS scheduler to match the given list of reminders.
  ///
  /// Strategy: cancel all, then schedule every reminder that is still in the
  /// future and unread. This is simpler and more correct than diffing, and
  /// it's what the OS already does efficiently (a few hundred operations).
  ///
  /// Call this on app launch (after a fresh boot or app update) and whenever
  /// the global notifications toggle is turned back on.
  Future<int> rescheduleAll(List<Reminder> reminders) async {
    if (!_initialized) await init();
    await cancelAll();

    final now = DateTime.now();
    int scheduled = 0;
    for (final r in reminders) {
      if (r.isRead) continue;
      if (r.remindAt.isBefore(now)) continue;
      final ok = await schedule(r);
      if (ok) scheduled += 1;
    }
    return scheduled;
  }

  /// Maps a string Reminder.id to a stable 32-bit int (the plugin requires int).
  int _idFor(String reminderId) {
    // Strip sign bit so we always get a non-negative int that survives
    // round-tripping through Java/Kotlin AlarmManager.
    return reminderId.hashCode & 0x7fffffff;
  }

  void _onTap(NotificationResponse response) {
    _handleTap(response.payload);
  }

  /// Internal: validate a notification payload and dispatch it to
  /// [onNotificationTap] if one is registered. Extracted from [_onTap] so
  /// unit tests can drive the same code path without spinning up a full
  /// plugin + notification response.
  void _handleTap(String? payload) {
    final reminderId = payload;
    if (reminderId == null || reminderId.isEmpty) return;
    final handler = onNotificationTap;
    if (handler == null) return;
    // Reconstruct a stub Reminder with the id; handlers that need full
    // details can re-read from TradeProvider.
    handler(Reminder(
      id: reminderId,
      title: '',
      note: null,
      remindAt: DateTime.now(),
    ));
  }

  /// Test-only: drive the tap handler with a raw payload string. Mirrors
  /// what the plugin invokes via [NotificationResponse.payload].
  @visibleForTesting
  void handleTapForTest(String? payload) => _handleTap(payload);
}
