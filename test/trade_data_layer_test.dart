// Regression tests for the data-integrity fixes shipped in the deployment
// prep pass (H1–H8 round). These tests target pure logic (no Hive fixture)
// so they are fast, deterministic, and can catch the regressions the audit
// flagged — most importantly, the data-loss bugs in the deserialization
// path (H1–H3) and the breakeven mis-categorization (H7).
//
// Things covered here:
//   H1: analysisNotes are NOT in the serialized trade map
//       (asymmetry between _tradeToMap and _tradeFromMap is intentional).
//   H2: _tradeFromMap tolerates every key being absent (no KeyError crash).
//   H3: _tradeFromMap infers isClosed from exitDate when the field is
//       missing from older persisted data.
//   H7: computeResultForTest categorizes breakeven (entry==exit) as
//       TradeResult.breakeven, not as success (no inflated win rate).
//   H14: TradeEntry.unrealizedProfitLoss returns null so callers can't
//       accidentally display ₩0 for a real open position (was 0 before).
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/models/account_tag.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/services/local_storage_service.dart';

void main() {
  group('H1: serialize excludes analysisNotes', () {
    test('tradeToMapForTest never contains analysisNotes', () {
      final t = TradeEntry(
        id: 't1',
        stockSymbol: '005930',
        stockName: 'Samsung Electronics',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 70000,
        exitPrice: 72000,
        quantity: 10,
        entryDate: DateTime.utc(2025, 1, 1),
        exitDate: DateTime.utc(2025, 2, 1),
        reason: 'good entry',
        strategy: 'pullback',
        lesson: 'patience',
        result: TradeResult.success,
        isClosed: true,
        analysisNotes: [
          AnalysisNote(
            id: 'n1',
            content: 'thesis notes',
            createdAt: DateTime.utc(2025, 1, 1),
          ),
        ],
      );
      final m = LocalStorageService.tradeToMapForTest(t);
      expect(
        m.containsKey('analysisNotes'),
        isFalse,
        reason: 'notes are persisted separately, not inside trade JSON',
      );
      // Sanity: the field set is the documented stable contract.
      expect(m['id'], 't1');
      expect(m['result'], 'success');
      expect(m['isClosed'], true);
    });
  });

  group('H2: schema-evolution safe deserialization', () {
    test('completely empty map does not throw', () {
      final t = LocalStorageService.tradeFromMapForTest({});
      expect(t.id, '');
      expect(t.stockSymbol, '');
      expect(t.stockName, '');
      expect(t.entryPrice, 0);
      expect(t.quantity, 0);
      expect(t.result, TradeResult.pending);
    });

    test('missing enum-shaped strings fall back to defaults', () {
      final t = LocalStorageService.tradeFromMapForTest({
        'entryDate': '2025-01-01T00:00:00.000Z',
      });
      expect(t.type, TradeType.real);
      expect(t.direction, TradeDirection.buy);
      expect(t.result, TradeResult.pending);
    });

    test('null / missing numeric fields become 0, not null', () {
      final t = LocalStorageService.tradeFromMapForTest({
        'id': 't2',
        'type': 'real',
        'direction': 'buy',
        'entryDate': '2025-01-01T00:00:00.000Z',
      });
      // entryPrice / quantity default to 0 rather than crashing on .toDouble().
      expect(t.entryPrice, 0);
      expect(t.quantity, 0);
    });

    test('malformed entryDate does not throw, falls back to now', () {
      final t = LocalStorageService.tradeFromMapForTest({
        'id': 't3',
        'type': 'real',
        'direction': 'buy',
        'entryDate': 'not-an-iso-date',
      });
      // DateTime.tryParse returns null on garbage; the deserializer
      // falls back to DateTime.now() to avoid a crash.
      expect(t.entryDate.year, DateTime.now().year);
    });
  });

  group('H3: isClosed inferred from exitDate when field missing', () {
    test('missing isClosed + present exitDate → isClosed=true', () {
      // Simulates a trade persisted by an older app version that pre-dates
      // the `isClosed` field. Without the inference, the trade would
      // re-appear under the Open tab after upgrade.
      final t = LocalStorageService.tradeFromMapForTest({
        'id': 't4',
        'type': 'real',
        'direction': 'buy',
        'entryPrice': 100,
        'exitPrice': 110,
        'quantity': 1,
        'entryDate': '2025-01-01T00:00:00.000Z',
        'exitDate': '2025-02-01T00:00:00.000Z',
        'result': 'success',
        // Note: no 'isClosed' key — that's the point of this test.
      });
      expect(
        t.isClosed,
        isTrue,
        reason: 'exitDate present → trade is logically closed',
      );
    });

    test('missing isClosed + null exitDate → isClosed=false (open)', () {
      final t = LocalStorageService.tradeFromMapForTest({
        'id': 't5',
        'type': 'real',
        'direction': 'buy',
        'entryPrice': 100,
        'quantity': 1,
        'entryDate': '2025-01-01T00:00:00.000Z',
        // exitDate omitted entirely.
        'result': 'pending',
      });
      expect(t.isClosed, isFalse);
    });

    test('explicit isClosed=false wins regardless of exitDate', () {
      final t = LocalStorageService.tradeFromMapForTest({
        'id': 't6',
        'type': 'real',
        'direction': 'buy',
        'entryPrice': 100,
        'exitPrice': 110,
        'quantity': 1,
        'entryDate': '2025-01-01T00:00:00.000Z',
        'exitDate': '2025-02-01T00:00:00.000Z',
        'result': 'success',
        'isClosed': false, // user explicitly re-opened a closed trade
      });
      expect(
        t.isClosed,
        isFalse,
        reason: 'explicit value wins over inference from exitDate',
      );
    });
  });

  group('H7: breakeven is its own result, not a win', () {
    test('buy + exit > entry → success', () {
      expect(
        TradeProvider.computeResultForTest(TradeDirection.buy, 100, 110),
        TradeResult.success,
      );
    });

    test('buy + exit < entry → failure', () {
      expect(
        TradeProvider.computeResultForTest(TradeDirection.buy, 100, 90),
        TradeResult.failure,
      );
    });

    test('sell + entry > exit → success', () {
      expect(
        TradeProvider.computeResultForTest(TradeDirection.sell, 110, 100),
        TradeResult.success,
      );
    });

    test('sell + entry < exit → failure', () {
      expect(
        TradeProvider.computeResultForTest(TradeDirection.sell, 100, 110),
        TradeResult.failure,
      );
    });

    test('buy + exit == entry → breakeven (NOT success)', () {
      // The original bug: buy+breakeven was silently counted as success,
      // inflating the win-rate counter.
      expect(
        TradeProvider.computeResultForTest(TradeDirection.buy, 100, 100),
        TradeResult.breakeven,
      );
    });

    test('sell + exit == entry → breakeven (NOT success)', () {
      // Same fix, opposite direction. Previous behaviour had sell+breakeven
      // as success; we now agree on breakeven for both directions.
      expect(
        TradeProvider.computeResultForTest(TradeDirection.sell, 100, 100),
        TradeResult.breakeven,
      );
    });
  });

  group('H14: unrealizedProfitLoss is null (not silently 0)', () {
    test('open position getter returns null, not 0', () {
      final t = TradeEntry(
        id: 't7',
        stockSymbol: '005930',
        stockName: 'Samsung',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 70000,
        quantity: 10,
        entryDate: DateTime.now(),
        // exitPrice / exitDate / isClosed all default to null/false →
        // position is open; P/L cannot be computed without a current price.
      );
      expect(
        t.unrealizedProfitLoss,
        isNull,
        reason:
            'previously returned 0, which made the UI show "₩0 P/L" '
            'for open positions and misled the user into thinking '
            'there was no exposure',
      );
      expect(
        t.profitLoss,
        0,
        reason: 'profitLoss on open position is correctly 0 (no realized exit)',
      );
    });
  });

  group('AccountTag model serialization', () {
    test('toMap / fromMap round-trip preserves every field', () {
      final a = AccountTag(
        id: 'a1',
        name: '키움증권 메인',
        colorValue: 0xFF6C5CE7,
        memo: '주 계좌',
        createdAt: DateTime.utc(2026, 1, 15, 9, 30),
      );
      final restored = AccountTag.fromMap(
        LocalStorageService.accountToMapForTest(a),
      );
      expect(restored.id, 'a1');
      expect(restored.name, '키움증권 메인');
      expect(restored.colorValue, 0xFF6C5CE7);
      expect(restored.memo, '주 계좌');
      expect(restored.createdAt, DateTime.utc(2026, 1, 15, 9, 30));
    });

    test('fromJson / toJson are aliases of fromMap / toMap', () {
      final a = AccountTag(
        id: 'x',
        name: '토스증권',
        createdAt: DateTime.utc(2026, 2, 1),
      );
      expect(AccountTag.fromJson(a.toJson()).name, '토스증권');
    });

    test('corrupted map does not throw and fills safe defaults', () {
      final a = AccountTag.fromMap(const {});
      expect(a.id, '');
      expect(a.name, '');
      expect(a.colorValue, isNull);
    });

    test('copyWith can explicitly clear nullable fields', () {
      final a = AccountTag(
        id: 'a1',
        name: 'KB ISA',
        colorValue: 1,
        memo: 'm',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final cleared = a.copyWith(colorValue: null, memo: null);
      expect(cleared.colorValue, isNull);
      expect(cleared.memo, isNull);
      // Untouched fields survive.
      expect(cleared.name, 'KB ISA');
    });
  });

  group('TradeEntry.accountTag backward compatibility', () {
    test('serialized map includes accountTag when present', () {
      final t = TradeEntry(
        id: 't1',
        stockSymbol: '005930',
        stockName: 'Samsung',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 70000,
        exitPrice: 72000,
        quantity: 10,
        entryDate: DateTime.utc(2025, 1, 1),
        exitDate: DateTime.utc(2025, 2, 1),
        result: TradeResult.success,
        isClosed: true,
        accountTag: '키움증권 메인',
      );
      final m = LocalStorageService.tradeToMapForTest(t);
      expect(m['accountTag'], '키움증권 메인');
      final restored = LocalStorageService.tradeFromMapForTest(m);
      expect(restored.accountTag, '키움증권 메인');
    });

    test(
      'legacy persisted trade without accountTag key deserializes to null',
      () {
        // Simulates data written by an app version that pre-dates accounts.
        final legacyMap = <String, dynamic>{
          'id': 'old-1',
          'stockSymbol': '005930',
          'stockName': 'Samsung',
          'type': 'real',
          'direction': 'buy',
          'entryPrice': 70000,
          'exitPrice': 72000,
          'quantity': 10,
          'entryDate': '2025-01-01T00:00:00.000Z',
          'exitDate': '2025-02-01T00:00:00.000Z',
          'result': 'success',
          'isClosed': true,
        };
        final t = LocalStorageService.tradeFromMapForTest(legacyMap);
        expect(
          t.accountTag,
          isNull,
          reason: 'missing key must not crash the read path (H2 policy)',
        );
        expect(t.isClosed, isTrue);
      },
    );

    test('withAccountTag reassigns without touching other fields', () {
      final t = TradeEntry(
        id: 't1',
        stockSymbol: 'AAPL',
        stockName: 'Apple',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 100,
        quantity: 1,
        entryDate: DateTime.utc(2025, 1, 1),
        accountTag: 'A',
      );
      final moved = t.withAccountTag('B');
      expect(moved.accountTag, 'B');
      expect(moved.stockSymbol, 'AAPL');
      final cleared = t.withAccountTag(null);
      expect(cleared.accountTag, isNull);
    });
  });
}
