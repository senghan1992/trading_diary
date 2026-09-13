import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/trade_entry.dart';
import '../models/account_tag.dart';
import '../models/stock.dart';
import '../services/local_storage_service.dart';

enum TradeFilter { all, real, virtual }

class TradeProvider extends ChangeNotifier {
  List<TradeEntry> _trades = [];
  List<AccountTag> _accounts = [];
  TradeFilter _filter = TradeFilter.all;

  /// Currently-selected account tag *name* for the journal filter bar.
  /// `null` = all accounts combined (integrated view).
  String? _selectedAccountTagFilter;
  final _uuid = const Uuid();
  List<AccountTag> get accounts => _accounts;
  String? get selectedAccountTagFilter => _selectedAccountTagFilter;

  List<TradeEntry> get trades => _trades;
  TradeFilter get filter => _filter;

  TradeProvider() {
    loadTrades();
    loadAccounts();
  }

  void loadTrades() {
    _trades = LocalStorageService.getTrades();
    notifyListeners();
  }

  void setSelectedAccountTagFilter(String? tag) {
    _selectedAccountTagFilter = tag;
    notifyListeners();
  }

  void loadAccounts() {
    _accounts = LocalStorageService.getAccounts();
    notifyListeners();
  }

  Future<void> addAccount({
    required String name,
    int? colorValue,
    String? memo,
  }) async {
    final account = AccountTag(
      id: _uuid.v4(),
      name: name,
      colorValue: colorValue,
      memo: memo,
      createdAt: DateTime.now(),
    );
    await LocalStorageService.saveAccount(account);
    loadAccounts();
  }

  Future<void> updateAccount(AccountTag account) async {
    await LocalStorageService.saveAccount(account);
    loadAccounts();
  }

  /// Deletes the account registry entry. Trades keep their stored
  /// `accountTag` string so history is never lost; they simply render as
  /// an orphaned (or "미지정") tag until reassigned.
  Future<void> deleteAccount(String id) async {
    await LocalStorageService.deleteAccount(id);
    loadAccounts();
  }

