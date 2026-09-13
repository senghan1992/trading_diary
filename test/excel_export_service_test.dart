import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/services/excel_export_service.dart';

void main() {
  TradeEntry trade({
    String? id,
    String? name,
    bool closed = false,
    double entry = 10000,
    double? exit,
    int qty = 10,
    String? reason,
    MarketType? market,
    String? tag,
  }) {
    return TradeEntry(
      id: id ?? 't1',
      stockSymbol: '005930',
      stockName: name ?? '삼성전자',
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: entry,
      exitPrice: exit,
      quantity: qty,
      entryDate: DateTime(2026, 8, 1, 9, 30),
      exitDate: closed ? DateTime(2026, 8, 5, 15, 20) : null,
      reason: reason,
      result: closed
          ? (exit != null && exit > entry
                ? TradeResult.success
                : TradeResult.failure)
          : TradeResult.pending,
      isClosed: closed,
      market: market,
      accountTag: tag,
    );
  }

  group('ExcelExportService.generateCsv', () {
    test('starts with UTF-8 BOM and sheet header', () {
      final csv = ExcelExportService.generateCsv([]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv.split('\n').first.endsWith(
              '거래ID,매수일자,매도일자,증권사/계좌,종목명,종목코드,시장구분,거래유형,매매방향,진입단가,청산단가,수량,총투자금,실현손익,수익률(%),상태,매매전략,매매사유,배운점',
            ),
        isTrue,
      );
    });

    test('open trade renders empty exit columns and 보유중 status', () {
      final csv = ExcelExportService.generateCsv([trade()]);
      final row = csv.split('\n')[1];
      expect(row, contains('2026-08-01'));
      expect(row, endsWith(',보유중,,,'));
      expect(row, contains('"100,000"')); // 총투자금 (10,000 × 10주)
    });

    test('closed trade computes invested amount, pnl and return', () {
      final csv = ExcelExportService.generateCsv(
        [trade(closed: true, entry: 10000, exit: 11000, qty: 10)],
      );
      final row = csv.split('\n')[1];
      expect(row, contains('2026-08-05'));
      expect(row, contains('100,000')); // 총투자금
      expect(row, contains('10,000')); // 실현손익
      expect(row, contains('10.00')); // 수익률
      expect(row, contains('수익'));
    });

    test('escapes commas, quotes and newlines in free-text fields', () {
      final csv = ExcelExportService.generateCsv([
        trade(reason: '실적 발표, "호재" 있음\n추가 매수 고려'),
      ]);
      expect(csv, contains('"실적 발표, ""호재"" 있음\n추가 매수 고려"'));
    });

    test('null account tag falls back to 미지정', () {
      final csv = ExcelExportService.generateCsv([trade()]);
      expect(csv.split('\n')[1], contains(',미지정,'));
    });

    test('account tag and market labels render', () {
      final csv = ExcelExportService.generateCsv([
        trade(tag: '토스증권 ISA', market: MarketType.nasdaq),
      ]);
      expect(csv.split('\n')[1], contains('토스증권 ISA'));
      expect(csv.split('\n')[1], contains('나스닥'));
    });
  });
}
