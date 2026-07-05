import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// What the app should do relative to the server-reported configuration.
enum UpdateStatus {
  /// Current version meets or exceeds the server's minimum AND the server
  /// has not flagged a force update. Show the app normally.
  upToDate,

  /// A newer version exists but the user can keep using the current build.
  /// Surface an optional ("Update available") dialog.
  optional,

  /// The installed version is below the server's minimum OR the server has
  /// explicitly flagged a force update. The app must block until updated.
  required,
}

/// Server-driven update configuration.
///
/// Shape mirrors the JSON hosted at [AppConstants.appConfigUrl]. All fields
/// except [latestVersion] and [minimumVersion] are optional so a partial
/// rollout (only mandatory fields) is supported during initial deployment.
@immutable
class UpdateConfig {
  const UpdateConfig({
    required this.latestVersion,
    required this.minimumVersion,
    required this.forceUpdate,
    this.messageKo,
    this.messageEn,
    this.storeUrlIos,
    this.storeUrlAndroid,
  });

  final String latestVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final String? messageKo;
  final String? messageEn;

  /// Optional explicit store URLs. When null, [UpdateService.openStore] falls
  /// back to the configured App Store ID / Play Store package name.
  final String? storeUrlIos;
  final String? storeUrlAndroid;

  /// Picks the message matching the current locale, falling back to the
  /// English one and then to a sensible default if neither is provided.
  String messageFor(String? languageCode) {
    final ko = messageKo;
    final en = messageEn;
    if (languageCode == 'ko' && ko != null && ko.isNotEmpty) return ko;
    if (en != null && en.isNotEmpty) return en;
    if (ko != null && ko.isNotEmpty) return ko;
    return '';
  }

  factory UpdateConfig.fromJson(Map<String, dynamic> json) {
    return UpdateConfig(
      latestVersion: (json['latest_version'] as String?) ?? '0.0.0',
      minimumVersion: (json['minimum_version'] as String?) ?? '0.0.0',
      forceUpdate: (json['force_update'] as bool?) ?? false,
      messageKo: json['update_message_ko'] as String?,
      messageEn: json['update_message_en'] as String?,
      storeUrlIos: json['store_url_ios'] as String?,
      storeUrlAndroid: json['store_url_android'] as String?,
    );
  }
}

/// Loads the server-driven update configuration and decides whether the
/// current app build needs an update (optional or required).
///
/// Singleton because the check is cheap to repeat and we don't want to
/// re-fetch from the network on every screen transition.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  UpdateConfig? _cached;
  DateTime? _cachedAt;

  /// Caches the fetched config for this window to avoid hammering the
  /// hosting endpoint on every cold start. Soft cap; even if the fetch
  /// fails, we don't retry until it expires.
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Hard network timeout for the config fetch. Kept tight so a slow CDN
  /// doesn't make users stare at a splash screen.
  static const Duration _fetchTimeout = Duration(seconds: 5);

  /// Returns the currently installed app version as a semver string,
  /// e.g. "1.0.0". The "+N" build suffix from `pubspec.yaml` is dropped.
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version.split('+').first;
  }

  /// Returns the cached config if it's still fresh, otherwise re-fetches.
  /// On any error (network, parse, missing fields) returns null so the
  /// caller can fall through to a normal app start.
  ///
  /// When [AppConstants.appConfigUrl] still points at the example.com
  /// placeholder, returns null without making a network call - this is how
  /// local development avoids trying to fetch a non-existent config.
  Future<UpdateConfig?> getConfig({bool forceRefresh = false}) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return cached;
    }

    final url = AppConstants.appConfigUrl;
    if (url.isEmpty || url.startsWith('https://example.com')) {
      // Host hasn't been configured yet. Don't try to fetch the placeholder.
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(_fetchTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          'UpdateService: config fetch returned ${response.statusCode}',
        );
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        debugPrint('UpdateService: config payload is not a JSON object');
        return null;
      }
      final config = UpdateConfig.fromJson(body);
      _cached = config;
      _cachedAt = DateTime.now();
      return config;
    } on TimeoutException {
      debugPrint('UpdateService: config fetch timed out');
      return null;
    } catch (e) {
      debugPrint('UpdateService: config fetch error - $e');
      return null;
    }
  }

  /// Decides which [UpdateStatus] applies to the current build relative to
  /// the server-provided [config].
  UpdateStatus checkStatus(UpdateConfig config, String currentVersion) {
    final cmpMin = _compareVersions(currentVersion, config.minimumVersion);
    if (cmpMin < 0) return UpdateStatus.required;
    if (config.forceUpdate) return UpdateStatus.required;
    final cmpLatest =
        _compareVersions(currentVersion, config.latestVersion);
    if (cmpLatest < 0) return UpdateStatus.optional;
    return UpdateStatus.upToDate;
  }

  /// Opens the appropriate app store page for the current platform.
  ///
  /// Resolution order for the URL:
  ///   1. [overrideUrl] if supplied (caller-provided, e.g. a force-screen
  ///      uses the config's per-platform URL).
  ///   2. [UpdateConfig.storeUrlIos] / [UpdateConfig.storeUrlAndroid] from
  ///      the most recently fetched config, if any.
  ///   3. Platform default derived from the dart-define IDs.
  ///
  /// Returns false when no URL is resolvable or the platform can't launch
  /// it - callers should treat that as a hard error and log it.
  Future<bool> openStore({
    String? overrideUrl,
    UpdateConfig? config,
  }) async {
    final url = overrideUrl ?? _resolveStoreUrl(config);
    if (url == null || url.isEmpty) {
      debugPrint('UpdateService.openStore: no URL resolvable');
      return false;
    }

    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      debugPrint('UpdateService.openStore: cannot launch $url');
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _resolveStoreUrl(UpdateConfig? config) {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      if (config?.storeUrlIos != null && config!.storeUrlIos!.isNotEmpty) {
        return config.storeUrlIos;
      }
      final id = AppConstants.iosAppStoreId;
      if (id.isEmpty) return null;
      return 'https://apps.apple.com/app/id$id';
    }
    if (Platform.isAndroid) {
      if (config?.storeUrlAndroid != null &&
          config!.storeUrlAndroid!.isNotEmpty) {
        return config.storeUrlAndroid;
      }
      final pkg = AppConstants.androidPackageName;
      if (pkg.isEmpty) return null;
      return 'https://play.google.com/store/apps/details?id=$pkg';
    }
    return null;
  }

  /// Semver-style compare: "1.2.3" vs "1.10.0". Returns negative if [a] is
  /// older than [b], positive if newer, 0 if equal. Missing components are
  /// treated as 0, so "1.0" equals "1.0.0".
  static int _compareVersions(String a, String b) {
    final pa = a.split('+').first.split('.').map(int.tryParse).toList();
    final pb = b.split('+').first.split('.').map(int.tryParse).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? (pa[i] ?? 0) : 0;
      final nb = i < pb.length ? (pb[i] ?? 0) : 0;
      if (na != nb) return na - nb;
    }
    return 0;
  }
}