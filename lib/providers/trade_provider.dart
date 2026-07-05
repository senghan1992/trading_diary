import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../services/stock_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

enum TradeFilter { all, real, virtual }

class TradeProvider extends ChangeNotifier {
  List<TradeEntry> _trades = [];
  List<Reminder> _reminders = [];
  TradeFilter _filter = TradeFilter.all;
  final _uuid = const Uuid();

  List<TradeEntry> get trades => _trades;
  List<Reminder> get reminders => _reminders;
  TradeFilter get filter => _filter;

  TradeProvider() {
    loadTrades();
    loadReminders();
  }

  void loadTrades() {
    _trades = LocalStorageService.getTrades();
    notifyListeners();
  }

  void loadReminders() {
    _reminders = LocalStorageService.getReminders();
    notifyListeners();
  }

  void setFilter(TradeFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  List<TradeEntry> get filteredTrades {
    switch (_filter) {
      case TradeFilter.all:
        return _trades;
      case TradeFilter.real:
        return _trades.where((t) => t.type == TradeType.real).toList();
      case TradeFilter.virtual:
        return _trades.where((t) => t.type == TradeType.virtual).toList();
    }
  }

  List<TradeEntry> get openPositions {
    return filteredTrades.where((t) => !t.isClosed).toList();
  }

  List<TradeEntry> get closedPositions {
    return filteredTrades.where((t) => t.isClosed).toList();
  }

  List<TradeEntry> get closedTrades {
    return closedPositions;
  }

  int get totalTradesAll => _trades.where((t) => t.isClosed).length;
  int get openPositionCountAll => _trades.where((t) => !t.isClosed).length;

  Future<void> addPosition({
    required String stockSymbol,
    required String stockName,
    required MarketType market,
    required TradeType type,
    required TradeDirection direction,
    required double entryPrice,
    required int quantity,
    required DateTime entryDate,
    String? reason,
    String? strategy,
  }) async {
    final trade = TradeEntry(
      id: _uuid.v4(),
      stockSymbol: stockSymbol,
      stockName: stockName,
      market: market,
      type: type,
      direction: direction,
      entryPrice: entryPrice,
      exitPrice: null,
      quantity: quantity,
      entryDate: entryDate,
      exitDate: null,
      reason: reason,
      strategy: strategy,
      result: TradeResult.pending,
      isClosed: false,
    );
    await LocalStorageService.saveTrade(trade);
    loadTrades();
  }

  Future<void> addTrade({
    required String stockSymbol,
    required String stockName,
    required MarketType market,
    required TradeType type,
    required TradeDirection direction,
    required double entryPrice,
    required double exitPrice,
    required int quantity,
    required DateTime entryDate,
    required DateTime exitDate,
    String? reason,
    String? strategy,
  }) async {
    // M1 guard: silently coerce nonsensical exit dates to entryDate rather
    // than persist an invalid trade. The UI date picker already prevents
    // this for normal flows, but the provider must still defend against
    // direct API callers and stale form state.
    final safeExitDate =
        exitDate.isBefore(entryDate) ? entryDate : exitDate;
    final trade = TradeEntry(
      id: _uuid.v4(),
      stockSymbol: stockSymbol,
      stockName: stockName,
      market: market,
      type: type,
      direction: direction,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
      quantity: quantity,
      entryDate: entryDate,
      exitDate: safeExitDate,
      reason: reason,
      strategy: strategy,
      result: _computeResult(direction, entryPrice, exitPrice),
      isClosed: true,
    );
    await LocalStorageService.saveTrade(trade);
    loadTrades();
  }

  Future<void> closePosition({
    required String tradeId,
    required double exitPrice,
    required DateTime exitDate,
  }) async {
    // B1 guard: previously called `_trades.firstWhere(...)` which throws
    // StateError when the trade is no longer in the in-memory list (deleted
    // elsewhere, sync conflict, etc.). The fire-and-forget call site means
    // an exception here would silently corrupt the next save round-trip.
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _trades[idx];
    // H5: idempotency guard. Calling closePosition twice used to silently
    // overwrite the original exit data; the in-memory trade list now mirrors
    // Hive, so this catches double-tap regressions on the UI side too.
    if (trade.isClosed) return;
    // M1 guard: same as addTrade — coerce exit < entry to entry.
    final safeExitDate =
        exitDate.isBefore(trade.entryDate) ? trade.entryDate : exitDate;
    final closedTrade = trade.copyWith(
      exitPrice: exitPrice,
      exitDate: safeExitDate,
      result: _computeResult(trade.direction, trade.entryPrice, exitPrice),
      isClosed: true,
    );
    await LocalStorageService.saveTrade(closedTrade);
    loadTrades();
  }

  /// H7: assigns one of success / failure / breakeven based on price
  /// comparison. Breakeven used to silently count as success (inflating the
  /// win rate); it now has its own [TradeResult.breakeven] value so the win
  /// rate counter excludes it.
  /// Public test-friendly wrapper around the H7 [_computeResult] logic.
  /// Exposes the breakeven success/failure attribution rules without
  /// requiring a full Hive fixture to exercise.
  static TradeResult computeResultForTest(
          TradeDirection direction, double entryPrice, double exitPrice) =>
      _computeResult(direction, entryPrice, exitPrice);
  static TradeResult _computeResult(
      TradeDirection direction, double entryPrice, double exitPrice) {
    if (direction == TradeDirection.buy) {
      if (exitPrice > entryPrice) return TradeResult.success;
      if (exitPrice < entryPrice) return TradeResult.failure;
      return TradeResult.breakeven;
    } else {
      if (exitPrice < entryPrice) return TradeResult.success;
      if (exitPrice > entryPrice) return TradeResult.failure;
      return TradeResult.breakeven;
    }
  }

  Future<void> updateTrade(TradeEntry trade) async {
    await LocalStorageService.saveTrade(trade);
    loadTrades();
  }

  /// H4: cascading delete. Removes the trade from Hive AND any AnalysisNote
  /// keys prefixed with `${tradeId}_` AND any Reminder whose `tradeId` field
  /// matches. Reminders tied to this trade are also cancelled in the OS via
  /// [NotificationService.cancel] so a notification stops firing for a
  /// trade the user has already deleted.
  ///
  /// OS-level cancel is wrapped in try/catch — if the notification plugin
  /// is unavailable (test env, plugin not loaded), the Hive cascade must
  /// still complete and the in-memory state must still reflect the delete.
  /// Hive, not the OS scheduler, is the source of truth.
  Future<void> deleteTrade(String id) async {
    final notes = LocalStorageService.getNotesForTrade(id);
    for (final n in notes) {
      await LocalStorageService.deleteNote(id, n.id);
    }
    final remindersForTrade =
        _reminders.where((r) => r.tradeId == id).toList(growable: false);
    for (final r in remindersForTrade) {
      await LocalStorageService.deleteReminder(r.id);
      try {
        await NotificationService.instance.cancel(r.id);
      } catch (_) {
        // Best-effort OS cancel — Hive delete is canonical.
      }
    }
    await LocalStorageService.deleteTrade(id);
    loadTrades();
    loadReminders();
  }

  Future<void> addAnalysisNote(String tradeId, String content, {String category = 'general'}) async {
    final note = AnalysisNote(
      id: _uuid.v4(),
      content: content,
      createdAt: DateTime.now(),
      category: category,
    );
    await LocalStorageService.saveNote(tradeId, note);
    notifyListeners();
  }

  Future<void> deleteAnalysisNote(String tradeId, String noteId) async {
    await LocalStorageService.deleteNote(tradeId, noteId);
    notifyListeners();
  }

  List<AnalysisNote> getNotesForTrade(String tradeId) {
    return LocalStorageService.getNotesForTrade(tradeId);
  }

  /// Returns true if the reminder was persisted AND scheduled with the OS.
  /// Returns false if the user has not granted (or has revoked) notification
  /// permission — in that case the reminder is still saved to Hive so the
  /// in-app reminders tab can show it, but no OS notification will fire.
  ///
  /// [tradeId] is the optional `Reminder.tradeId` field that makes the
  /// reminder a child of a trade (so that deleting the trade cascades into
  /// cancelling the reminder — see [deleteTrade]).
  Future<bool> addReminder(
    String title,
    String? note,
    DateTime remindAt, {
    String? tradeId,
  }) async {
    final reminder = Reminder(
      id: _uuid.v4(),
      title: title,
      note: note,
      remindAt: remindAt,
      tradeId: tradeId,
    );
    await LocalStorageService.saveReminder(reminder);

    // H9: gate the OS-level schedule on actual permission. Previously we
    // just called schedule() and any permission failure was swallowed (the
    // notification never fires and the user sees nothing).
    final granted = await NotificationService.instance.requestPermissions() ?? true;
    if (!granted) {
      loadReminders();
      return false;
    }

    final ok = await NotificationService.instance.schedule(reminder);
    loadReminders();
    return ok;
  }

  Future<void> markReminderRead(String id) async {
    await LocalStorageService.markReminderRead(id);
    // Marking as read only suppresses the in-app badge; future ones would
    // still fire because the user may want the OS notification even after
    // seeing the card. We deliberately do NOT cancel the OS schedule here.
    loadReminders();
  }

  /// Removes the reminder from local storage AND cancels any OS-scheduled
  /// notification for it. This is the only way to stop a future reminder
  /// from firing.
  Future<void> deleteReminder(String id) async {
    await LocalStorageService.deleteReminder(id);
    await NotificationService.instance.cancel(id);
    loadReminders();
  }

  /// M9: shifts a reminder's [remindAt] forward by [by] and re-schedules
  /// it with the OS. Used when an overdue reminder needs to be rescheduled
  /// (the new snooze picker exposes 1d / 1w / 1mo / 3mo options).
  ///
  /// Returns true if the reminder was persisted AND successfully rescheduled.
  /// All OS-level calls are wrapped in try/catch — the Hive write is the
  /// source of truth, and a missing/disabled notification plugin (test
  /// env, plugin not loaded yet) must not block the data update.
  Future<bool> snoozeReminder(String id, Duration by) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return false;
    final old = _reminders[idx];
    // Build a fresh Reminder so date + read state update atomically.
    final updated = Reminder(
      id: old.id,
      title: old.title,
      note: old.note,
      remindAt: old.remindAt.add(by),
      isRead: false, // snoozing counts as new attention
      tradeId: old.tradeId,
    );
    await LocalStorageService.saveReminder(updated);

    try {
      await NotificationService.instance.cancel(old.id);
    } catch (_) {
      // Best-effort OS cancel — Hive save is canonical.
    }

    bool granted = true;
    try {
      granted =
          await NotificationService.instance.requestPermissions() ?? true;
    } catch (_) {
      granted = true;
    }
    if (!granted) {
      loadReminders();
      return false;
    }

    bool ok = false;
    try {
      ok = await NotificationService.instance.schedule(updated);
    } catch (_) {
      ok = false;
    }

    loadReminders();
    return ok;
  }

