import 'stock.dart';

enum TradeType { real, virtual }

enum TradeDirection { buy, sell }

/// `breakeven` covers the exitPrice == entryPrice case. It used to map to
/// `success` (which inflated the win-rate counter); it now sits alongside
/// success/failure so the win-rate denominator doesn't double-count.
enum TradeResult { success, failure, breakeven, pending }

enum TradeExecutionAction { buy, sell }

class TradeExecution {
  final String id;
  final TradeExecutionAction action;
  final double price;
  final int quantity;
  final DateTime date;
  final String? memo;

  const TradeExecution({
    required this.id,
    required this.action,
    required this.price,
    required this.quantity,
    required this.date,
    this.memo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action.name,
    'price': price,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'memo': memo,
  };

  factory TradeExecution.fromMap(Map<String, dynamic> m) {
    return TradeExecution(
      id: (m['id'] as String?) ?? '',
      action: TradeExecutionAction.values.byName(
        (m['action'] as String?) ?? TradeExecutionAction.buy.name,
      ),
      price: ((m['price'] as num?) ?? 0).toDouble(),
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      memo: m['memo'] as String?,
    );
  }

  TradeExecution copyWith({
    String? id,
    TradeExecutionAction? action,
    double? price,
    int? quantity,
    DateTime? date,
    String? memo,
  }) {
    return TradeExecution(
      id: id ?? this.id,
      action: action ?? this.action,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      date: date ?? this.date,
      memo: memo ?? this.memo,
    );
  }
}

class TradeExecutionSnapshot {
  final TradeExecution execution;
  final int stepIndex;
  final int remainingSharesAfter;
  final double averagePriceAfter;
  final double? stepRealizedPnl;
  final double? stepReturnPercent;

  const TradeExecutionSnapshot({
    required this.execution,
    required this.stepIndex,
    required this.remainingSharesAfter,
    required this.averagePriceAfter,
    this.stepRealizedPnl,
    this.stepReturnPercent,
  });
}

class TradeCalculatedState {
  final double averageEntryPrice;
  final double? averageExitPrice;
  final int totalBuyQuantity;
  final int totalSellQuantity;
  final int remainingQuantity;
  final double realizedProfitLoss;
  final DateTime entryDate;
  final DateTime? exitDate;
  final bool isClosed;
  final TradeResult result;

  const TradeCalculatedState({
    required this.averageEntryPrice,
    required this.averageExitPrice,
    required this.totalBuyQuantity,
    required this.totalSellQuantity,
    required this.remainingQuantity,
    required this.realizedProfitLoss,
    required this.entryDate,
    required this.exitDate,
    required this.isClosed,
    required this.result,
  });
}

class TradeEntry {
  final String id;
  final String stockSymbol;
  final String stockName;
  final TradeType type;
  final TradeDirection direction;
  final double _rawEntryPrice;
  final double? _rawExitPrice;
  final int _rawQuantity;
  final DateTime _rawEntryDate;
  final DateTime? _rawExitDate;
  final String? reason;
  final String? strategy;
  final String? lesson;
  final TradeResult _rawResult;
  final List<AnalysisNote> analysisNotes;
  final bool _rawIsClosed;
  final MarketType? market;
  final String? accountTag;
  final List<TradeExecution> executions;

  TradeEntry({
    required this.id,
    required this.stockSymbol,
    required this.stockName,
    required this.type,
    required this.direction,
    required double entryPrice,
    double? exitPrice,
    required int quantity,
    required DateTime entryDate,
    DateTime? exitDate,
    this.reason,
    this.strategy,
    this.lesson,
    TradeResult result = TradeResult.pending,
    this.analysisNotes = const [],
    bool isClosed = false,
    this.market,
    this.accountTag,
    this.executions = const [],
  })  : _rawEntryPrice = entryPrice,
        _rawExitPrice = exitPrice,
        _rawQuantity = quantity,
        _rawEntryDate = entryDate,
        _rawExitDate = exitDate,
        _rawResult = result,
        _rawIsClosed = isClosed;

  bool get hasExecutions => executions.isNotEmpty;

  TradeCalculatedState get _calcState {
    if (executions.isEmpty) {
      return TradeCalculatedState(
        averageEntryPrice: _rawEntryPrice,
        averageExitPrice: _rawExitPrice,
        totalBuyQuantity: _rawQuantity,
        totalSellQuantity: (_rawIsClosed && _rawExitPrice != null) ? _rawQuantity : 0,
        remainingQuantity: _rawIsClosed ? 0 : _rawQuantity,
        realizedProfitLoss: _rawProfitLoss,
        entryDate: _rawEntryDate,
        exitDate: _rawExitDate,
        isClosed: _rawIsClosed,
        result: _rawResult,
      );
    }
    return _computeCalculatedState();
  }

