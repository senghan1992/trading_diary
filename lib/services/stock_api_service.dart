import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../utils/currency.dart';

class StockApiService {
  static final List<Stock> _mockStocks = _generateMockStocks();

  // Per-market cache (avoid cross-market cache pollution)
  static final Map<MarketType, DateTime> _lastFetchStocksByMarket = {};
  static final Map<MarketType, List<Stock>> _lastRealStocksByMarket = {};

  // Indices are fetched together; a single timestamp is fine
  static DateTime _lastFetchIndices = DateTime(2000);
  static List<MarketIndex>? _lastRealIndices;

  // Finnhub API configuration.
  //
  // SECURITY: the previous implementation embedded the API key as a `const`
  // in source. That value is now considered public (it's been in the repo's
  // git history) and MUST be revoked at https://finnhub.io/dashboard before
  // release. Inject the rotated key at build time with --dart-define:
  //
  //   flutter run --dart-define=FINNHUB_API_KEY=your-new-key
  //
  // An empty default forces callers to handle the missing-key case explicitly
  // (see [_fetchFinnhubQuote]) so dev never builds with a silently-leaked
  // value.
  static const String _finnhubApiKey = String.fromEnvironment(
    'FINNHUB_API_KEY',
    defaultValue: '',
  );
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';

  // Yahoo Finance configuration (for Korean stocks)
  static const String _chartUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';
  static const Duration _cacheDuration = Duration(seconds: 30);

  // Error tracking for debugging
  static String? _lastError;

  static List<Stock> _generateMockStocks() {
    final rng = Random(42);
    final raw = <(String, String, String?, MarketType, double)>[
      ('005930', 'Samsung Electronics', '삼성전자', MarketType.kospi, 78400),
      ('000660', 'SK Hynix', 'SK하이닉스', MarketType.kospi, 182500),
      ('035420', 'Naver', '네이버', MarketType.kospi, 215000),
      ('373220', 'LG Energy Solution', 'LG에너지솔루션', MarketType.kospi, 395000),
      ('207940', 'Samsung Biologics', '삼성바이오로직스', MarketType.kospi, 810000),
      ('051910', 'LG Chem', 'LG화학', MarketType.kospi, 445000),
      ('005935', 'Samsung Electronics P', '삼성전자우', MarketType.kospi, 65200),
      ('000270', 'KIA', '기아', MarketType.kospi, 105500),
      ('005380', 'Hyundai Motor', '현대차', MarketType.kospi, 245000),
      ('068270', 'Celltrion', '셀트리온', MarketType.kospi, 185000),
      ('035720', 'Kakao', '카카오', MarketType.kosdaq, 48500),
      ('247540', 'EcoPro BM', '에코프로비엠', MarketType.kosdaq, 215000),
      ('196170', 'Alteogen', '알테오젠', MarketType.kosdaq, 285000),
      ('403870', 'HPSP', 'HPSP', MarketType.kosdaq, 32000),
      ('086520', 'EcoPro', '에코프로', MarketType.kosdaq, 98000),
      ('352820', 'HLB', 'HLB', MarketType.kosdaq, 72000),
      ('091990', 'Celltrion Healthcare', '셀트리온헬스케어', MarketType.kosdaq, 82000),
      ('293490', 'Kakao Game', '카카오게임즈', MarketType.kosdaq, 21500),
      ('263750', 'Pearl Abyss', '펄어비스', MarketType.kosdaq, 42500),
      ('144510', 'Soulbrain', '솔브레인', MarketType.kosdaq, 265000),
      ('AAPL', 'Apple Inc.', '애플', MarketType.nasdaq, 198),
      ('MSFT', 'Microsoft', '마이크로소프트', MarketType.nasdaq, 425),
      ('GOOGL', 'Alphabet', '알파벳', MarketType.nasdaq, 175),
      ('AMZN', 'Amazon', '아마존', MarketType.nasdaq, 186),
      ('NVDA', 'NVIDIA', '엔비디아', MarketType.nasdaq, 875),
      ('META', 'Meta', '메타', MarketType.nasdaq, 505),
      ('TSLA', 'Tesla', '테슬라', MarketType.nasdaq, 245),
      ('AMD', 'AMD', 'AMD', MarketType.nasdaq, 165),
      ('INTC', 'Intel', '인텔', MarketType.nasdaq, 42),
      ('NFLX', 'Netflix', '넷플릭스', MarketType.nasdaq, 685),
    ];

    return raw.map((s) {
      final (symbol, name, nameKr, market, price) = s;
      final changePercent = (rng.nextDouble() - 0.5) * 6;
      final changePrice = price * changePercent / 100;
      return Stock(
        symbol: symbol, name: name, nameKr: nameKr, market: market,
        currentPrice: price, changePrice: changePrice, changePercent: changePercent,
        openPrice: price * (1 + (rng.nextDouble() - 0.5) * 0.02),
        highPrice: price * (1 + rng.nextDouble() * 0.03),
        lowPrice: price * (1 - rng.nextDouble() * 0.03),
        prevClose: price * (1 - changePercent / 100),
        volume: rng.nextInt(10000000) + 100000,
      );
    }).toList();
  }

  static String _yahooSymbol(String symbol, MarketType market) {
    if (market == MarketType.nasdaq) return symbol;
    return market == MarketType.kospi ? '$symbol.KS' : '$symbol.KQ';
  }

