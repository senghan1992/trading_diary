import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/stock.dart';
import '../utils/hangul_util.dart';
import 'local_storage_service.dart';

/// Service responsible for managing stock data for search & auto-complete.
///
/// Features:
/// 1. Bundled offline default stock data in `assets/data/stocks_default.json`.
/// 2. Daily automatic background updates from remote URL (`AppConstants.stockListUrl`).
/// 3. Fast local search supporting code, name, and Korean initial consonants (chosung).
class StockDataService extends ChangeNotifier {
  StockDataService._() : _client = null, _overrideUrl = null;

  static StockDataService _instance = StockDataService._();
  static StockDataService get instance => _instance;

  @visibleForTesting
  static void setInstanceForTesting(StockDataService testInstance) {
    _instance = testInstance;
  }

  /// Seam for unit tests to inject custom HTTP client and URL.
  @visibleForTesting
  factory StockDataService.forTest({
    required http.Client client,
    String? url,
  }) {
    return StockDataService._internal(client, url);
  }

  StockDataService._internal(this._client, this._overrideUrl);

  final http.Client? _client;
  final String? _overrideUrl;

  List<StockItem> _stocks = [];
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Current cached stocks in memory.
  List<StockItem> get stocks => List.unmodifiable(_stocks);

  /// Whether stock data has finished its initial load.
  bool get isInitialized => _isInitialized;

  /// Whether a remote sync is currently in flight.
  bool get isSyncing => _isSyncing;

  /// Last successful sync timestamp.
  DateTime? get lastSyncTime => _lastSyncTime ?? LocalStorageService.getAllStocksUpdatedAt();

  /// Database version for bundled stock data. Bumped to 2026091002 (KOSPI 2,481 + KOSDAQ 1,823 + NASDAQ 5,593 = 9,897).
  static const int kStockDataVersion = 2026091002;

  /// Sync interval (24 hours).
  static const Duration syncInterval = Duration(hours: 24);

  /// HTTP timeout for downloading latest stock list.
  static const Duration _fetchTimeout = Duration(seconds: 5);

  /// Initializes stock data: loads from cache or bundled asset, then checks
  /// if a daily background sync is needed.
  /// Automatically migrates outdated/incomplete local cache to the latest full database.
  Future<void> init() async {
    if (_isInitialized) return;

    final cachedVersion = LocalStorageService.getAllStocksVersion();
    final cached = LocalStorageService.getAllStocks();

    // If cache is empty, outdated, or contains significantly fewer stocks than
    // the full bundled database (~9800+), reload from bundle immediately.
    if (cached == null ||
        cached.isEmpty ||
        cachedVersion < kStockDataVersion ||
        cached.length < 9000) {
      debugPrint('StockDataService: upgrading local cache to bundle v$kStockDataVersion');
      await _loadFromBundle();
    } else {
      _stocks = cached;
      _lastSyncTime = LocalStorageService.getAllStocksUpdatedAt();
    }

    _isInitialized = true;
    notifyListeners();

    // Trigger daily background sync if needed (non-blocking)
    _checkDailySync();
  }

