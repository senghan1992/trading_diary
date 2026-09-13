import '../utils/hangul_util.dart';

/// Which market a traded stock belongs to.
///
/// Drives the currency unit and decimal precision used when rendering
/// prices in trade rows (integer won for KOSPI/KOSDAQ, 2dp USD for NASDAQ).
/// Nullable usages (`MarketType?`) mean the market was not specified —
/// including trades filed under the "기타/가상자산" bucket. Display sites
/// fall back to `inferMarketFromSymbol` (see `lib/utils/currency.dart`)
/// for legacy entries without a stored market.
enum MarketType { kospi, kosdaq, nasdaq }

/// Represents an individual stock or asset for autocomplete and market mapping.
class StockItem {
  final String code;
  final String name;
  final MarketType market;
  final String chosung;
  final String decomposed;

  StockItem({
    required this.code,
    required this.name,
    required this.market,
    String? chosung,
    String? decomposed,
  })  : chosung = chosung ?? HangulUtil.extractChosung(name),
        decomposed = decomposed ?? HangulUtil.decompose(name);

  factory StockItem.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    return StockItem(
      code: (json['code'] as String? ?? '').trim(),
      name: name,
      market: _parseMarket(json['market']),
      chosung: json['chosung'] as String?,
      decomposed: json['decomposed'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'market': market.name,
        'chosung': chosung,
      };

  /// Matches against query by code, name, Korean initial consonant (chosung),
  /// or decomposed Jamo sequence (supporting typing-in-progress states).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    // 1. Check code prefix or inclusion
    if (code.toLowerCase().contains(q)) return true;

    // 2. Multi-angle Korean and text matching
    return HangulUtil.matches(
      name,
      q,
      targetChosung: chosung,
      targetDecomposed: decomposed,
    );
  }

  static MarketType _parseMarket(dynamic market) {
    if (market is String) {
      final lower = market.trim().toLowerCase();
      if (lower == 'kosdaq' || lower.contains('kq')) return MarketType.kosdaq;
      if (lower == 'nasdaq' || lower.contains('nas') || lower == 'us') return MarketType.nasdaq;
      return MarketType.kospi;
    }
    return MarketType.kospi;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockItem &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          market == other.market;

  @override
  int get hashCode => code.hashCode ^ market.hashCode;
}