  /// Re-syncs the OS scheduler to the current in-memory list of reminders.
  /// Use on app launch (covers cold reboot / OS clearing alarms).
  Future<int> rescheduleAllReminders() async {
    return NotificationService.instance.rescheduleAll(_reminders);
  }

  Future<List<DailyPrice>> getHistoricalPrices(String symbol) async {
    return await StockApiService.getHistoricalPrices(symbol);
  }

  int get totalTrades => closedPositions.length;
  int get openPositionCount => openPositions.length;
  int get winningTrades => closedPositions.where((t) => t.result == TradeResult.success).length;
  int get losingTrades => closedPositions.where((t) => t.result == TradeResult.failure).length;
  int get pendingTrades => openPositions.length;

  double get winRate {
    if (totalTrades == 0) return 0;
    return (winningTrades / totalTrades) * 100;
  }

  double get totalProfitLoss {
    return closedPositions.fold(0.0, (sum, t) => sum + t.profitLoss);
  }

  double get currentValue {
    return openPositions.fold(0.0, (sum, t) => sum + (t.entryPrice * t.quantity));
  }

  List<MapEntry<DateTime, double>> get profitLossOverTime {
    final map = <DateTime, double>{};
    for (final t in closedPositions) {
      if (t.exitDate != null) {
        map[t.exitDate!] = (map[t.exitDate!] ?? 0) + t.profitLoss;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    var cumulative = 0.0;
    return sorted.map((e) {
      cumulative += e.value;
      return MapEntry(e.key, cumulative);
    }).toList();
  }

  /// Date-keyed (year/month/day, time zeroed) map of summed profit/loss for
  /// all closed trades. Keys present only for days with at least one close.
  Map<DateTime, double> get dailyPnLByDate {
    final map = <DateTime, double>{};
    for (final t in closedPositions) {
      if (t.exitDate == null) continue;
      final dayKey = DateTime(t.exitDate!.year, t.exitDate!.month, t.exitDate!.day);
      map[dayKey] = (map[dayKey] ?? 0) + t.profitLoss;
    }
    return map;
  }

  /// Closed trades grouped by their exit date (day-level key, time zeroed).
  /// Order within a day follows the iteration order of [closedPositions].
  Map<DateTime, List<TradeEntry>> get closedTradesByExitDate {
    final map = <DateTime, List<TradeEntry>>{};
    for (final t in closedPositions) {
      if (t.exitDate == null) continue;
      final dayKey = DateTime(t.exitDate!.year, t.exitDate!.month, t.exitDate!.day);
      map.putIfAbsent(dayKey, () => []).add(t);
    }
    return map;
  }

  /// Average profit/loss across all closed trades. 0 when there are none.
  double get averagePnL {
    if (totalTrades == 0) return 0;
    return totalProfitLoss / totalTrades;
  }

  /// Trade with the highest profit; null when there is no closed trade.
  TradeEntry? get bestTrade {
    if (closedPositions.isEmpty) return null;
    final sorted = [...closedPositions]..sort((a, b) => b.profitLoss.compareTo(a.profitLoss));
    return sorted.first;
  }

  /// Trade with the lowest profit (i.e. largest loss); null when there is no closed trade.
  TradeEntry? get worstTrade {
    if (closedPositions.isEmpty) return null;
    final sorted = [...closedPositions]..sort((a, b) => a.profitLoss.compareTo(b.profitLoss));
    return sorted.first;
  }

  /// Length of the longest run of consecutive winning closes, ordered by exit date ascending.
  int get longestWinStreak {
    if (closedPositions.isEmpty) return 0;
    final ordered = [...closedPositions]..sort((a, b) => (a.exitDate ?? a.entryDate).compareTo(b.exitDate ?? b.entryDate));
    var best = 0;
    var current = 0;
    for (final t in ordered) {
      if (t.result == TradeResult.success) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  /// Length of the longest run of consecutive losing closes, ordered by exit date ascending.
  int get longestLossStreak {
    if (closedPositions.isEmpty) return 0;
    final ordered = [...closedPositions]..sort((a, b) => (a.exitDate ?? a.entryDate).compareTo(b.exitDate ?? b.entryDate));
    var best = 0;
    var current = 0;
    for (final t in ordered) {
      if (t.result == TradeResult.failure) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }
}
