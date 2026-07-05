import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'local_storage_service.dart';

/// Centralized ad management for AdMob.
///
/// In production, replace the test ad unit IDs with the real ones from the
/// AdMob console. The IDs below are Google's official sample IDs and will
/// display placeholder ads - they will not earn revenue and using them in
/// release builds is a policy violation.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // Google sample ad unit IDs - safe for development only. Using these in
  // production is an AdMob policy violation and will be rejected at store
  // review time. Override at build time with --dart-define, e.g.:
  //
  //   flutter build apk --release \
  //     --dart-define=ADMOB_BANNER_ID=ca-app-pub-YOUR_ACCOUNT/123 \
  //     --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-YOUR_ACCOUNT/456 \
  //     --dart-define=ADMOB_NATIVE_ID=ca-app-pub-YOUR_ACCOUNT/789
  //
  // Defaults below are the official Google sample IDs and are correct for
  // dev / debug builds.
  static const String bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String interstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const String nativeAdUnitId = String.fromEnvironment(
    'ADMOB_NATIVE_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2247696110',
  );

  InterstitialAd? _interstitialAd;
  bool _initialized = false;

  /// Number of journal entries saved since the last interstitial impression.
  /// Resets each time an ad is shown (or [dispose] is called).
  int _entriesSinceLastAd = 0;

  /// Show the pre-loaded interstitial on every Nth entry save. Tune this
  /// to balance monetization with user experience.
  static const int _showAdEveryNEntries = 5;

  /// Initializes the Mobile Ads SDK and requests ATT permission on iOS.
  /// Safe to call multiple times - subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Restore the persisted interstitial-cadence counter so cadence
    // survives app kills. Relies on LocalStorageService.init() having run
    // first (see main.dart).
    _entriesSinceLastAd = LocalStorageService.getAdInterstitialCounter();

    await MobileAds.instance.initialize();

    if (!kIsWeb && Platform.isIOS) {
      // Show the system tracking prompt. The Info.plist key
      // NSUserTrackingUsageDescription is required for this to display.
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: interstitial load failed - $error');
          _interstitialAd = null;
          // Retry once after a delay so a transient failure doesn't kill
          // future impressions for the session.
          Future<void>.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// Shows the pre-loaded interstitial if one is ready, then immediately
  /// starts loading the next one. Safe to call from anywhere - the ad will
  /// be presented over the current screen.
  void showInterstitialIfReady() {
    final ad = _interstitialAd;
    if (ad == null) return;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdService: interstitial show failed - $error');
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// Records that a journal entry was saved. Shows the pre-loaded interstitial
  /// on every Nth call ([_showAdEveryNEntries]). Counter is persisted to
  /// disk after each change so cadence survives app kills.
  ///
  /// Use this from the trade-entry save flow instead of calling
  /// [showInterstitialIfReady] directly.
  void onEntrySaved() {
    _entriesSinceLastAd++;
    _persistCounter();
    if (_entriesSinceLastAd >= _showAdEveryNEntries) {
      _entriesSinceLastAd = 0;
      _persistCounter();
      showInterstitialIfReady();
    }
  }

  /// Fire-and-forget write of [_entriesSinceLastAd] to disk. The write is
  /// cheap and serialized by Hive; lateness by a few ms is acceptable here
  /// because the counter is a soft pacing signal, not a correctness invariant.
  void _persistCounter() {
    // ignore: discarded_futures
    LocalStorageService.setAdInterstitialCounter(_entriesSinceLastAd);
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _initialized = false;
    _entriesSinceLastAd = 0;
  }
}