import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/stock.dart';
import '../models/trade_entry.dart';

/// Excel-compatible CSV export.
///
/// Generates a standard CSV that opens cleanly in Microsoft Excel, Hancom
/// Hancell, Google Sheets, and Apple Numbers with **zero dependency on any
/// native package**: the payload is plain UTF-8 text prefixed with a BOM
/// (`\uFEFF`) so Excel auto-detects the encoding and renders Korean text
/// without mojibake. The service exposes the CSV through the system
/// clipboard plus an in-app preview sheet, which works on every platform
/// (iOS/Android/Web/Desktop) without extra permissions or plugins.
class ExcelExportService {
  ExcelExportService._();

  /// UTF-8 BOM — forces Excel/Hancell to read the file as UTF-8.
  static const String _bom = '\uFEFF';

  /// Sheet header row. Column order matches [_rowFor] exactly.
  static const List<String> _header = [
    '거래ID',
    '매수일자',
    '매도일자',
    '증권사/계좌',
    '종목명',
    '종목코드',
    '시장구분',
    '거래유형',
    '매매방향',
    '진입단가',
    '청산단가',
    '수량',
    '총투자금',
    '실현손익',
    '수익률(%)',
    '상태',
    '매매전략',
    '매매사유',
    '배운점',
  ];

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final NumberFormat _moneyFormat = NumberFormat('#,##0.##');
  static final NumberFormat _pctFormat = NumberFormat('#,##0.00');

  /// Builds the full CSV document (BOM + header + one row per trade).
  ///
  /// Rows follow the input order. Callers wanting a specific order (e.g.
  /// newest first) should sort [trades] before calling.
  static String generateCsv(List<TradeEntry> trades) {
    final buffer = StringBuffer(_bom);
    buffer.writeln(_header.map(_escape).join(','));
    for (final trade in trades) {
      buffer.writeln(_rowFor(trade).map(_escape).join(','));
    }
    return buffer.toString();
  }

  /// CSV-escapes a single cell: wrap in double quotes when the value
  /// contains a comma, quote, or newline, and double any embedded quotes.
  static String _escape(String? value) {
    final raw = value ?? '';
    if (raw.contains(',') || raw.contains('"') || raw.contains('\n')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  static List<String> _rowFor(TradeEntry t) {
    final totalInvested = t.entryPrice * t.quantity;
    return [
      t.id,
      _dateFormat.format(t.entryDate),
      t.exitDate != null ? _dateFormat.format(t.exitDate!) : '',
      t.accountTag ?? '미지정',
      t.stockName,
      t.stockSymbol,
      _marketLabel(t.market),
      t.type == TradeType.real ? '실전' : '모의',
      t.direction == TradeDirection.buy ? '매수(롱)' : '매도(숏)',
      _moneyFormat.format(t.entryPrice),
      t.exitPrice != null ? _moneyFormat.format(t.exitPrice!) : '',
      '${t.quantity}',
      _moneyFormat.format(totalInvested),
      _moneyFormat.format(t.profitLoss),
      _pctFormat.format(t.profitLossPercent),
      _statusLabel(t),
      t.strategy ?? '',
      t.reason ?? '',
      t.lesson ?? '',
    ];
  }

  static String _marketLabel(MarketType? market) {
    switch (market) {
      case MarketType.kospi:
        return '코스피';
      case MarketType.kosdaq:
        return '코스닥';
      case MarketType.nasdaq:
        return '나스닥';
      case null:
        return '';
    }
  }

  static String _statusLabel(TradeEntry t) {
    if (!t.isClosed) return '보유중';
    return switch (t.result) {
      TradeResult.success => '수익',
      TradeResult.failure => '손실',
      TradeResult.breakeven => '손익분기',
      TradeResult.pending => '청산대기',
    };
  }

  /// Copies the CSV to the system clipboard with a confirmation snackbar.
  static void copyToClipboard(BuildContext context, List<TradeEntry> trades) {
    final csv = generateCsv(trades);
    Clipboard.setData(ClipboardData(text: csv));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n?.exportCopiedSnack ?? '엑셀(CSV) 데이터가 클립보드에 복사되었습니다.',
          ),
        ),
      );
  }

  /// Bottom sheet with one-tap clipboard copy plus a live preview of the
  /// generated CSV so the user can verify the payload before pasting it
  /// into Excel / Google Sheets.
  static void showExportDialog(
    BuildContext context,
    List<TradeEntry> trades,
  ) {
    final csv = generateCsv(trades);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final preview = csv.length > 2000 ? '${csv.substring(0, 2000)}\n…' : csv;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_view, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.exportToExcel ?? '엑셀(CSV)로 내보내기',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.exportCsvDescription ??
                      'UTF-8 BOM CSV · Excel/한셀/구글 스프레드시트 호환',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.exportTradeCount(trades.length) ??
                      '총 ${trades.length}건의 거래가 포함됩니다.',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => copyToClipboard(sheetContext, trades),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n?.exportCopyClipboard ?? '클립보드로 복사'),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      preview,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