  TradeCalculatedState _computeCalculatedState() {
    return calculateExecutions(
      executions: executions,
      direction: direction,
      fallbackEntryDate: _rawEntryDate,
      fallbackEntryPrice: _rawEntryPrice,
      fallbackQuantity: _rawQuantity,
    );
  }

  static TradeCalculatedState calculateExecutions({
    required List<TradeExecution> executions,
    required TradeDirection direction,
    required DateTime fallbackEntryDate,
    required double fallbackEntryPrice,
    required int fallbackQuantity,
  }) {
    final sorted = [...executions]..sort((a, b) => a.date.compareTo(b.date));
    var currentShares = 0;
    var currentAvgPrice = 0.0;
    var totalBuyShares = 0;
    var totalBuyAmount = 0.0;
    var totalSellShares = 0;
    var totalSellAmount = 0.0;
    var totalRealizedPnl = 0.0;
    DateTime? firstEntryDate;
    DateTime? lastExitDate;

    for (final exec in sorted) {
      if (exec.action == TradeExecutionAction.buy) {
        firstEntryDate ??= exec.date;
        totalBuyShares += exec.quantity;
        totalBuyAmount += exec.price * exec.quantity;

        final newShares = currentShares + exec.quantity;
        if (newShares > 0) {
          currentAvgPrice = ((currentShares * currentAvgPrice) + (exec.quantity * exec.price)) / newShares;
        }
        currentShares = newShares;
      } else {
        lastExitDate = exec.date;
        totalSellShares += exec.quantity;
        totalSellAmount += exec.price * exec.quantity;

        final profitPerShare = (direction == TradeDirection.buy)
            ? (exec.price - currentAvgPrice)
            : (currentAvgPrice - exec.price);
        totalRealizedPnl += profitPerShare * exec.quantity;

        currentShares = (currentShares - exec.quantity).clamp(0, double.infinity).toInt();
      }
    }

    final isFullyClosed = totalBuyShares > 0 && currentShares == 0 && totalSellShares > 0;
    final avgEntry = totalBuyShares > 0 ? (totalBuyAmount / totalBuyShares) : fallbackEntryPrice;
    final avgExit = totalSellShares > 0 ? (totalSellAmount / totalSellShares) : null;

    TradeResult calcResult;
    if (!isFullyClosed && totalSellShares == 0) {
      calcResult = TradeResult.pending;
    } else {
      if (totalRealizedPnl > 0) {
        calcResult = TradeResult.success;
      } else if (totalRealizedPnl < 0) {
        calcResult = TradeResult.failure;
      } else {
        calcResult = TradeResult.breakeven;
      }
    }

    return TradeCalculatedState(
      averageEntryPrice: avgEntry,
      averageExitPrice: avgExit,
      totalBuyQuantity: totalBuyShares,
      totalSellQuantity: totalSellShares,
      remainingQuantity: currentShares,
      realizedProfitLoss: totalRealizedPnl,
      entryDate: firstEntryDate ?? fallbackEntryDate,
      exitDate: isFullyClosed ? lastExitDate : (totalSellShares > 0 ? lastExitDate : null),
      isClosed: isFullyClosed,
      result: calcResult,
    );
  }

  /// 체결 진행 단계별 스냅샷 목록 생성 (타임라인 UI용)
  List<TradeExecutionSnapshot> getExecutionSnapshots() {
    if (executions.isEmpty) return const [];
    final sorted = [...executions]..sort((a, b) => a.date.compareTo(b.date));
    final snapshots = <TradeExecutionSnapshot>[];

    var currentShares = 0;
    var currentAvgPrice = 0.0;

    for (var i = 0; i < sorted.length; i++) {
      final exec = sorted[i];
      if (exec.action == TradeExecutionAction.buy) {
        final newShares = currentShares + exec.quantity;
        if (newShares > 0) {
          currentAvgPrice = ((currentShares * currentAvgPrice) + (exec.quantity * exec.price)) / newShares;
        }
        currentShares = newShares;
        snapshots.add(
          TradeExecutionSnapshot(
            execution: exec,
            stepIndex: i + 1,
            remainingSharesAfter: currentShares,
            averagePriceAfter: currentAvgPrice,
          ),
        );
      } else {
        final profitPerShare = (direction == TradeDirection.buy)
            ? (exec.price - currentAvgPrice)
            : (currentAvgPrice - exec.price);
        final pnl = profitPerShare * exec.quantity;
        final returnPct = currentAvgPrice > 0 ? (profitPerShare / currentAvgPrice) * 100 : 0.0;
        currentShares = (currentShares - exec.quantity).clamp(0, double.infinity).toInt();
        snapshots.add(
          TradeExecutionSnapshot(
            execution: exec,
            stepIndex: i + 1,
            remainingSharesAfter: currentShares,
            averagePriceAfter: currentAvgPrice,
            stepRealizedPnl: pnl,
            stepReturnPercent: returnPct,
          ),
        );
      }
    }

    return snapshots;
  }

