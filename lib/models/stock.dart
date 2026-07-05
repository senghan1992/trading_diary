enum MarketType { kospi, kosdaq, nasdaq }

class Stock {
  final String symbol;
  final String name;
  final String? nameKr;
  final MarketType market;
  final double currentPrice;
  final double changePrice;
  final double changePercent;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final double prevClose;
  final int volume;
  final bool isFavorite;

  Stock({
    required this.symbol,
    required this.name,
    this.nameKr,
    required this.market,
    required this.currentPrice,
    required this.changePrice,
    required this.changePercent,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.prevClose,
    required this.volume,
    this.isFavorite = false,
  });

  bool get isPositive => changePrice >= 0;

  Stock copyWith({
    String? symbol,
    String? name,
    String? nameKr,
    MarketType? market,
    double? currentPrice,
    double? changePrice,
    double? changePercent,
    double? openPrice,
    double? highPrice,
    double? lowPrice,
    double? prevClose,
    int? volume,
    bool? isFavorite,
  }) {
    return Stock(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      nameKr: nameKr ?? this.nameKr,
      market: market ?? this.market,
      currentPrice: currentPrice ?? this.currentPrice,
      changePrice: changePrice ?? this.changePrice,
      changePercent: changePercent ?? this.changePercent,
      openPrice: openPrice ?? this.openPrice,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      prevClose: prevClose ?? this.prevClose,
      volume: volume ?? this.volume,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class MarketIndex {
  final String name;
  final String symbol;
  final double currentPrice;
  final double changePrice;
  final double changePercent;

  MarketIndex({
    required this.name,
    required this.symbol,
    required this.currentPrice,
    required this.changePrice,
    required this.changePercent,
  });

  bool get isPositive => changePrice >= 0;
}

class DailyPrice {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  DailyPrice({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}
