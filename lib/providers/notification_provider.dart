import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trade_entry.dart';
import '../services/notification_service.dart';

/// App-level state for the "Notifications" feature.
///
/// Owns:
///   * The user-facing global toggle (persisted to SharedPreferences).
///   * A cached view of the OS permission state (refreshed on demand).
///   * The wiring between the toggle and [NotificationService]:
///       ON  → reschedule all known reminders
///       OFF → cancel every scheduled notification
class NotificationProvider extends ChangeNotifier {
  static const String _enabledKey = 'app_notifications_enabled';
  static const String _defaultEnabled = 'true';

  bool _enabled = true;
  bool _osGranted = true;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isEnabled => _enabled;
  bool get isOsGranted => _osGranted;

  /// True only when both the user toggle is on AND the OS has granted permission.
  /// UI helpers can use this to decide whether to show a "notifications won't fire"
  /// banner.
  bool get willFire => _enabled && _osGranted;

  NotificationProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadPreference();
    await refreshOsPermission();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getString(_enabledKey) == null
        ? true
        : prefs.getString(_enabledKey) == _defaultEnabled;
    _loaded = true;
    notifyListeners();
  }

  /// Re-queries the OS for current permission state. Safe to call any time
  /// (e.g. when the settings screen mounts, or after returning from system
  /// settings).
  Future<void> refreshOsPermission() async {
    final granted = await NotificationService.instance.areNotificationsEnabled();
    _osGranted = granted ?? true;
    notifyListeners();
  }

  /// Toggles the global notifications switch. Persists, then syncs the OS
  /// scheduler to match.
  ///
  /// If [osGranted] is false, this still flips the user preference, but
  /// scheduling is skipped (the OS will refuse). Callers should surface a
  /// "open settings" CTA in that case.
  Future<void> setEnabled(bool value, {required List<Reminder> reminders}) async {
    if (_enabled == value) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enabledKey, value ? _defaultEnabled : 'false');
    notifyListeners();

    if (value) {
      // Re-hydrate the OS scheduler from the persisted reminders.
      await NotificationService.instance.rescheduleAll(reminders);
    } else {
      // Wipe every scheduled notification.
      await NotificationService.instance.cancelAll();
    }
  }

  /// Asks the OS for POST_NOTIFICATIONS (Android 13+) or iOS alert/badge/sound.
  /// On grant, also reschedules existing reminders if the toggle is on.
  Future<bool> requestPermission({required List<Reminder> reminders}) async {
    final granted = await NotificationService.instance.requestPermissions();
    _osGranted = granted ?? true;
    notifyListeners();
    if (_osGranted && _enabled) {
      await NotificationService.instance.rescheduleAll(reminders);
    }
    return _osGranted;
  }

  /// Opens the OS-level app settings so the user can manually grant the
  /// notification permission (required when the user has previously denied
  /// and there's no in-app re-prompt available).
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