  double get entryPrice => executions.isNotEmpty ? _calcState.averageEntryPrice : _rawEntryPrice;
  double? get exitPrice => executions.isNotEmpty ? _calcState.averageExitPrice : _rawExitPrice;
  int get quantity => executions.isNotEmpty ? _calcState.totalBuyQuantity : _rawQuantity;
  int get remainingQuantity => executions.isNotEmpty ? _calcState.remainingQuantity : (_rawIsClosed ? 0 : _rawQuantity);
  DateTime get entryDate => executions.isNotEmpty ? _calcState.entryDate : _rawEntryDate;
  DateTime? get exitDate => executions.isNotEmpty ? _calcState.exitDate : _rawExitDate;
  bool get isClosed => executions.isNotEmpty ? _calcState.isClosed : _rawIsClosed;
  TradeResult get result => executions.isNotEmpty ? _calcState.result : _rawResult;

  double get _rawProfitLoss {
    if (!_rawIsClosed || _rawExitPrice == null) return 0;
    if (direction == TradeDirection.buy) {
      return (_rawExitPrice - _rawEntryPrice) * _rawQuantity;
    } else {
      return (_rawEntryPrice - _rawExitPrice) * _rawQuantity;
    }
  }

  double get profitLoss {
    if (executions.isNotEmpty) {
      return _calcState.realizedProfitLoss;
    }
    return _rawProfitLoss;
  }

  double get profitLossPercent {
    if (entryPrice == 0) return 0;
    if (executions.isNotEmpty) {
      if (_calcState.totalSellQuantity == 0 || exitPrice == null) return 0;
      if (direction == TradeDirection.buy) {
        return ((exitPrice! - entryPrice) / entryPrice) * 100;
      } else {
        return ((entryPrice - exitPrice!) / entryPrice) * 100;
      }
    }
    if (!isClosed || exitPrice == null) return 0;
    if (direction == TradeDirection.buy) {
      return ((exitPrice! - entryPrice) / entryPrice) * 100;
    } else {
      return ((entryPrice - exitPrice!) / entryPrice) * 100;
    }
  }

  /// Unrealized P/L on an open position. Returns `null` because the app has
  /// no live price feed — every value shown is derived from user-entered
  /// prices only ([entryPrice] / [exitPrice]). Callers that need an
  /// "unrealized" figure should compute it from their own inputs or show a
  /// placeholder instead.
  double? get unrealizedProfitLoss => null;

  TradeEntry copyWith({
    String? id,
    String? stockSymbol,
    String? stockName,
    TradeType? type,
    TradeDirection? direction,
    double? entryPrice,
    double? exitPrice,
    int? quantity,
    DateTime? entryDate,
    DateTime? exitDate,
    String? reason,
    String? strategy,
    String? lesson,
    TradeResult? result,
    List<AnalysisNote>? analysisNotes,
    bool? isClosed,
    MarketType? market,
    String? accountTag,
    List<TradeExecution>? executions,
  }) {
    return TradeEntry(
      id: id ?? this.id,
      stockSymbol: stockSymbol ?? this.stockSymbol,
      stockName: stockName ?? this.stockName,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      entryPrice: entryPrice ?? this.entryPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      quantity: quantity ?? this.quantity,
      entryDate: entryDate ?? this.entryDate,
      exitDate: exitDate ?? this.exitDate,
      reason: reason ?? this.reason,
      strategy: strategy ?? this.strategy,
      lesson: lesson ?? this.lesson,
      result: result ?? this.result,
      analysisNotes: analysisNotes ?? this.analysisNotes,
      isClosed: isClosed ?? this.isClosed,
      market: market ?? this.market,
      accountTag: accountTag ?? this.accountTag,
      executions: executions ?? this.executions,
    );
  }

  /// Clears the account tag. `copyWith(accountTag: null)` keeps the old
  /// value because of the `??` fallback, so unassigning needs this.
  TradeEntry withAccountTag(String? tag) {
    return TradeEntry(
      id: id,
      stockSymbol: stockSymbol,
      stockName: stockName,
      type: type,
      direction: direction,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
      quantity: quantity,
      entryDate: entryDate,
      exitDate: exitDate,
      reason: reason,
      strategy: strategy,
      lesson: lesson,
      result: result,
      analysisNotes: analysisNotes,
      isClosed: isClosed,
      market: market,
      accountTag: tag,
      executions: executions,
    );
  }
}

class AnalysisNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final String category;

  AnalysisNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.category = 'general',
  });
}
