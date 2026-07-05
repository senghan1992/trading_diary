import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trade_entry.dart';
import '../models/favorite_folder.dart';
import '../models/stock.dart';

class LocalStorageService {
  static const _tradesBox = 'trades';
  static const _watchlistBox = 'watchlist';
  static const _notesBox = 'notes';
  static const _remindersBox = 'reminders';
  static const _foldersBox = 'folders';
  static const _marketCacheBox = 'market_cache';
  static const _prefsBox = 'prefs';
  static const _kAdInterstitialCounter = 'ad_interstitial_counter';

  /// M16: tracks per-box open failures so the rest of the app can probe
  /// state via [isBoxAvailable] instead of crashing on every operation
  /// when a single box is wedged (disk full, corrupted file, etc.).
  static final Set<String> _unavailableBoxes = <String>{};

  /// Public name → human-readable label map so settings UI can show
  /// the user which boxes failed to open without leaking internal keys.
  static const Map<String, String> _boxDisplayNames = {
    _tradesBox: 'Trade history',
    _watchlistBox: 'Watchlist',
    _notesBox: 'Analysis notes',
    _remindersBox: 'Reminders',
    _foldersBox: 'Folders',
    _marketCacheBox: 'Market data cache',
    _prefsBox: 'Preferences',
  };

  /// Returns true iff every required box is available.
  static bool get isHealthy => _unavailableBoxes.isEmpty;

  /// Returns the user-facing labels of any boxes that failed to open.
  /// Empty list means all boxes are available.
  static List<String> get unavailableBoxLabels => _unavailableBoxes
      .map((k) => _boxDisplayNames[k] ?? k)
      .toList(growable: false);

  /// Single-box probe. Returns true if the named box opened successfully.
  static bool isBoxAvailable(String boxName) => !_unavailableBoxes.contains(boxName);

  /// Centralised accessor used by every getter/setter below. Returns null
  /// when the box failed to open during [init] so callers can no-op instead
  /// of throwing [HiveError] on every disk read/write. This was previously a
  /// crash bug: a single corrupted box took the entire app down because the
  /// read paths bypassed the [_unavailableBoxes] tracker.
  static Box? _box(String name) {
    if (_unavailableBoxes.contains(name)) return null;
    try {
      return Hive.box(name);
    } catch (_) {
      // Box never opened (Hive throws if openBox was never called or failed).
      _unavailableBoxes.add(name);
      return null;
    }
  }

  /// Opens every box the app needs. Failures are isolated per-box: a single
  /// disk error doesn't prevent the rest of the app from working, and the
  /// failure mode is observable via [unavailableBoxLabels].
  static Future<void> init() async {
    await Hive.initFlutter();
    for (final name in const [
      _tradesBox,
      _watchlistBox,
      _notesBox,
      _remindersBox,
      _foldersBox,
      _marketCacheBox,
      _prefsBox,
    ]) {
      try {
        await Hive.openBox(name);
      } catch (e, st) {
        _unavailableBoxes.add(name);
        debugPrint('Hive.openBox("$name") failed: $e\n$st');
      }
    }
  }

