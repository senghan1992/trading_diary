import 'stock.dart';

enum TradeType { real, virtual }
enum TradeDirection { buy, sell }
/// `breakeven` covers the exitPrice == entryPrice case. It used to map to
/// `success` (which inflated the win-rate counter); it now sits alongside
/// success/failure so the win-rate denominator doesn't double-count.
enum TradeResult { success, failure, breakeven, pending }

class TradeEntry {
  final String id;
  final String stockSymbol;
  final String stockName;
  final TradeType type;
  final TradeDirection direction;
  final double entryPrice;
  final double? exitPrice;
  final int quantity;
  final DateTime entryDate;
  final DateTime? exitDate;
  final String? reason;
  final String? strategy;
  final String? lesson;
  final TradeResult result;
  final List<AnalysisNote> analysisNotes;
  final List<Reminder> reminders;
  final bool isClosed;

  /// Which market the trade's stock belongs to (KOSPI / KOSDAQ / NASDAQ).
  /// Drives the currency unit displayed in trade rows (₩ vs $) and the
  /// decimal precision (integer for won, 2dp for USD).
  ///
  /// Nullable on purpose: trades persisted before this field was added
  /// have no market stored. Callers should fall back to
  /// `inferMarketFromSymbol(stockSymbol)` when this is null so legacy
  /// trades still render with sensible units.
  final MarketType? market;

  TradeEntry({
    required this.id,
    required this.stockSymbol,
    required this.stockName,
    required this.type,
    required this.direction,
    required this.entryPrice,
    this.exitPrice,
    required this.quantity,
    required this.entryDate,
    this.exitDate,
    this.reason,
    this.strategy,
    this.lesson,
    this.result = TradeResult.pending,
    this.analysisNotes = const [],
    this.reminders = const [],
    this.isClosed = false,
    this.market,
  });

  double get profitLoss {
    if (!isClosed || exitPrice == null) return 0;
    if (direction == TradeDirection.buy) {
      return (exitPrice! - entryPrice) * quantity;
    } else {
      return (entryPrice - exitPrice!) * quantity;
    }
  }

  double get profitLossPercent {
    if (entryPrice == 0) return 0;
    if (!isClosed || exitPrice == null) return 0;
    if (direction == TradeDirection.buy) {
      return ((exitPrice! - entryPrice) / entryPrice) * 100;
    } else {
      return ((entryPrice - exitPrice!) / entryPrice) * 100;
    }
  }

  /// Unrealized P/L on an open position. Returns `null` because computing it
  /// requires the live current market price — the [TradeEntry] model has no
  /// way to fetch it. Callers (e.g. the detail screen) must look up the
  /// current price from `StockApiService` and pass it to whatever formula
  /// they implement.
  ///
  /// The previous version silently returned `0`, which could mislead callers
  /// into displaying `₩0` and the user into thinking there was no exposure.
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
    List<Reminder>? reminders,
    bool? isClosed,
    MarketType? market,
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
      reminders: reminders ?? this.reminders,
      isClosed: isClosed ?? this.isClosed,
      market: market ?? this.market,
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

class Reminder {
  final String id;
  final String title;
  final String? note;
  final DateTime remindAt;
  final bool isRead;
  /// Optional link back to the [TradeEntry] this reminder belongs to.
  /// Nullable because some reminders (e.g. generic review prompts) are
  /// not tied to any specific trade. When present, deleting the trade
  /// must also cancel the reminder (see TradeProvider.deleteTrade).
  final String? tradeId;

  Reminder({
    required this.id,
    required this.title,
    this.note,
    required this.remindAt,
    this.isRead = false,
    this.tradeId,
  });

  Reminder copyWith({bool? isRead, String? tradeId}) {
    return Reminder(
      id: id,
      title: title,
      note: note,
      remindAt: remindAt,
      isRead: isRead ?? this.isRead,
      tradeId: tradeId ?? this.tradeId,
    );
  }
}
