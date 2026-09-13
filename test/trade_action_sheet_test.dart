import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/widgets/trade_action_sheet.dart';

class _FakeTradeProvider extends ChangeNotifier implements TradeProvider {
  final List<TradeEntry> _trades = [];

  @override
  List<TradeEntry> get trades => _trades;

  @override
  Future<void> closePosition({
    required String tradeId,
    required double exitPrice,
    required DateTime exitDate,
    int? quantity,
  }) async {}

  @override
  Future<void> addTradeExecution({
    required String tradeId,
    required TradeExecutionAction action,
    required double price,
    required int quantity,
    required DateTime date,
    String? memo,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('TradeActionSheet renders tabs, quantity chips, and fields', (tester) async {
    final trade = TradeEntry(
      id: 't-1',
      stockSymbol: '005930',
      stockName: '삼성전자',
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: 50000,
      quantity: 20,
      entryDate: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TradeProvider>(create: (_) => _FakeTradeProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TradeActionSheet(
              trade: trade,
              provider: _FakeTradeProvider(),
              initialTab: TradeActionTab.sell,
            ),
          ),
        ),
      ),
    );

    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('매도 기록 (분할/전량)'), findsOneWidget);
    expect(find.text('추가 매수'), findsOneWidget);
    expect(find.text('전량(100%)'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // Tab switch to buy
    await tester.tap(find.text('추가 매수'));
    await tester.pumpAndSettle();

    expect(find.text('추가 매수 수량'), findsOneWidget);
    expect(find.text('체결 매수가'), findsOneWidget);
  });
}
