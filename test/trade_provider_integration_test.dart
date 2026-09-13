// Integration tests for TradeProvider that exercise the Hive data layer.
// These complement the pure-logic tests in trade_data_layer_test.dart by
// covering the full save → load → cascade cycle through a real Hive box.
//
// Targets:
//   H4: deleteTrade cascades to AnalysisNotes (Hive-level).
//   H5: closePosition is idempotent — a second call with a different exit
//       price does NOT overwrite the first close.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/services/local_storage_service.dart';

void main() {
  late Directory tempDir;

  // Box names mirror the `_xxxBox` private constants in LocalStorageService.
  // Duplicating them here keeps the service's constants private.
  const kTradesBox = 'trades';
  const kNotesBox = 'notes';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_hive');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(kTradesBox);
    await Hive.openBox<dynamic>(kNotesBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Wipe state between tests so each test sees a clean Hive.
    await Hive.box<dynamic>(kTradesBox).clear();
    await Hive.box<dynamic>(kNotesBox).clear();
  });

  group('H4: deleteTrade cascades to notes', () {
    test(
      'removing a trade also removes its notes',
      () async {
        final tp = TradeProvider();
        // give the constructor's load* methods one tick to drain
        await Future<void>.delayed(Duration.zero);

        // 1. add a trade via the provider's public API
        await tp.addTrade(
          stockSymbol: '005930',
          stockName: 'Samsung',
          market: MarketType.kospi,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: 70000,
          exitPrice: 72000,
          quantity: 1,
          entryDate: DateTime.utc(2025, 1, 1),
          exitDate: DateTime.utc(2025, 2, 1),
        );
        final trades = tp.trades;
        expect(trades.length, 1);
        final tradeId = trades.first.id;

        // 2. attach two notes linked by tradeId
        await tp.addAnalysisNote(tradeId, 'thesis note', category: 'thesis');
        await tp.addAnalysisNote(tradeId, 'risk note', category: 'risk');
        expect(LocalStorageService.getNotesForTrade(tradeId).length, 2);

        // 3. delete the trade
        await tp.deleteTrade(tradeId);

        // 4. every trace of the trade must be gone from Hive.
        expect(
          tp.trades.where((t) => t.id == tradeId),
          isEmpty,
          reason: 'the trade itself must be deleted',
        );
        expect(
          LocalStorageService.getNotesForTrade(tradeId),
          isEmpty,
          reason: 'analysis notes must be deleted in the cascade',
        );

        // 5. unrelated trades/notes must survive the cascade.
        await tp.addTrade(
          stockSymbol: '000660',
          stockName: 'SK Hynix',
          market: MarketType.kospi,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: 100000,
          exitPrice: 105000,
          quantity: 1,
          entryDate: DateTime.utc(2025, 3, 1),
          exitDate: DateTime.utc(2025, 4, 1),
        );
        final otherId = tp.trades
            .firstWhere((t) => t.stockSymbol == '000660')
            .id;
        await tp.addAnalysisNote(otherId, 'unrelated note');
        expect(
          LocalStorageService.getNotesForTrade(otherId).length,
          1,
          reason: 'other trades\' notes must be untouched by the cascade',
        );
      },
    );
  });

  group('H5: closePosition is idempotent', () {
    test('double-close does not overwrite the first close', () async {
      final tp = TradeProvider();
      await Future<void>.delayed(Duration.zero);

      // Open a position via the public API.
      await tp.addPosition(
        stockSymbol: '005930',
        stockName: 'Samsung',
        market: MarketType.kospi,
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 70000,
        quantity: 1,
        entryDate: DateTime.utc(2025, 1, 1),
        reason: 'breakout',
      );
      final tradeId = tp.openPositions.first.id;
      final firstCloseDate = DateTime.utc(2025, 2, 1);

      await tp.closePosition(
        tradeId: tradeId,
        exitPrice: 72000,
        exitDate: firstCloseDate,
      );

      final afterFirst = tp.trades.firstWhere((t) => t.id == tradeId);
      expect(afterFirst.isClosed, true);
      expect(afterFirst.exitPrice, 72000);
      expect(afterFirst.exitDate, firstCloseDate);

      // Try to close again with a different price/date. Must no-op due to
      // the H5 idempotency guard.
      await tp.closePosition(
        tradeId: tradeId,
        exitPrice: 999,
        exitDate: DateTime.utc(2099, 1, 1),
      );

      final afterSecond = tp.trades.firstWhere((t) => t.id == tradeId);
      expect(afterSecond.isClosed, true);
      expect(
        afterSecond.exitPrice,
        72000,
        reason: 'exit price must remain at the first close value',
      );
      expect(
        afterSecond.exitDate,
        firstCloseDate,
        reason: 'exit date must remain at the first close value',
      );

      // Also verify Hive persisted the original close, not the second one.
      final fromHive = LocalStorageService.getTrades().firstWhere(
        (t) => t.id == tradeId,
      );
      expect(fromHive.exitPrice, 72000);
      expect(fromHive.exitDate, firstCloseDate);
    });
  });
}