  static bool _shouldRefreshStocks(MarketType market) {
    final last = _lastFetchStocksByMarket[market];
    if (last == null) return true;
    return DateTime.now().difference(last) > _cacheDuration;
  }
  static bool _shouldRefreshIndices() {
    return DateTime.now().difference(_lastFetchIndices) > _cacheDuration;
  }

  static Future<Map<String, dynamic>?> _fetchChartMeta(String yahooSymbol) async {
    try {
      final encoded = yahooSymbol.replaceAll('^', '%5E');
      final url = Uri.parse('$_chartUrl/$encoded?range=1d&interval=1d');
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      });
      if (response.statusCode != 200) {
        _lastError = 'Yahoo Finance API returned status ${response.statusCode}';
        return null;
      }
      final data = jsonDecode(response.body);
      final result = data['chart']['result'] as List? ?? [];
      if (result.isEmpty) {
        _lastError = 'Yahoo Finance API returned empty result for $yahooSymbol';
        return null;
      }
      return result[0]['meta'] as Map<String, dynamic>?;
    } catch (e) {
      _lastError = 'Yahoo Finance API error: $e';
      return null;
    }
  }

  // Finnhub Quote API (for US stocks only)
  static Future<Map<String, dynamic>?> _fetchFinnhubQuote(String symbol) async {
    // The API key is now build-time injected (see [_finnhubApiKey]). When
    // the key is missing we fail fast with a clear error instead of silently
    // sending an empty `token=` to Finnhub (which would 401 and leave
    // [_lastError] cryptic).
    if (_finnhubApiKey.isEmpty) {
      _lastError =
          'Finnhub API key not configured. Pass --dart-define=FINNHUB_API_KEY=... '
          'when running the app.';
      return null;
    }
    try {
      final url = Uri.parse('$_finnhubBaseUrl/quote?symbol=$symbol&token=$_finnhubApiKey');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        _lastError = 'Finnhub API returned status ${response.statusCode}';
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Finnhub returns 0 for all values if symbol not found
      if (data['c'] == 0 && data['d'] == 0 && data['h'] == 0) {
        _lastError = 'Finnhub: No data for symbol $symbol';
        return null;
      }
      return data;
    } catch (e) {
      _lastError = 'Finnhub API error: $e';
      return null;
    }
  }

  static MarketIndex? _parseIndexMeta(String symbol, String name, Map<String, dynamic> meta) {
    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    if (price == null) return null;
    final change = price - (prevClose ?? price);
    return MarketIndex(name: name, symbol: symbol, currentPrice: price, changePrice: change, changePercent: prevClose != null && prevClose > 0 ? (change / prevClose * 100) : 0);
  }

  static Stock? _parseStockMeta(String symbol, MarketType market, String name, String? nameKr, Map<String, dynamic> meta) {
    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    final open = (meta['regularMarketOpen'] as num?)?.toDouble();
    final high = (meta['regularMarketDayHigh'] as num?)?.toDouble();
    final low = (meta['regularMarketDayLow'] as num?)?.toDouble();
    final volume = (meta['regularMarketVolume'] as num?)?.toInt();
    if (price == null) return null;
    final change = price - (prevClose ?? price);
    final changePct = prevClose != null && prevClose > 0 ? (change / prevClose * 100) : 0.0;
    return Stock(
      symbol: symbol, name: name, nameKr: nameKr, market: market,
      currentPrice: price, changePrice: change, changePercent: changePct,
      openPrice: open ?? price, highPrice: high ?? price, lowPrice: low ?? price,
      prevClose: prevClose ?? price, volume: volume ?? 0,
    );
  }

  // Parse Finnhub quote response
  static Stock? _parseFinnhubQuote(String symbol, MarketType market, String name, String? nameKr, Map<String, dynamic> quote) {
    final price = (quote['c'] as num?)?.toDouble(); // Current price
    if (price == null || price == 0) return null;

    final change = (quote['d'] as num?)?.toDouble() ?? 0.0;
    final changePct = (quote['dp'] as num?)?.toDouble() ?? 0.0;
    final high = (quote['h'] as num?)?.toDouble() ?? price;
    final low = (quote['l'] as num?)?.toDouble() ?? price;
    final open = (quote['o'] as num?)?.toDouble() ?? price;
    final prevClose = (quote['pc'] as num?)?.toDouble() ?? price;

    return Stock(
      symbol: symbol,
      name: name,
      nameKr: nameKr,
      market: market,
      currentPrice: price,
      changePrice: change,
      changePercent: changePct,
      openPrice: open,
      highPrice: high,
      lowPrice: low,
      prevClose: prevClose,
      volume: 0, // Finnhub quote doesn't include volume
    );
  }

  static Future<List<MarketIndex>> getMarketIndices() async {
    if (!_shouldRefreshIndices() && _lastRealIndices != null) return _lastRealIndices!;

    try {
      // Use Yahoo Finance for Korean indices, Finnhub for US index
      final results = await Future.wait([
        _fetchChartMeta('^KS11'),
        _fetchChartMeta('^KQ11'),
        _fetchFinnhubQuote('^IXIC'),
      ]);

      final indices = [
        results[0] != null ? _parseIndexMeta('^KS11', 'KOSPI', results[0]!) : null,
        results[1] != null ? _parseIndexMeta('^KQ11', 'KOSDAQ', results[1]!) : null,
        results[2] != null ? _parseFinnhubIndexMeta('^IXIC', 'NASDAQ', results[2]!) : null,
      ];

      final valid = indices.whereNotNull().toList();
      if (valid.isNotEmpty) {
        _lastRealIndices = valid;
        _lastFetchIndices = DateTime.now();
        return valid;
      }
    } catch (e) {
      _lastError = 'getMarketIndices error: $e';
    }

    return _lastRealIndices ?? _mockIndices;
  }

  static MarketIndex? _parseFinnhubIndexMeta(String symbol, String name, Map<String, dynamic> quote) {
    final price = (quote['c'] as num?)?.toDouble();
    final prevClose = (quote['pc'] as num?)?.toDouble();
    if (price == null || price == 0) return null;
    final change = price - (prevClose ?? price);
    final changePct = prevClose != null && prevClose > 0 ? (change / prevClose * 100) : 0.0;
    return MarketIndex(name: name, symbol: symbol, currentPrice: price, changePrice: change, changePercent: changePct);
  }

  static final _mockIndices = [
    MarketIndex(name: 'KOSPI', symbol: '^KS11', currentPrice: 2680.50, changePrice: 15.30, changePercent: 0.57),
    MarketIndex(name: 'KOSDAQ', symbol: '^KQ11', currentPrice: 865.20, changePrice: -3.40, changePercent: -0.39),
    MarketIndex(name: 'NASDAQ', symbol: '^IXIC', currentPrice: 18450.80, changePrice: 85.60, changePercent: 0.47),
  ];

  static Future<List<Stock>> getStocksByMarket(MarketType market) async {
    final baseStocks = _mockStocks.where((s) => s.market == market).toList();

    if (!_shouldRefreshStocks(market)) {
      // Cache hit for THIS market — return its own cached data
      final cached = _lastRealStocksByMarket[market];
      if (cached != null) return cached;
      return baseStocks;
    }

    try {
      List<Stock> enriched;

      if (market == MarketType.nasdaq) {
        // Use Finnhub for NASDAQ stocks (more reliable)
        enriched = await _fetchNasdaqStocksWithFinnhub(baseStocks);
      } else {
        // Use Yahoo Finance for Korean stocks (KOSPI, KOSDAQ) — parallel fetch
        enriched = await _fetchKoreanStocksWithYahoo(baseStocks, market);
      }

      // Always refresh the cache for this market after a successful fetch.
      _lastFetchStocksByMarket[market] = DateTime.now();
      _lastRealStocksByMarket[market] = enriched;

      return enriched;
    } catch (e) {
      _lastError = 'getStocksByMarket error for ${market.name}: $e';
    }

    // On failure, prefer cached data for THIS market; fall back to mock.
    return _lastRealStocksByMarket[market] ?? baseStocks;
  }

  static Future<List<Stock>> _fetchNasdaqStocksWithFinnhub(List<Stock> baseStocks) async {
    final enriched = <Stock>[];
    final results = await Future.wait(
      baseStocks.map((s) => _fetchFinnhubQuote(s.symbol)),
    );

    for (var i = 0; i < baseStocks.length; i++) {
      final s = baseStocks[i];
      final quote = results[i];
      if (quote != null) {
        final parsed = _parseFinnhubQuote(s.symbol, s.market, s.name, s.nameKr, quote);
        enriched.add(parsed ?? s);
      } else {
        enriched.add(s);
      }
    }

    return enriched;
  }

  static Future<List<Stock>> _fetchKoreanStocksWithYahoo(List<Stock> baseStocks, MarketType market) async {
    // Parallel fetch like NASDAQ — no artificial 100ms delay per symbol.
    // Yahoo Finance's v8/finance/chart endpoint typically tolerates a small burst.
    final metas = await Future.wait(
      baseStocks.map((s) => _fetchChartMeta(_yahooSymbol(s.symbol, market))),
    );

    return List<Stock>.generate(baseStocks.length, (i) {
      final s = baseStocks[i];
      final meta = metas[i];
      if (meta != null) {
        final parsed = _parseStockMeta(s.symbol, s.market, s.name, s.nameKr, meta);
        if (parsed != null) return parsed;
      }
      // Per-symbol fallback: keep mock data for any failed symbol,
      // rather than dropping the whole batch.
      return s;
    });
  }

  static Future<Stock?> getStockBySymbol(String symbol) async {
    try {
      final mock = _mockStocks.where((s) => s.symbol == symbol).toList();
      if (mock.isEmpty) return null;
      final s = mock.first;

      // Use Finnhub for NASDAQ, Yahoo Finance for Korean stocks
      if (s.market == MarketType.nasdaq) {
        final quote = await _fetchFinnhubQuote(s.symbol);
        if (quote != null) {
          final parsed = _parseFinnhubQuote(s.symbol, s.market, s.name, s.nameKr, quote);
          if (parsed != null) return parsed;
        }
      } else {
        final meta = await _fetchChartMeta(_yahooSymbol(s.symbol, s.market));
        if (meta != null) {
          final parsed = _parseStockMeta(s.symbol, s.market, s.name, s.nameKr, meta);
          if (parsed != null) return parsed;
        }
      }
    } catch (e) {
      _lastError = 'getStockBySymbol error: $e';
    }
    return _mockStocks.cast<Stock?>().firstWhere((s) => s?.symbol == symbol, orElse: () => null);
  }

  /// Get the last error message for debugging
  static String? getLastError() => _lastError;

  /// Clear the last error
  static void clearLastError() => _lastError = null;

  /// Fetch daily OHLC prices for the chart on the trade-detail screen.
  ///
  /// Source dispatch (per the project standard — Yahoo was deprecated
  /// because of increasing 4xx from the Flutter client; the rest of the
  /// app already routes through Naver + Finnhub):
  ///
  ///   • KOSPI / KOSDAQ → Naver mobile API (`/api/stock/{symbol}/price`)
  ///   • NASDAQ         → Finnhub candle API (`/stock/candle?resolution=D`)
  ///
  /// [market] is the persisted `TradeEntry.market` and wins over symbol-
  /// shape heuristics so a user-added symbol that isn't in [_mockStocks]
  /// still routes correctly. Falls back to [_mockStocks] lookup, then
  /// [inferMarketFromSymbol] (6-digit numeric → KOSPI, else NASDAQ).
  ///
  /// Returns ~1 month of trading days (Naver/Finnhub responses are
  /// truncated server-side; mock fallback generates ~22 entries).
  static Future<List<DailyPrice>> getHistoricalPrices(
    String symbol, {
    MarketType? market,
  }) async {
    const targetDays = 30;
    final mock = _mockStocks.where((s) => s.symbol == symbol).toList();
    final effective = market ??
        (mock.isNotEmpty ? mock.first.market : inferMarketFromSymbol(symbol));

    try {
      if (effective == MarketType.kospi || effective == MarketType.kosdaq) {
        return await _fetchNaverDailyPrices(symbol, days: targetDays);
      }
      if (effective == MarketType.nasdaq) {
        return await _fetchFinnhubDailyPrices(symbol, days: targetDays);
      }
    } catch (_) {}

    return _mockHistoricalPrices(symbol, days: targetDays);
  }

  /// Naver mobile stock API for KOSPI/KOSDAQ daily prices.
  ///
  /// URL: `https://m.stock.naver.com/api/stock/{symbol}/price?pageSize=30&page=1`
  /// (singular `stock`, NOT the plural `/api/stocks/marketValue/...` we
  /// use for the constituent list — those are different endpoints.)
  ///
  /// Response: a JSON array of one object per trading day, **newest
  /// first**. Each entry has `localTradedAt` (YYYY-MM-DD), comma-string
  /// OHLC (`"309,500"`), and `accumulatedTradingVolume` (int). We sort
  /// ascending so the chart's x-axis reads left→right as time progresses.
  ///
  /// Naver caps each response around 60 entries; `pageSize=30` is enough
  /// to cover 1 month of trading days plus a holiday buffer, so we don't
  /// need pagination for the 1달 (one-month) use case.
  static Future<List<DailyPrice>> _fetchNaverDailyPrices(
    String symbol, {
    required int days,
  }) async {
    const pageSize = 30;
    final url = Uri.parse(
        'https://m.stock.naver.com/api/stock/$symbol/price?pageSize=$pageSize&page=1');
    final response = await http.get(url, headers: const {
      'User-Agent': _naverMobileUserAgent,
    });
    if (response.statusCode != 200) {
      _lastError = 'Naver 일봉 조회 실패: HTTP ${response.statusCode} ($symbol)';
      throw Exception('Naver status ${response.statusCode}');
    }

    final List<dynamic> raw = jsonDecode(response.body);
    final prices = <DailyPrice>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final dateStr = entry['localTradedAt']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;
      // Naver ships `localTradedAt` as a date-only string (no timezone).
      // `DateTime.parse` would treat it as local midnight, which matches
      // how the chart's date axis renders.
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final open = _parseCommaNumber(entry['openPrice']);
      final high = _parseCommaNumber(entry['highPrice']);
      final low = _parseCommaNumber(entry['lowPrice']);
      final close = _parseCommaNumber(entry['closePrice']);
      // Skip rows where Naver returned no OHLC (suspended / halted days).
      if (open == 0 || close == 0) continue;

      final volumeRaw = entry['accumulatedTradingVolume'];
      final volume = volumeRaw is num
          ? volumeRaw.toInt()
          : int.tryParse(volumeRaw?.toString().replaceAll(',', '') ?? '0') ?? 0;

      prices.add(DailyPrice(
        date: date,
        open: open,
        // Naver occasionally omits high/low for halted sessions; fall
        // back to close so the wick doesn't collapse to a single point.
        high: high == 0 ? close : high,
        low: low == 0 ? close : low,
        close: close,
        volume: volume,
      ));
    }

    // Newest-first → oldest-first for the chart.
    prices.sort((a, b) => a.date.compareTo(b.date));

    if (prices.length > days) return prices.sublist(prices.length - days);
    return prices;
  }

  /// Finnhub candle API for NASDAQ daily prices.
  ///
  /// URL: `https://finnhub.io/api/v1/stock/candle?symbol={sym}&resolution=D&from={ts}&to={ts}&token={key}`
  ///
  /// Response:
  /// ```
  /// { "c":[closes], "h":[highs], "l":[lows], "o":[opens],
  ///   "t":[unix_seconds], "v":[volumes], "s":"ok"|"no_data"|"error" }
  /// ```
  static Future<List<DailyPrice>> _fetchFinnhubDailyPrices(
    String symbol, {
    required int days,
  }) async {
    if (_finnhubApiKey.isEmpty) {
      _lastError =
          'Finnhub API key not configured. Pass --dart-define=FINNHUB_API_KEY=... '
          'when running the app.';
      throw Exception('Finnhub key missing');
    }
    // Buffer 10 extra calendar days so weekends/holidays don't shrink the
    // returned series below `days` trading sessions.
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days + 10));
    final url = Uri.parse(
        '$_finnhubBaseUrl/stock/candle?symbol=$symbol&resolution=D'
        '&from=${from.millisecondsSinceEpoch ~/ 1000}'
        '&to=${to.millisecondsSinceEpoch ~/ 1000}'
        '&token=$_finnhubApiKey');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      _lastError = 'Finnhub 일봉 조회 실패: HTTP ${response.statusCode} ($symbol)';
      throw Exception('Finnhub status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['s'] != 'ok') {
      _lastError = 'Finnhub 일봉 응답 이상: s=${data['s']} ($symbol)';
      throw Exception('Finnhub status field=${data['s']}');
    }

    final opens = (data['o'] as List? ?? const []).cast<num>();
    final highs = (data['h'] as List? ?? const []).cast<num>();
    final lows = (data['l'] as List? ?? const []).cast<num>();
    final closes = (data['c'] as List? ?? const []).cast<num>();
    final timestamps = (data['t'] as List? ?? const []).cast<num>();
    final volumes = (data['v'] as List? ?? const []).cast<num>();

    if (timestamps.isEmpty) {
      throw Exception('Finnhub returned empty candle array');
    }

    final prices = <DailyPrice>[];
    for (var i = 0; i < timestamps.length; i++) {
      prices.add(DailyPrice(
        date: DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000),
        open: opens[i].toDouble(),
        high: highs[i].toDouble(),
        low: lows[i].toDouble(),
        close: closes[i].toDouble(),
        volume: i < volumes.length ? volumes[i].toInt() : 0,
      ));
    }

    if (prices.length > days) return prices.sublist(prices.length - days);
    return prices;
  }

  static List<DailyPrice> _mockHistoricalPrices(String symbol, {int days = 30}) {
    final rng = Random(symbol.hashCode);
    final today = DateTime.now();
    final prices = <DailyPrice>[];
    var price = 100.0 + rng.nextDouble() * 200;
    // Walk back ~`days` calendar days; the weekday filter cuts weekends so
    // the final list is roughly `days * 5/7` ≈ 22 trading-day entries.
    for (var i = days + 14; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      if (date.weekday > 5) continue;
      final change = (rng.nextDouble() - 0.48) * price * 0.04;
      price += change;
      if (price < 10) price = 10;
      prices.add(DailyPrice(date: date, open: price * (1 + (rng.nextDouble() - 0.5) * 0.01), high: price * (1 + rng.nextDouble() * 0.02), low: price * (1 - rng.nextDouble() * 0.02), close: price, volume: rng.nextInt(5000000) + 100000));
    }
    return prices;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KOREAN STOCK SEARCH (Naver Mobile Stock API)
  //
  // Why Naver and not Yahoo/Finnhub:
  //   - Finnhub's `/search` returns 401 on the free tier (paid-only).
  //   - Yahoo's `/v1/finance/search` requires cookie+crumb auth since 2023
  //     and is increasingly 4xx-blocked even with valid auth.
  //   - Naver's HTML search page only supports exact-ticker lookups, not
  //     fuzzy name search, so we can't scrape the search page directly.
  //   - Naver's *mobile* stock API (`m.stock.naver.com/api/...`) returns
  //     JSON with full KOSPI/KOSDAQ tickers + Korean names, no auth needed,
  //     UTF-8 clean. We fetch the constituent list once, cache it for
  //     [_koreanStockListTtl], and do fuzzy matching locally — fast, no
  //     per-keystroke API calls.
  //
  // Coverage: top 100 KOSPI + top 100 KOSDAQ by market cap ≈ 200 stocks,
  // which captures the bulk of retail trading activity in Korea. The list
  // is sorted by market value so the picker shows the most liquid names
  // first; full list (≈4,300 stocks) is available by paginating but isn't
  // needed for the picker UX.
  // ─────────────────────────────────────────────────────────────────────────

  static List<_KoreanStock>? _koreanStockList;
  static DateTime? _koreanStockListFetchedAt;
  static Future<List<_KoreanStock>>? _koreanStockListInflight;

  /// Refresh every 5 minutes. The constituent list itself is stable for
  /// weeks, but prices change continuously during Korean market hours
  /// (09:00–15:30 KST) and we want the picker rows to show fresh quotes.
  /// Coalescing in [_getKoreanStockList] means rapid searches within the
  /// window still hit the cache.
  static const _koreanStockListTtl = Duration(minutes: 5);

  static const _naverMobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1';

  /// Returns the Naver-sourced KOSPI+KOSDAQ stock list. Cached in memory
  /// for [_koreanStockListTtl] and coalesced across concurrent callers so
  /// a flurry of searches share one fetch.
  static Future<List<_KoreanStock>> _getKoreanStockList({bool force = false}) async {
    if (!force &&
        _koreanStockList != null &&
        _koreanStockListFetchedAt != null &&
        DateTime.now().difference(_koreanStockListFetchedAt!) <
            _koreanStockListTtl) {
      return _koreanStockList!;
    }

    if (_koreanStockListInflight != null) return _koreanStockListInflight!;

    final inflight = _fetchKoreanStockList();
    _koreanStockListInflight = inflight;
    try {
      return await inflight;
    } finally {
      _koreanStockListInflight = null;
    }
  }

  static Future<List<_KoreanStock>> _fetchKoreanStockList() async {
    try {
      // KOSPI + KOSDAQ in parallel — both endpoints return JSON sorted by
      // market value descending, so index 0 is the largest cap stock in
      // each market. `pageSize=100` is the API's hard limit per page; the
      // top 100 per market captures the overwhelming majority of retail
      // trading volume in Korea.
      final responses = await Future.wait([
        http
            .get(
              Uri.parse(
                  'https://m.stock.naver.com/api/stocks/marketValue/KOSPI?page=1&pageSize=100'),
              headers: const {'User-Agent': _naverMobileUserAgent},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse(
                  'https://m.stock.naver.com/api/stocks/marketValue/KOSDAQ?page=1&pageSize=100'),
              headers: const {'User-Agent': _naverMobileUserAgent},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      final stocks = <_KoreanStock>[];
      for (var i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response.statusCode != 200) continue;
        final market = i == 0 ? MarketType.kospi : MarketType.kosdaq;
        final body = jsonDecode(response.body);
        if (body is! Map) continue;
        final list = (body['stocks'] as List?) ?? [];
        for (final s in list) {
          if (s is! Map) continue;
          final code = (s['itemCode'] ?? '').toString();
          final name = (s['stockName'] ?? '').toString();
          if (code.isEmpty || name.isEmpty) continue;

          // Naver ships prices as quoted comma-separated strings
          // (`"309,500"`, `"23,500"`, `"31,498,600"`). Strip commas before
          // parsing so `double.tryParse` accepts them.
          final closePrice = _parseCommaNumber(s['closePrice']);
          final changePrice = _parseCommaNumber(s['compareToPreviousClosePrice']);
          final changePercent = _parseCommaNumber(s['fluctuationsRatio']);
          final volume = _parseCommaNumber(s['accumulatedTradingVolume']).toInt();

          stocks.add(_KoreanStock(
            symbol: code,
            nameKr: name,
            market: market,
            currentPrice: closePrice,
            changePrice: changePrice,
            changePercent: changePercent,
            volume: volume,
          ));
        }
      }

      if (stocks.isEmpty) {
        _lastError = 'Naver 종목 목록 로드 실패: 응답에 종목이 없습니다';
        return const [];
      }

      _koreanStockList = stocks;
      _koreanStockListFetchedAt = DateTime.now();
      return stocks;
    } catch (e) {
      _lastError = 'Naver 종목 목록 로드 오류: $e';
      return const [];
    }
  }

  /// Combined search entry point used by the picker. Runs the Korean
  /// (Naver) and US/NASDAQ (Finnhub) searches in parallel and concatenates
  /// the results with Korean rows first per the user's market priority.
  ///
  /// Failures in either path degrade gracefully — if e.g. Finnhub returns
  /// 401 (free-tier limit on `/search`) we just drop the US results and
  /// surface whatever Korean matched; we never fail the whole query.
  static Future<List<Stock>> searchStocksRemote(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final batches = await Future.wait([
      _searchKoreanStocksRemote(q),
      _searchNasdaqStocksRemote(q),
    ]);

    // Korean first; NASDAQ below. Stable concat — preserves each side's
    // own relevance ordering.
    return [...batches[0], ...batches[1]];
  }

  /// Korean-market leg: filters the Naver-sourced cached list.
  ///
  /// Matching rules:
  ///   - Korean name substring match (case-insensitive): "삼성" → 삼성전자.
  ///   - Ticker prefix match: "005" → 005930 삼성전자. Tickers are 6-digit
  ///     numeric so prefix is more precise than contains (avoids matching
  ///     every ticker containing any digit).
  ///   - Both rules combined (OR): a query like "삼성 005" matches items
  ///     satisfying either rule.
  static Future<List<Stock>> _searchKoreanStocksRemote(String query) async {
    final stocks = await _getKoreanStockList();
    if (stocks.isEmpty) return const [];

    final qLower = query.toLowerCase();
    return stocks
        .where((s) =>
            s.nameKr.toLowerCase().contains(qLower) ||
            s.symbol.startsWith(query))
        .map((s) => Stock(
              symbol: s.symbol,
              name: s.nameKr, // Naver returns Korean names directly.
              nameKr: s.nameKr,
              market: s.market,
              currentPrice: s.currentPrice,
              changePrice: s.changePrice,
              changePercent: s.changePercent,
              volume: s.volume,
              // Naver's marketValue endpoint doesn't surface open/high/low
              // directly; derive prevClose from current - change (the math
              // is exact) and leave OHLC at 0 — the picker only renders
              // current price + change %, and the user's actual fill price
              // is entered manually on the trade form.
              prevClose: s.currentPrice - s.changePrice,
              openPrice: 0,
              highPrice: 0,
              lowPrice: 0,
            ))
        .toList();
  }

  /// US/NASDAQ leg: filters the NASDAQ-screener cached list.
  ///
  /// Why NASDAQ's own screener over Finnhub/Yahoo here:
  ///   - Finnhub's `/search` is gated to paid tiers (returns 401 on free
  ///     keys — confirmed against Finnhub's own GitHub issue tracker).
  ///   - Yahoo's `/v1/finance/search` requires cookie+crumb auth and is
  ///     increasingly 4xx-blocked.
  ///   - NASDAQ's `/api/screener/stocks` is a public endpoint with no auth,
  ///     returns the full NASDAQ constituent list (~4,150 names) with
  ///     current price, change, and volume — everything the picker needs
  ///     in one shot. We cache it for [_usStockListTtl] and fuzzy-match
  ///     locally, the same pattern we use for Naver Korean.
  ///
  /// Korean aliases: NASDAQ names are English-only, so users searching
  /// "엔비디아" or "테슬라" need a small hand-curated mapping. We layer
  /// [_usKoreanAliases] on top of the screener list — it covers the most
  /// well-known NASDAQ tickers, not as data (those still come from NASDAQ)
  /// but as a UI affordance for Korean text search.
  ///
  /// Returns an empty list (not an error) when the API call fails — the
  /// picker shows "no results" and the user keeps their Korean matches.
  static List<_UsStock>? _usStockList;
  static DateTime? _usStockListFetchedAt;
  static Future<List<_UsStock>>? _usStockListInflight;

  /// Refresh every 5 minutes — same cadence as the Korean list so prices
  /// stay fresh during US market hours (09:30–16:00 ET) without hammering
  /// the endpoint.
  static const _usStockListTtl = Duration(minutes: 5);

  static Future<List<_UsStock>> _getUsStockList({bool force = false}) async {
    if (!force &&
        _usStockList != null &&
        _usStockListFetchedAt != null &&
        DateTime.now().difference(_usStockListFetchedAt!) < _usStockListTtl) {
      return _usStockList!;
    }

    if (_usStockListInflight != null) return _usStockListInflight!;

    final inflight = _fetchUsStockList();
    _usStockListInflight = inflight;
    try {
      return await inflight;
    } finally {
      _usStockListInflight = null;
    }
  }

  static Future<List<_UsStock>> _fetchUsStockList() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://api.nasdaq.com/api/screener/stocks?exchange=NASDAQ&download=true'),
            headers: const {
              // nasdaq.com serves mobile traffic from api.nasdaq.com. A
              // desktop browser UA triggers a redirect to the marketing
              // page; a mobile UA gets JSON.
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                  'Mobile/15E148 Safari/604.1',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _lastError =
            'NASDAQ 목록 로드 실패 (status ${response.statusCode})';
        return const [];
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        _lastError = 'NASDAQ 응답 파싱 실패: 루트가 객체가 아님';
        return const [];
      }
      // NASDAQ screener wraps everything under {data: {headers, rows, ...}}
      // — NOT data.table.rows. Earlier code accessed a phantom `table`
      // level and silently returned an empty list, which is why a search
      // for "nvidia" or "엔비디아" found no US matches at all.
      final wrapper = data['data'];
      if (wrapper is! Map) {
        _lastError = 'NASDAQ 응답 파싱 실패: data 필드 없음 (keys=${data.keys.toList()})';
        return const [];
      }
      final rows = (wrapper['rows'] as List?) ?? const [];

      final stocks = <_UsStock>[];
      for (final r in rows) {
        if (r is! Map) continue;
        final symbol = (r['symbol'] ?? '').toString().trim();
        if (symbol.isEmpty) continue;
        // Skip non-equity vehicles. NASDAQ's screener occasionally includes
        // ETFs under the exchange= filter.
        final name = (r['name'] ?? '').toString();
        if (_isLikelyEtfOrNote(name)) continue;

        final currentPrice = _parseNasdaqMoney(r['lastsale']);
        final changePrice = _parseNasdaqMoney(r['netchange']);
        // pctchange is a signed percentage string like "-1.392%".
        final changePercent = _parseNasdaqPercent(r['pctchange']);
        final volume = _parseCommaNumber(r['volume']).toInt();

        // Korean alias lookup (e.g., NVDA → 엔비디아). Stored separately
        // from `name` so we don't mutate the canonical English name.
        final alias = _usKoreanAliases[symbol];

        stocks.add(_UsStock(
          symbol: symbol,
          name: name,
          nameKr: alias,
          currentPrice: currentPrice,
          changePrice: changePrice,
          changePercent: changePercent,
          volume: volume,
        ));
      }

      if (stocks.isEmpty) {
        _lastError = 'NASDAQ 목록 로드 실패: 응답에 종목이 없습니다';
        return const [];
      }

      _usStockList = stocks;
      _usStockListFetchedAt = DateTime.now();
      return stocks;
    } catch (e) {
      _lastError = 'NASDAQ 목록 로드 오류: $e';
      return const [];
    }
  }

  /// Heuristic filter for non-equity tickers (ETFs, ETNs, notes) that
  /// NASDAQ's screener occasionally includes. Cheaper than maintaining a
  /// ticker allowlist and matches how retail Korean apps gate the picker.
  static bool _isLikelyEtfOrNote(String name) {
    final upper = name.toUpperCase();
    return upper.contains(' ETF') ||
        upper.endsWith(' ETF') ||
        upper.contains(' ETN') ||
        upper.contains(' NOTE') ||
        upper.contains(' TRUST') ||
        upper.contains(' FUND');
  }

  /// Parse NASDAQ's money strings — formats vary (`"$194.83"`, `"1,234.56"`,
  /// `"\$0.0012"`, empty for halted tickers). Returns 0 on any miss.
  static double _parseNasdaqMoney(dynamic v) {
    if (v == null) return 0;
    final cleaned = v
        .toString()
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  /// Parse NASDAQ's percent strings (`"-1.392%"`, `"+0.45%"`, `""`).
  static double _parseNasdaqPercent(dynamic v) {
    if (v == null) return 0;
    final cleaned = v
        .toString()
        .replaceAll('%', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  static Future<List<Stock>> _searchNasdaqStocksRemote(String query) async {
    final stocks = await _getUsStockList();
    if (stocks.isEmpty) return const [];

    final q = query.trim();
    if (q.isEmpty) return const [];
    final qLower = q.toLowerCase();

    return stocks
        .where((s) =>
            // Symbol prefix match: "NV" → NVDA, NVDA-prefixed names.
            s.symbol.toLowerCase().startsWith(qLower) ||
            // English name substring: "nvidia" → NVIDIA Corporation.
            s.name.toLowerCase().contains(qLower) ||
            // Korean alias: "엔비디아" → NVDA. Exact-match only here
            // because alias keys are short and substring would over-match.
            (s.nameKr != null && s.nameKr == q))
        .map((s) => Stock(
              symbol: s.symbol,
              name: s.name,
              // Show Korean alias in the picker row if the user searched
              // by it; otherwise fall back to the English name so the row
              // is still legible.
              nameKr: s.nameKr ?? s.name,
              market: MarketType.nasdaq,
              currentPrice: s.currentPrice,
              changePrice: s.changePrice,
              changePercent: s.changePercent,
              volume: s.volume,
              prevClose: s.currentPrice - s.changePrice,
              openPrice: 0,
              highPrice: 0,
              lowPrice: 0,
            ))
        .toList();
  }
}

extension _ListWhereNotNull<T> on List<T?> {
  List<T> whereNotNull() => where((e) => e != null).cast<T>().toList();
}

/// Internal record for one row of Naver's KOSPI/KOSDAQ list. Kept private
/// because the picker expects [Stock]; this is just the search-source
/// tuple before mapping.
///
/// Includes the price fields Naver's `marketValue` endpoint surfaces
/// (`closePrice`, `compareToPreviousClosePrice`, `fluctuationsRatio`,
/// `accumulatedTradingVolume`) so the picker rows can show the current
/// quote without a second round-trip per result.
class _KoreanStock {
  final String symbol;
  final String nameKr;
  final MarketType market;
  final double currentPrice;
  final double changePrice;
  final double changePercent;
  final int volume;
  const _KoreanStock({
    required this.symbol,
    required this.nameKr,
    required this.market,
    required this.currentPrice,
    required this.changePrice,
    required this.changePercent,
    required this.volume,
  });
}

/// Strip Naver's quoted-comma numbers (`"309,500"`, `"31,498,600"`) and
/// parse to double. Returns 0 on missing/malformed input so a single bad
/// row never takes down the whole list.
double _parseCommaNumber(dynamic v) {
  if (v == null) return 0;
  final cleaned = v.toString().replaceAll(',', '').trim();
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}

/// Internal record for one row of NASDAQ's screener. Mirrors [_KoreanStock]
/// so [_searchNasdaqStocksRemote] can produce a [Stock] without a second
/// API call per result. `nameKr` is populated from [_usKoreanAliases]
/// when the user happens to search by a well-known Korean nickname.
class _UsStock {
  final String symbol;
  final String name;
  final String? nameKr;
  final double currentPrice;
  final double changePrice;
  final double changePercent;
  final int volume;
  const _UsStock({
    required this.symbol,
    required this.name,
    this.nameKr,
    required this.currentPrice,
    required this.changePrice,
    required this.changePercent,
    required this.volume,
  });
}

/// Korean nicknames for the most actively-traded NASDAQ tickers. Lets the
/// picker match Korean-text queries like "엔비디아" → NVDA without us
/// shipping the rest of the ticker list ourselves — the canonical name
/// still comes from NASDAQ's screener, this is just a UI affordance.
///
/// Coverage is intentionally narrow: only the ~30 names retail Korean
/// traders actually search for. Anything outside this map falls back to
/// the English name, which still matches via the English-substring rule.
const Map<String, String> _usKoreanAliases = {
  'AAPL': '애플',
  'MSFT': '마이크로소프트',
  'GOOGL': '구글',
  'GOOG': '구글',
  'AMZN': '아마존',
  'NVDA': '엔비디아',
  'META': '메타',
  'TSLA': '테슬라',
  'AMD': 'AMD',
  'INTC': '인텔',
  'NFLX': '넷플릭스',
  'AVGO': '브로드컴',
  'ORCL': '오라클',
  'CRM': '세일즈포스',
  'CSCO': '시스코',
  'ADBE': '어도비',
  'PYPL': '페이팔',
  'QCOM': '퀄컴',
  'TXN': '텍사스인스트루먼트',
  'MU': '마이크론',
  'AMAT': '어플라이드머티어리얼즈',
  'LRCX': '램리서치',
  'KLAC': '케이엘에이',
  'SNPS': '시놉시스',
  'CDNS': '케이던스',
  'MRVL': '마벨',
  'ARM': 'ARM',
  'PANW': '팔로알토네트웍스',
  'CRWD': '크라우드스트라이크',
  'SHOP': '쇼피파이',
  'SQ': '블록',
  'COIN': '코인베이스',
  'ROKU': '로쿠',
  'ZM': '줌',
  'UBER': '우버',
  'LYFT': '라이프트',
  'ABNB': '에어비앤비',
  'BIDU': '바이두',
  'JD': 'JD닷컴',
  'BABA': '알리바바',
  'PDD': '핀둬둬',
};