  void setFilter(TradeFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  List<TradeEntry> get filteredTrades {
    Iterable<TradeEntry> scoped = switch (_filter) {
      TradeFilter.all => _trades,
      TradeFilter.real => _trades.where((t) => t.type == TradeType.real),
      TradeFilter.virtual => _trades.where((t) => t.type == TradeType.virtual),
    };
    if (_selectedAccountTagFilter != null) {
      scoped = scoped.where((t) => t.accountTag == _selectedAccountTagFilter);
    }
    return scoped.toList();
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

  Future<void> addPosition({
    required String stockSymbol,
    required String stockName,
    MarketType? market,
    required TradeType type,
    required TradeDirection direction,
    required double entryPrice,
    required int quantity,
    required DateTime entryDate,
    String? reason,
    String? strategy,
    String? lesson,
    String? accountTag,
    List<TradeExecution> executions = const [],
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
      lesson: lesson ?? strategy,
      accountTag: accountTag,
      result: TradeResult.pending,
      isClosed: false,
      executions: executions,
    );
    await LocalStorageService.saveTrade(trade);
    loadTrades();
  }

  Future<void> addTrade({
    required String stockSymbol,
    required String stockName,
    MarketType? market,
    required TradeType type,
    required TradeDirection direction,
    required double entryPrice,
    required double exitPrice,
    required int quantity,
    required DateTime entryDate,
    required DateTime exitDate,
    String? reason,
    String? strategy,
    String? lesson,
    String? accountTag,
    List<TradeExecution> executions = const [],
  }) async {
    // M1 guard: silently coerce nonsensical exit dates to entryDate rather
    // than persist an invalid trade. The UI date picker already prevents
    // this for normal flows, but the provider must still defend against
    // direct API callers and stale form state.
    final safeExitDate = exitDate.isBefore(entryDate) ? entryDate : exitDate;
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
      lesson: lesson ?? strategy,
      accountTag: accountTag,
      result: _computeResult(direction, entryPrice, exitPrice),
      isClosed: true,
      executions: executions,
    );
    await LocalStorageService.saveTrade(trade);
    loadTrades();
  }

  Future<void> addTradeExecution({
    required String tradeId,
    required TradeExecutionAction action,
    required double price,
    required int quantity,
    required DateTime date,
    String? memo,
  }) async {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _trades[idx];

    final currentExecutions = List<TradeExecution>.from(trade.executions);
    // executions가 없던 기존 거래라면 첫 매수(및 이전 매도)를 execution으로 부트스트랩
    if (currentExecutions.isEmpty) {
      currentExecutions.add(TradeExecution(
        id: _uuid.v4(),
        action: TradeExecutionAction.buy,
        price: trade.entryPrice,
        quantity: trade.quantity,
        date: trade.entryDate,
        memo: '1차 매수',
      ));
      if (trade.isClosed && trade.exitPrice != null && trade.exitDate != null) {
        currentExecutions.add(TradeExecution(
          id: _uuid.v4(),
          action: TradeExecutionAction.sell,
          price: trade.exitPrice!,
          quantity: trade.quantity,
          date: trade.exitDate!,
          memo: '전량 매도',
        ));
      }
    }

    currentExecutions.add(TradeExecution(
      id: _uuid.v4(),
      action: action,
      price: price,
      quantity: quantity,
      date: date,
      memo: memo,
    ));

    final updatedTrade = trade.copyWith(executions: currentExecutions);
    await LocalStorageService.saveTrade(updatedTrade);
    loadTrades();
  }

  Future<void> deleteTradeExecution({
    required String tradeId,
    required String executionId,
  }) async {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _trades[idx];
    final newExecutions = trade.executions.where((e) => e.id != executionId).toList();
    final updatedTrade = trade.copyWith(executions: newExecutions);
    await LocalStorageService.saveTrade(updatedTrade);
    loadTrades();
  }

  Future<void> closePosition({
    required String tradeId,
    required double exitPrice,
    required DateTime exitDate,
    int? quantity,
  }) async {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _trades[idx];
    if (trade.isClosed) return;

    final targetQty = (quantity != null && quantity > 0)
        ? quantity
        : trade.remainingQuantity;

    // 분할 매도(수량이 남은 수량보다 적거나, 이미 executions가 있는 경우)
    if (trade.hasExecutions || (quantity != null && quantity < trade.remainingQuantity)) {
      await addTradeExecution(
        tradeId: tradeId,
        action: TradeExecutionAction.sell,
        price: exitPrice,
        quantity: targetQty,
        date: exitDate,
        memo: targetQty < trade.remainingQuantity ? '부분 매도' : '전량 매도',
      );
      return;
    }

    final safeExitDate = exitDate.isBefore(trade.entryDate)
        ? trade.entryDate
        : exitDate;
    final closedTrade = trade.copyWith(
      exitPrice: exitPrice,
      exitDate: safeExitDate,
      result: _computeResult(trade.direction, trade.entryPrice, exitPrice),
      isClosed: true,
    );
    await LocalStorageService.saveTrade(closedTrade);
    loadTrades();
  }

  /// Reassigns (or clears) an existing trade's account tag.
  Future<void> updateTradeAccountTag(String tradeId, String? accountTag) async {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    await updateTrade(_trades[idx].withAccountTag(accountTag));
  }

  /// H7: assigns one of success / failure / breakeven based on price
  /// comparison. Breakeven used to silently count as success (inflating the
  /// win rate); it now has its own [TradeResult.breakeven] value so the win
  /// rate counter excludes it.
  /// Public test-friendly wrapper around the H7 [_computeResult] logic.
  /// Exposes the breakeven success/failure attribution rules without
  /// requiring a full Hive fixture to exercise.
  static TradeResult computeResultForTest(
    TradeDirection direction,
    double entryPrice,
    double exitPrice,
  ) => _computeResult(direction, entryPrice, exitPrice);
  static TradeResult _computeResult(
    TradeDirection direction,
    double entryPrice,
    double exitPrice,
  ) {
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
  /// keys prefixed with `${tradeId}_`.
  Future<void> deleteTrade(String id) async {
    final notes = LocalStorageService.getNotesForTrade(id);
    for (final n in notes) {
      await LocalStorageService.deleteNote(id, n.id);
    }
    await LocalStorageService.deleteTrade(id);
    loadTrades();
  }

  Future<void> addAnalysisNote(
    String tradeId,
    String content, {
    String category = 'general',
  }) async {
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

  int get totalTrades => closedPositions.length;
  int get openPositionCount => openPositions.length;
  int get winningTrades =>
      closedPositions.where((t) => t.result == TradeResult.success).length;
  int get losingTrades =>
      closedPositions.where((t) => t.result == TradeResult.failure).length;
  int get pendingTrades => openPositions.length;

  double get winRate {
    if (totalTrades == 0) return 0;
    return (winningTrades / totalTrades) * 100;
  }

  double get totalProfitLoss {
    return closedPositions.fold(0.0, (sum, t) => sum + t.profitLoss);
  }

  double get currentValue {
    return openPositions.fold(
      0.0,
      (sum, t) => sum + (t.entryPrice * t.quantity),
    );
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
      final dayKey = DateTime(
        t.exitDate!.year,
        t.exitDate!.month,
        t.exitDate!.day,
      );
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
      final dayKey = DateTime(
        t.exitDate!.year,
        t.exitDate!.month,
        t.exitDate!.day,
      );
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
    final sorted = [...closedPositions]
      ..sort((a, b) => b.profitLoss.compareTo(a.profitLoss));
    return sorted.first;
  }

  /// Trade with the lowest profit (i.e. largest loss); null when there is no closed trade.
  TradeEntry? get worstTrade {
    if (closedPositions.isEmpty) return null;
    final sorted = [...closedPositions]
      ..sort((a, b) => a.profitLoss.compareTo(b.profitLoss));
    return sorted.first;
  }

  /// Length of the longest run of consecutive winning closes, ordered by exit date ascending.
  int get longestWinStreak {
    if (closedPositions.isEmpty) return 0;
    final ordered = [...closedPositions]
      ..sort(
        (a, b) =>
            (a.exitDate ?? a.entryDate).compareTo(b.exitDate ?? b.entryDate),
      );
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
    final ordered = [...closedPositions]
      ..sort(
        (a, b) =>
            (a.exitDate ?? a.entryDate).compareTo(b.exitDate ?? b.entryDate),
      );
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
