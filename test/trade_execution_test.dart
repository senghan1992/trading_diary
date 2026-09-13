import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/services/local_storage_service.dart';

void main() {
  group('TradeExecution and TradeEntry split trade calculations', () {
    test('Scale-in (additional buy) correctly updates average price and quantity', () {
      final now = DateTime(2026, 9, 1);
      final trade = TradeEntry(
        id: 'trade-1',
        stockSymbol: '005930',
        stockName: '삼성전자',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 50000,
        quantity: 10,
        entryDate: now,
        executions: [
          TradeExecution(
            id: 'e1',
            action: TradeExecutionAction.buy,
            price: 50000,
            quantity: 10,
            date: now,
            memo: '1차 매수',
          ),
          TradeExecution(
            id: 'e2',
            action: TradeExecutionAction.buy,
            price: 40000,
            quantity: 10,
            date: now.add(const Duration(days: 1)),
            memo: '2차 추가매수',
          ),
        ],
      );

      expect(trade.hasExecutions, isTrue);
      // (10 * 50000 + 10 * 40000) / 20 = 45000
      expect(trade.entryPrice, 45000);
      expect(trade.quantity, 20);
      expect(trade.remainingQuantity, 20);
      expect(trade.isClosed, isFalse);
      expect(trade.exitPrice, isNull);
      expect(trade.profitLoss, 0);
      expect(trade.result, TradeResult.pending);
    });

    test('Partial exit (scale-out) realizes profit and preserves average price on remaining', () {
      final now = DateTime(2026, 9, 1);
      final trade = TradeEntry(
        id: 'trade-2',
        stockSymbol: '005930',
        stockName: '삼성전자',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 45000,
        quantity: 20,
        entryDate: now,
        executions: [
          TradeExecution(
            id: 'e1',
            action: TradeExecutionAction.buy,
            price: 50000,
            quantity: 10,
            date: now,
          ),
          TradeExecution(
            id: 'e2',
            action: TradeExecutionAction.buy,
            price: 40000,
            quantity: 10,
            date: now.add(const Duration(days: 1)),
          ),
          TradeExecution(
            id: 'e3',
            action: TradeExecutionAction.sell,
            price: 60000,
            quantity: 10,
            date: now.add(const Duration(days: 2)),
            memo: '1차 분할 익절',
          ),
        ],
      );

      expect(trade.quantity, 20);
      expect(trade.remainingQuantity, 10);
      expect(trade.isClosed, isFalse);
      expect(trade.entryPrice, 45000);
      expect(trade.exitPrice, 60000);
      // Realized P/L: (60,000 - 45,000) * 10 = +150,000
      expect(trade.profitLoss, 150000);
      expect(trade.result, TradeResult.success);

      final snapshots = trade.getExecutionSnapshots();
      expect(snapshots.length, 3);
      expect(snapshots[0].remainingSharesAfter, 10);
      expect(snapshots[0].averagePriceAfter, 50000);
      expect(snapshots[1].remainingSharesAfter, 20);
      expect(snapshots[1].averagePriceAfter, 45000);
      expect(snapshots[2].remainingSharesAfter, 10);
      expect(snapshots[2].averagePriceAfter, 45000);
      expect(snapshots[2].stepRealizedPnl, 150000);
    });

    test('Full exit across multiple sells marks trade closed with correct total PnL', () {
      final now = DateTime(2026, 9, 1);
      final trade = TradeEntry(
        id: 'trade-3',
        stockSymbol: '005930',
        stockName: '삼성전자',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 45000,
        quantity: 20,
        entryDate: now,
        executions: [
          TradeExecution(
            id: 'e1',
            action: TradeExecutionAction.buy,
            price: 50000,
            quantity: 10,
            date: now,
          ),
          TradeExecution(
            id: 'e2',
            action: TradeExecutionAction.buy,
            price: 40000,
            quantity: 10,
            date: now.add(const Duration(days: 1)),
          ),
          TradeExecution(
            id: 'e3',
            action: TradeExecutionAction.sell,
            price: 60000,
            quantity: 10,
            date: now.add(const Duration(days: 2)),
          ),
          TradeExecution(
            id: 'e4',
            action: TradeExecutionAction.sell,
            price: 55000,
            quantity: 10,
            date: now.add(const Duration(days: 3)),
          ),
        ],
      );

      expect(trade.remainingQuantity, 0);
      expect(trade.isClosed, isTrue);
      expect(trade.entryPrice, 45000);
      // Average exit: (10 * 60000 + 10 * 55000) / 20 = 57500
      expect(trade.exitPrice, 57500);
      // Total P/L: (60,000 - 45,000)*10 + (55,000 - 45,000)*10 = 150,000 + 100,000 = 250,000
      expect(trade.profitLoss, 250000);
      expect(trade.result, TradeResult.success);
    });

    test('Serialization roundtrip preserves executions correctly', () {
      final now = DateTime(2026, 9, 1, 10, 30);
      final original = TradeEntry(
        id: 'trade-storage-test',
        stockSymbol: 'AAPL',
        stockName: 'Apple',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 150,
        quantity: 10,
        entryDate: now,
        executions: [
          TradeExecution(
            id: 'e1',
            action: TradeExecutionAction.buy,
            price: 150,
            quantity: 10,
            date: now,
            memo: '1st buy',
          ),
          TradeExecution(
            id: 'e2',
            action: TradeExecutionAction.buy,
            price: 160,
            quantity: 5,
            date: now.add(const Duration(days: 2)),
            memo: 'pyramiding',
          ),
          TradeExecution(
            id: 'e3',
            action: TradeExecutionAction.sell,
            price: 170,
            quantity: 5,
            date: now.add(const Duration(days: 5)),
            memo: 'take profit',
          ),
        ],
      );

      final map = LocalStorageService.tradeToMapForTest(original);
      expect(map.containsKey('executions'), isTrue);
      expect((map['executions'] as List).length, 3);

      final restored = LocalStorageService.tradeFromMapForTest(map);
      expect(restored.hasExecutions, isTrue);
      expect(restored.executions.length, 3);
      expect(restored.executions[0].action, TradeExecutionAction.buy);
      expect(restored.executions[0].price, 150);
      expect(restored.executions[1].action, TradeExecutionAction.buy);
      expect(restored.executions[1].price, 160);
      expect(restored.executions[2].action, TradeExecutionAction.sell);
      expect(restored.executions[2].price, 170);
      expect(restored.remainingQuantity, 10);
      expect(restored.isClosed, isFalse);
    });
  });
}
