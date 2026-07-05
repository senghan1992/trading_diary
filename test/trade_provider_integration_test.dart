// Integration tests for TradeProvider that exercise the Hive data layer.
// These complement the pure-logic tests in trade_data_layer_test.dart by
// covering the full save → load → cascade cycle through a real Hive box.
//
// Targets:
//   H4: deleteTrade cascades to AnalysisNotes + Reminders (Hive-level).
//   H5: closePosition is idempotent — a second call with a different exit
//       price does NOT overwrite the first close.
//
// Note: NotificationService.cancel/schedule calls inside TradeProvider are
// tested here only for "did the Hive cascade complete" semantics. The
// flutter_local_notifications plugin requires a real platform channel
// which is unavailable in `flutter test`, so we don't try to verify that
// the OS-level cancel/schedule succeeded — TradeProvider wraps cancel in
// try/catch so that a failed OS cancel never blocks the Hive cascade.
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
  const kRemindersBox = 'reminders';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_hive');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(kTradesBox);
    await Hive.openBox<dynamic>(kNotesBox);
    await Hive.openBox<dynamic>(kRemindersBox);
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
    await Hive.box<dynamic>(kRemindersBox).clear();
  });

  group('H4: deleteTrade cascades to notes + reminders', () {
    test('removing a trade also removes its notes and trade-linked reminders',
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

      // 3. attach one reminder linked via tradeId
      final reminder = Reminder(
        id: 'r-cascade-1',
        title: 'follow up',
        remindAt: DateTime.utc(2025, 6, 1),
        tradeId: tradeId,
      );
      await LocalStorageService.saveReminder(reminder);
      tp.loadReminders();
      expect(tp.reminders.where((r) => r.tradeId == tradeId).length, 1);

      // 4. delete the trade — note that NotificationService.cancel will
      // throw in the test env (plugin not initialised); TradeProvider must
      // swallow that and complete the Hive cascade.
      await tp.deleteTrade(tradeId);

      // 5. every trace of the trade must be gone from Hive.
      expect(tp.trades.where((t) => t.id == tradeId), isEmpty,
          reason: 'the trade itself must be deleted');
      expect(LocalStorageService.getNotesForTrade(tradeId), isEmpty,
          reason: 'analysis notes must be deleted in the cascade');
      expect(LocalStorageService.getReminders().where((r) => r.tradeId == tradeId),
          isEmpty,
          reason: 'reminders whose tradeId pointed at this trade must also go');

      // 6. unrelated trades/notes/reminders must survive the cascade.
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
      final otherId = tp.trades.firstWhere((t) => t.stockSymbol == '000660').id;
      await tp.addAnalysisNote(otherId, 'unrelated note');
      expect(LocalStorageService.getNotesForTrade(otherId).length, 1,
          reason: 'other trades\' notes must be untouched by the cascade');
    });

    test('reminders not linked to the deleted trade survive', () async {
      final tp = TradeProvider();
      await Future<void>.delayed(Duration.zero);

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
      final tradeId = tp.trades.first.id;

      // Standalone reminder (no tradeId) should not be touched.
      final global = Reminder(
        id: 'r-global',
        title: 'global reminder',
        remindAt: DateTime.utc(2025, 7, 1),
      );
      // Linked reminder — different tradeId — should also not be touched.
      final other = Reminder(
        id: 'r-other',
        title: 'other trade reminder',
        remindAt: DateTime.utc(2025, 7, 2),
        tradeId: 'trade-other',
      );
      // Linked reminder — THIS trade — should be deleted.
      final owned = Reminder(
        id: 'r-owned',
        title: 'owned reminder',
        remindAt: DateTime.utc(2025, 7, 3),
        tradeId: tradeId,
      );
      await LocalStorageService.saveReminder(global);
      await LocalStorageService.saveReminder(other);
      await LocalStorageService.saveReminder(owned);
      tp.loadReminders();

      await tp.deleteTrade(tradeId);

      final remaining = LocalStorageService.getReminders();
      expect(remaining.map((r) => r.id), containsAll(['r-global', 'r-other']),
          reason: 'reminders without this tradeId must remain');
      expect(remaining.any((r) => r.id == 'r-owned'), isFalse,
          reason: 'reminder whose tradeId matched must be deleted');
    });
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
      expect(afterSecond.exitPrice, 72000,
          reason: 'exit price must remain at the first close value');
      expect(afterSecond.exitDate, firstCloseDate,
          reason: 'exit date must remain at the first close value');

      // Also verify Hive persisted the original close, not the second one.
      final fromHive = LocalStorageService.getTrades().firstWhere(
        (t) => t.id == tradeId,
      );
      expect(fromHive.exitPrice, 72000);
      expect(fromHive.exitDate, firstCloseDate);
    });
  });

  group('Snooze picker: snoozeReminder supports multiple durations', () {
    // Each picker option is verified in its own isolated test so the
    // expected delta starts from a known remindAt every time.

    Future<void> snoozeAndExpect({
      required TradeProvider tp,
      required String id,
      required Duration by,
      required DateTime originalRemindAt,
      required String expectedTradeId,
    }) async {
      final r = Reminder(
        id: id,
        title: 'review',
        remindAt: originalRemindAt,
        isRead: true, // user already saw it; snooze must reset
        tradeId: expectedTradeId,
      );
      await LocalStorageService.saveReminder(r);
      tp.loadReminders();

      await tp.snoozeReminder(id, by);

      final fromHive = LocalStorageService.getReminders().firstWhere(
        (r) => r.id == id,
      );
      expect(
        fromHive.remindAt.difference(originalRemindAt).inDays,
        by.inDays,
        reason: 'remindAt must advance by exactly ${by.inDays} days',
      );
      expect(fromHive.isRead, isFalse,
          reason: 'isRead must reset on every snooze');
      expect(fromHive.tradeId, expectedTradeId,
          reason: 'tradeId must survive the snooze round-trip');
    }

    test('snooze +1 day preserves tradeId and resets isRead', () async {
      await snoozeAndExpect(
        tp: TradeProvider()..loadReminders(),
        id: 'snooze-d1',
        by: const Duration(days: 1),
        originalRemindAt: DateTime.utc(2025, 1, 1),
        expectedTradeId: 'tx-1d',
      );
    });

    test('snooze +1 week preserves tradeId and resets isRead', () async {
      await snoozeAndExpect(
        tp: TradeProvider()..loadReminders(),
        id: 'snooze-w1',
        by: const Duration(days: 7),
        originalRemindAt: DateTime.utc(2025, 2, 1),
        expectedTradeId: 'tx-w1',
      );
    });

    test('snooze +1 month preserves tradeId and resets isRead', () async {
      // 30 days, mirroring what 1 month typically means in the picker.
      await snoozeAndExpect(
        tp: TradeProvider()..loadReminders(),
        id: 'snooze-m1',
        by: const Duration(days: 30),
        originalRemindAt: DateTime.utc(2025, 3, 1),
        expectedTradeId: 'tx-m1',
      );
    });

    test('snooze +3 months preserves tradeId and resets isRead', () async {
      await snoozeAndExpect(
        tp: TradeProvider()..loadReminders(),
        id: 'snooze-q1',
        by: const Duration(days: 90),
        originalRemindAt: DateTime.utc(2025, 4, 1),
        expectedTradeId: 'tx-q1',
      );
    });

    test('snooze with no matching id is a no-op (returns false)', () async {
      final tp = TradeProvider();
      await Future<void>.delayed(Duration.zero);

      final ok = await tp.snoozeReminder('does-not-exist', const Duration(days: 7));
      expect(ok, isFalse);
      // No side effect on the reminder store
      expect(LocalStorageService.getReminders(), isEmpty);
    });
  });
}