  /// Loads bundled stocks from assets/data/stocks_default.json.
  Future<void> _loadFromBundle() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/stocks_default.json',
      );
      final list = jsonDecode(jsonString) as List;
      _stocks = list
          .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: true);

      // Save full bundled data to local cache with latest version
      await LocalStorageService.saveAllStocks(_stocks, version: kStockDataVersion);
      _lastSyncTime = DateTime.now();
      debugPrint('StockDataService: successfully loaded ${_stocks.length} bundled stocks');
    } catch (e) {
      debugPrint('StockDataService: failed to load bundled stocks: $e');
    }
  }

  /// Checks if 24 hours have passed since last sync and fires background sync.
  void _checkDailySync() {
    final lastSync = lastSyncTime;
    final now = DateTime.now();

    if (lastSync == null || now.difference(lastSync) >= syncInterval) {
      // Fire-and-forget background sync
      unawaited(syncLatestStocks());
    }
  }

  /// Fetches latest stocks from remote URL and updates local cache.
  /// When forced (e.g. from Settings), falls back to reloading the full
  /// bundled database if remote is unavailable.
  Future<bool> syncLatestStocks({bool force = false}) async {
    if (_isSyncing) return false;

    final url = _overrideUrl ?? AppConstants.stockListUrl;
    final isRemoteAvailable = url.isNotEmpty && !url.startsWith('https://example.com');

    if (!isRemoteAvailable) {
      if (force) {
        // Fall back to reloading the latest bundled database
        await _loadFromBundle();
        notifyListeners();
        return true;
      }
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(_fetchTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          'StockDataService: sync returned HTTP ${response.statusCode}',
        );
        return false;
      }

      String rawString;
      try {
        rawString = utf8.decode(response.bodyBytes);
      } catch (_) {
        rawString = response.body;
      }

      final body = jsonDecode(rawString);
      if (body is! List) {
        debugPrint('StockDataService: sync payload is not a JSON list');
        return false;
      }

      final newStocks = <StockItem>[];
      for (final item in body) {
        if (item is Map<String, dynamic>) {
          newStocks.add(StockItem.fromJson(item));
        }
      }

      if (newStocks.isNotEmpty) {
        _stocks = newStocks;
        _lastSyncTime = DateTime.now();
        await LocalStorageService.saveAllStocks(_stocks);
        debugPrint(
          'StockDataService: successfully synced ${_stocks.length} stocks',
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('StockDataService: sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Searches stocks matching [query].
  ///
  /// Matches against:
  /// - Stock code (exact, prefix, contains)
  /// - Stock name (exact, prefix, contains)
  /// - Korean initial consonants (chosung, e.g. "ㅅㅅ" -> "삼성전자")
  ///
  /// Results are sorted with exact/prefix matches first, up to [limit] results.
  List<StockItem> search(
    String query, {
    MarketType? filterMarket,
    int limit = 20,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final pool = filterMarket == null
        ? _stocks
        : _stocks.where((s) => s.market == filterMarket);

    final matches = <StockItem>[];
    for (final stock in pool) {
      if (stock.matches(q)) {
        matches.add(stock);
      }
    }

    final qDec = HangulUtil.decompose(q);

    // Sort by relevance
    matches.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aCode = a.code.toLowerCase();
      final bCode = b.code.toLowerCase();

      // 1. Exact name match
      if (aName == q && bName != q) return -1;
      if (bName == q && aName != q) return 1;

      // 2. Exact code match
      if (aCode == q && bCode != q) return -1;
      if (bCode == q && aCode != q) return 1;

      // 3. Name starts with query
      final aStarts = aName.startsWith(q);
      final bStarts = bName.startsWith(q);
      if (aStarts && !bStarts) return -1;
      if (bStarts && !aStarts) return 1;

      // 4. Decomposed Jamo prefix match (e.g. '올' -> '올릭스')
      final aDecStarts = a.decomposed.startsWith(qDec);
      final bDecStarts = b.decomposed.startsWith(qDec);
      if (aDecStarts && !bDecStarts) return -1;
      if (bDecStarts && !aDecStarts) return 1;

      // 5. Code starts with query
      final aCodeStarts = aCode.startsWith(q);
      final bCodeStarts = bCode.startsWith(q);
      if (aCodeStarts && !bCodeStarts) return -1;
      if (bCodeStarts && !aCodeStarts) return 1;

      // 6. Chosung starts with query
      final aChoStarts = a.chosung.startsWith(q);
      final bChoStarts = b.chosung.startsWith(q);
      if (aChoStarts && !bChoStarts) return -1;
      if (bChoStarts && !aChoStarts) return 1;

      // 7. Shorter name preferred
      return a.name.length.compareTo(b.name.length);
    });

    if (matches.length > limit) {
      return matches.sublist(0, limit);
    }
    return matches;
  }
}