  // Market Stock Cache
  static Future<void> saveMarketStocks(MarketType market, List<Map<String, dynamic>> stocks) async {
    final box = _box(_marketCacheBox);
    if (box == null) return;
    await box.put('stocks_${market.name}', jsonEncode(stocks));
    await box.put('stocks_${market.name}_updated', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getMarketStocks(MarketType market) {
    final box = _box(_marketCacheBox);
    if (box == null) return null;
    final data = box.get('stocks_${market.name}');
    if (data == null) return null;
    final list = jsonDecode(data) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static DateTime? getMarketStocksUpdatedAt(MarketType market) {
    final box = _box(_marketCacheBox);
    if (box == null) return null;
    final data = box.get('stocks_${market.name}_updated');
    if (data == null) return null;
    return DateTime.parse(data);
  }

  static Future<void> saveMarketIndices(List<Map<String, dynamic>> indices) async {
    final box = _box(_marketCacheBox);
    if (box == null) return;
    await box.put('indices', jsonEncode(indices));
    await box.put('indices_updated', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getMarketIndices() {
    final box = _box(_marketCacheBox);
    if (box == null) return null;
    final data = box.get('indices');
    if (data == null) return null;
    final list = jsonDecode(data) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static DateTime? getMarketIndicesUpdatedAt() {
    final box = _box(_marketCacheBox);
    if (box == null) return null;
    final data = box.get('indices_updated');
    if (data == null) return null;
    return DateTime.parse(data);
  }

  // Trades
  static Future<void> saveTrade(TradeEntry trade) async {
    final box = _box(_tradesBox);
    if (box == null) return;
    await box.put(trade.id, jsonEncode(_tradeToMap(trade)));
  }

  static List<TradeEntry> getTrades() {
    final box = _box(_tradesBox);
    if (box == null) return const <TradeEntry>[];
    return box.values.map((v) => _tradeFromMap(jsonDecode(v))).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  static Future<void> deleteTrade(String id) async {
    final box = _box(_tradesBox);
    if (box == null) return;
    await box.delete(id);
  }

  // Favorite Folders
  static Future<void> saveFolder(FavoriteFolder folder) async {
    final box = _box(_foldersBox);
    if (box == null) return;
    await box.put(folder.id, jsonEncode({
      'id': folder.id,
      'name': folder.name,
      'createdAt': folder.createdAt.toIso8601String(),
    }));
  }

  static List<FavoriteFolder> getFolders() {
    final box = _box(_foldersBox);
    if (box == null) return const <FavoriteFolder>[];
    return box.values.map((v) {
      final m = jsonDecode(v);
      return FavoriteFolder(
        id: m['id'],
        name: m['name'],
        createdAt: DateTime.parse(m['createdAt']),
      );
    }).toList();
  }

  static Future<void> deleteFolder(String id) async {
    final foldersBox = _box(_foldersBox);
    if (foldersBox != null) await foldersBox.delete(id);
    final box = _box(_watchlistBox);
    if (box == null) return;
    final keys = box.keys.toList();
    for (final key in keys) {
      final data = box.get(key);
      if (data != null) {
        final item = FavoriteItem.fromJson(jsonDecode(data));
        if (item.folderIds.contains(id)) {
          final newFolderIds = List<String>.from(item.folderIds)..remove(id);
          if (newFolderIds.isEmpty) {
            await box.delete(key);
          } else {
            await box.put(key, jsonEncode(FavoriteItem(
              symbol: item.symbol,
              folderIds: newFolderIds,
            ).toJson()));
          }
        }
      }
    }
  }

  static Future<void> addToFolder(String symbol, String folderId) async {
    final box = _box(_watchlistBox);
    if (box == null) return;
    if (box.containsKey(symbol)) {
      final item = FavoriteItem.fromJson(jsonDecode(box.get(symbol)));
      if (!item.folderIds.contains(folderId)) {
        await box.put(symbol, jsonEncode(FavoriteItem(
          symbol: item.symbol,
          folderIds: [...item.folderIds, folderId],
        ).toJson()));
      }
    } else {
      await box.put(symbol, jsonEncode(FavoriteItem(
        symbol: symbol,
        folderIds: [folderId],
      ).toJson()));
    }
  }

  static Future<void> removeFromFolder(String symbol, String folderId) async {
    final box = _box(_watchlistBox);
    if (box == null) return;
    if (box.containsKey(symbol)) {
      final item = FavoriteItem.fromJson(jsonDecode(box.get(symbol)));
      final newFolderIds = List<String>.from(item.folderIds)..remove(folderId);
      if (newFolderIds.isEmpty) {
        await box.delete(symbol);
      } else {
        await box.put(symbol, jsonEncode(FavoriteItem(
          symbol: item.symbol,
          folderIds: newFolderIds,
        ).toJson()));
      }
    }
  }

  static List<String> getSymbolsInFolder(String folderId) {
    final box = _box(_watchlistBox);
    if (box == null) return const <String>[];
    final symbols = <String>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final item = FavoriteItem.fromJson(jsonDecode(data));
        if (item.folderIds.contains(folderId)) {
          symbols.add(item.symbol);
        }
      }
    }
    return symbols;
  }

  static List<String> getAllFavoriteSymbols() {
    final box = _box(_watchlistBox);
    if (box == null) return const <String>[];
    return box.keys.cast<String>().toList();
  }

  static Future<void> clearAllFavorites() async {
    final box = _box(_watchlistBox);
    if (box == null) return;
    await box.clear();
  }

  static Future<void> clearAllFolders() async {
    final foldersBox = _box(_foldersBox);
    if (foldersBox != null) await foldersBox.clear();
    final watchBox = _box(_watchlistBox);
    if (watchBox != null) await watchBox.clear();
  }

  static List<String> getFoldersForSymbol(String symbol) {
    final box = _box(_watchlistBox);
    if (box == null) return const <String>[];
    if (box.containsKey(symbol)) {
      return FavoriteItem.fromJson(jsonDecode(box.get(symbol))).folderIds;
    }
    return [];
  }

  // Reminders
  static Future<void> saveReminder(Reminder reminder) async {
    final box = _box(_remindersBox);
    if (box == null) return;
    await box.put(reminder.id, jsonEncode(_reminderToMap(reminder)));
  }

  static List<Reminder> getReminders() {
    final box = _box(_remindersBox);
    if (box == null) return const <Reminder>[];
    return box.values.map((v) => _reminderFromMap(jsonDecode(v))).toList()
      ..sort((a, b) => b.remindAt.compareTo(a.remindAt));
  }

  static Future<void> markReminderRead(String id) async {
    final box = _box(_remindersBox);
    if (box == null) return;
    final data = box.get(id);
    if (data != null) {
      final reminder = _reminderFromMap(jsonDecode(data));
      await box.put(id, jsonEncode(_reminderToMap(reminder.copyWith(isRead: true))));
    }
  }

  static Future<void> deleteReminder(String id) async {
    final box = _box(_remindersBox);
    if (box == null) return;
    await box.delete(id);
  }

  // Analysis Notes
  static Future<void> saveNote(String tradeId, AnalysisNote note) async {
    final box = _box(_notesBox);
    if (box == null) return;
    final key = '${tradeId}_${note.id}';
    await box.put(key, jsonEncode(_noteToMap(note)));
  }

  static List<AnalysisNote> getNotesForTrade(String tradeId) {
    final box = _box(_notesBox);
    if (box == null) return const <AnalysisNote>[];
    final prefix = '${tradeId}_';
    final notes = <AnalysisNote>[];
    for (final key in box.keys) {
      if (key.toString().startsWith(prefix)) {
        notes.add(_noteFromMap(jsonDecode(box.get(key))));
      }
    }
    return notes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> deleteNote(String tradeId, String noteId) async {
    final box = _box(_notesBox);
    if (box == null) return;
    final key = '${tradeId}_$noteId';
    await box.delete(key);
  }

  // Preferences (small key-value store for app-wide settings)
  /// Reads the persisted journal-entry counter used to throttle the
  /// interstitial ad cadence across app launches.
  static int getAdInterstitialCounter() {
    final box = _box(_prefsBox);
    if (box == null) return 0;
    return (box.get(_kAdInterstitialCounter, defaultValue: 0) as int?) ?? 0;
  }

  /// Writes the current journal-entry counter. Called after every
  /// increment so progress survives app kills.
  static Future<void> setAdInterstitialCounter(int count) async {
    final box = _box(_prefsBox);
    if (box == null) return;
    await box.put(_kAdInterstitialCounter, count);
  }

  // Serialization helpers.
  //
  // NOTE (H1): `analysisNotes` and `reminders` are intentionally NOT included
  // in the serialized map. They live in their own Hive boxes (_notesBox,
  // _remindersBox) and are read separately via TradeProvider / LocalStorageService.
  // Including them here would make every save round-trip wipe the in-memory
  // lists (since `_tradeFromMap` always assigns `const []` to the defaults).
  /// Public test-friendly wrapper around [_tradeToMap]. The mapping is
  /// exhaustive except for the analysis-notes / reminders, which live in
  /// their own boxes (H1).
  static Map<String, dynamic> tradeToMapForTest(TradeEntry t) => _tradeToMap(t);
  static Map<String, dynamic> _tradeToMap(TradeEntry t) => {
    'id': t.id, 'stockSymbol': t.stockSymbol, 'stockName': t.stockName,
    'type': t.type.name, 'direction': t.direction.name,
    'entryPrice': t.entryPrice, 'exitPrice': t.exitPrice, 'quantity': t.quantity,
    'entryDate': t.entryDate.toIso8601String(), 'exitDate': t.exitDate?.toIso8601String(),
    'reason': t.reason, 'strategy': t.strategy, 'lesson': t.lesson,
    'result': t.result.name, 'isClosed': t.isClosed,
    // Nullable: trades written before this field was added have no market
    // key in the persisted map; the read path handles that.
    'market': t.market?.name,
  };

  /// Schema-evolution-safe deserializer. Every key has a sensible default so a
  /// trade persisted by an older app version (or one with extra fields added
  /// later) can still be read without crashing the entire getTrades() call.
  /// Public test-friendly wrapper around [_tradeFromMap]. Every field has
  /// a safe default so a partially-shaped map (older app version,
  /// forward-compat, malformed JSON) does not crash the call (H2).
  /// `isClosed` defaults to `true` if `exitDate` is present and the field
  /// is missing, so closed positions don't get re-classified as open on
  /// schema migration (H3).
  static TradeEntry tradeFromMapForTest(Map<String, dynamic> m) => _tradeFromMap(m);
  static TradeEntry _tradeFromMap(Map<String, dynamic> m) {
    // H2: defaults on every required primitive; H3: infer isClosed for older
    // data that pre-dates the field by looking at whether an exitDate exists.
    final hasExitDate = m['exitDate'] != null;
    final rawIsClosed = m['isClosed'] as bool?;
    final isClosed = rawIsClosed ?? hasExitDate;

    // `market` is nullable on the model. Trades written before this field
    // existed have no key at all — `m['market']` returns null and we
    // leave `TradeEntry.market` as null. Display sites then fall back to
    // `inferMarketFromSymbol(stockSymbol)` for currency rendering.
    MarketType? marketFromStorage;
    final rawMarket = m['market'] as String?;
    if (rawMarket != null) {
      try {
        marketFromStorage = MarketType.values.byName(rawMarket);
      } catch (_) {
        // Unknown / corrupted value — leave null so we don't crash on read.
        marketFromStorage = null;
      }
    }

    return TradeEntry(
      id: (m['id'] as String?) ?? '',
      stockSymbol: (m['stockSymbol'] as String?) ?? '',
      stockName: (m['stockName'] as String?) ?? '',
      type: TradeType.values.byName(
        (m['type'] as String?) ?? TradeType.real.name,
      ),
      direction: TradeDirection.values.byName(
        (m['direction'] as String?) ?? TradeDirection.buy.name,
      ),
      entryPrice: ((m['entryPrice'] as num?) ?? 0).toDouble(),
      exitPrice: (m['exitPrice'] as num?)?.toDouble(),
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      entryDate: _parseDate(m['entryDate']) ?? DateTime.now(),
      exitDate: _parseDate(m['exitDate']),
      reason: m['reason'] as String?,
      strategy: m['strategy'] as String?,
      lesson: m['lesson'] as String?,
      result: TradeResult.values.byName(
        (m['result'] as String?) ?? TradeResult.pending.name,
      ),
      isClosed: isClosed,
      market: marketFromStorage,
    );
  }

  /// Parses a possibly-null ISO 8601 string into a [DateTime]. Returns null
  /// for any failure (including null input) so callers can decide defaults.
  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  static Map<String, dynamic> _reminderToMap(Reminder r) => {
    'id': r.id, 'title': r.title, 'note': r.note,
    'remindAt': r.remindAt.toIso8601String(), 'isRead': r.isRead,
    // tradeId is nullable for non-trade reminders; missing-key tolerant in
    // [_reminderFromMap] via the default of null.
    'tradeId': r.tradeId,
  };

  static Reminder _reminderFromMap(Map<String, dynamic> m) => Reminder(
    id: (m['id'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    note: m['note'] as String?,
    remindAt: DateTime.tryParse(m['remindAt'] as String? ?? '') ?? DateTime.now(),
    isRead: (m['isRead'] as bool?) ?? false,
    tradeId: m['tradeId'] as String?,
  );

  static Map<String, dynamic> _noteToMap(AnalysisNote n) => {
    'id': n.id, 'content': n.content,
    'createdAt': n.createdAt.toIso8601String(), 'category': n.category,
  };

  static AnalysisNote _noteFromMap(Map<String, dynamic> m) => AnalysisNote(
    id: m['id'], content: m['content'],
    createdAt: DateTime.parse(m['createdAt']), category: m['category'] ?? 'general',
  );
}
