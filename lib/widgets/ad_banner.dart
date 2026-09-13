import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// A standard 320x50 banner ad. Renders nothing until the ad is loaded,
/// so the surrounding layout does not jump when the ad arrives.
///
/// When the initial load fails (e.g. SDK still warming up, transient
/// network error, ATT prompt in flight), the widget retries on a fixed
/// 30-second cadence so a banner eventually appears instead of leaving
/// the slot empty. Detailed error info is logged on each failure to make
/// diagnosing fill-rate issues in the wild much easier.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _disposed = false;

  /// Number of consecutive load attempts. Backs off the retry interval so
  /// we don't hammer the SDK when something is wrong upstream, while still
  /// recovering automatically when the blocker clears.
  int _attempt = 0;

  /// Active retry timer; cancelled whenever a load is started or the widget
  /// is disposed.
  Timer? _retryTimer;

  /// Base delay between retry attempts. Doubles per failure up to
  /// [maxRetryDelay] so a permanent failure (wrong ad unit ID, no fill)
  /// doesn't cost us CPU forever, but a transient one recovers fast.
  static const Duration _baseRetryDelay = Duration(seconds: 30);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Duration get _nextRetryDelay {
    // 30s, 60s, 120s, 240s, capped at 5 min. _attempt=0 means "first retry".
    final multiplier = 1 << _attempt.clamp(0, 4);
    final delay = _baseRetryDelay * multiplier;
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }

  void _loadAd() {
    _retryTimer?.cancel();
    _retryTimer = null;

    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _attempt = 0;
          });
          debugPrint('AdBanner: loaded (unit=${AdService.bannerAdUnitId})');
        },
        onAdFailedToLoad: (ad, error) {
          // Log every failure with full context so issues can be triaged
          // from logs alone: code/domain/message plus our attempt count.
          debugPrint(
            'AdBanner: load failed attempt=$_attempt '
            'code=${error.code} domain=${error.domain} message=${error.message}',
          );
          ad.dispose();
          if (_disposed) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          _scheduleRetry();
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final delay = _nextRetryDelay;
    _attempt++;
    debugPrint(
      'AdBanner: retrying in ${delay.inSeconds}s (next attempt=$_attempt)',
    );
    _retryTimer = Timer(delay, _loadAd);
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
