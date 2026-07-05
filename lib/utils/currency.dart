import 'package:intl/intl.dart';
import '../models/stock.dart';

/// Locale-aware money formatting for trade display.
///
/// Korean markets (KOSPI/KOSDAQ) are won-denominated and quoted in integer
/// units — `₩309,500`. NASDAQ is USD with sub-dollar precision common —
/// `$194.83`. Symbols and decimals diverge enough that the right one has
/// to be picked at the call site, which is what this module exists for.
///
/// [formatTradeMoney] is the primary entry point. [currencySymbolFor] and
/// [numberFormatFor] are exposed separately when the caller needs just
/// the prefix or suffix (e.g. an `InputDecoration.prefixText`).

/// Returns the symbol that prefixes the price for the given market.
/// Defaults to `₩` when [market] is null so legacy trades (saved before
/// the market field was persisted) still render with sensible units.
String currencySymbolFor(MarketType? market) {
  switch (market) {
    case MarketType.kospi:
    case MarketType.kosdaq:
      return '₩';
    case MarketType.nasdaq:
      return r'$';
    case null:
      return '₩';
  }
}

/// Returns the integer/decimal format that matches the market's quoting
/// convention. Defaults to the Korean `#,##0` pattern for null.
NumberFormat numberFormatFor(MarketType? market) =>
    market == MarketType.nasdaq ? _usdFmt : _krwFmt;

// NumberFormat construction is cheap but called on every list-item rebuild,
// so we cache one per market.
final NumberFormat _krwFmt = NumberFormat('#,##0');
final NumberFormat _usdFmt = NumberFormat('#,##0.00');

/// Compose symbol + number into a single display string.
///   formatTradeMoney(309500, MarketType.kospi)  →  "₩309,500"
///   formatTradeMoney(194.83, MarketType.nasdaq) →  "$194.83"
String formatTradeMoney(double amount, MarketType? market) {
  return '${currencySymbolFor(market)}${numberFormatFor(market).format(amount)}';
}

/// Best-effort market inference from a stock symbol, used as a display-
/// fallback for trades saved before the `market` field was persisted.
///
///   - 6-digit numeric → Korean (defaults to KOSPI; we can't tell KOSPI
///     vs KOSDAQ from the symbol alone, and the visual difference is nil
///     — both render as ₩).
///   - any other non-empty symbol (alphabetic, contains letters) → NASDAQ.
///   - null/empty → null (caller decides what default to use).
///
/// This is a *display* helper only — the inferred market is never written
/// back into storage. The stored `market` field on TradeEntry stays null
/// for legacy trades; this function fills in the display gap.
MarketType? inferMarketFromSymbol(String? symbol) {
  if (symbol == null || symbol.isEmpty) return null;
  if (RegExp(r'^\d{6}$').hasMatch(symbol)) return MarketType.kospi;
  return MarketType.nasdaq;
}