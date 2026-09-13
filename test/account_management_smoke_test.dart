// Smoke tests for the multi-account tag management feature surfaces that
// don't pull in the ads SDK (JournalScreen embeds an AdBanner which needs
// real platform channels, so the journal itself is covered by manual QA).
//
// Covered here:
//   • TradeProvider account CRUD round-trip through a real Hive 'accounts'
//     box (saveAccount / getAccounts / deleteAccount).
//   • setSelectedAccountTagFilter narrows filteredTrades and null restores
//     the integrated view.
//   • AccountManagementScreen renders registered accounts with their
//     aggregated stats inside a real MaterialApp/localizations harness.
//   • AccountPerformanceCard renders one row per bucket with localized
//     labels and the sentinel "미지정" bucket for untagged trades.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/models/account_tag.dart';
import 'package:trading_diary/models/trade_analytics.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/account_management_screen.dart';
import 'package:trading_diary/services/local_storage_service.dart';
import 'package:trading_diary/services/trade_analytics_calculator.dart';
import 'package:trading_diary/widgets/analytics/account_performance_card.dart';

void main() {
  late Directory tempDir;

  const kTradesBox = 'trades';
  const kAccountsBox = 'accounts';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_accounts');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(kTradesBox);
    await Hive.openBox<dynamic>(kAccountsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<dynamic>(kTradesBox).clear();
    await Hive.box<dynamic>(kAccountsBox).clear();
  });

  // NOTE: fixed pumps instead of pumpAndSettle — some Material animations
  // in this harness never settle under flutter_test.
  Future<void> pumpWithProvider(WidgetTester tester, Widget child) async {
    final provider = TradeProvider();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        locale: const Locale('ko'),
        home: ChangeNotifierProvider<TradeProvider>.value(
          value: provider,
          child: child,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('TradeProvider account CRUD + tag filter', () {
    test('addAccount persists and loads through the Hive box', () async {
      final tp = TradeProvider();
      await Future<void>.delayed(Duration.zero);

      await tp.addAccount(name: '키움증권', colorValue: 0xFF6C5CE7);
      expect(tp.accounts.map((a) => a.name), contains('키움증권'));
      expect(LocalStorageService.getAccounts().length, 1);

      final account = tp.accounts.single;
      await tp.updateAccount(account.copyWith(memo: '메인'));
      expect(tp.accounts.single.memo, '메인');

      await tp.deleteAccount(account.id);
      expect(tp.accounts, isEmpty);
      expect(LocalStorageService.getAccounts(), isEmpty);
    });

    test(
      'setSelectedAccountTagFilter narrows filteredTrades; null = integrated',
      () async {
        final tp = TradeProvider();
        await Future<void>.delayed(Duration.zero);

        TradeEntry trade(String id, String? tag) => TradeEntry(
          id: id,
          stockSymbol: 'S$id',
          stockName: 'Stock $id',
          market: MarketType.kospi,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: 100,
          quantity: 1,
          entryDate: DateTime(2026, 1, id.hashCode.abs() % 28 + 1),
          isClosed: false,
          accountTag: tag,
        );
        await LocalStorageService.saveTrade(trade('1', '키움'));
        await LocalStorageService.saveTrade(trade('2', '토스'));
        await LocalStorageService.saveTrade(trade('3', null));
        tp.loadTrades();

        expect(
          tp.filteredTrades.length,
          3,
          reason: 'null filter = all accounts combined',
        );

        tp.setSelectedAccountTagFilter('키움');
        expect(tp.selectedAccountTagFilter, '키움');
        expect(tp.filteredTrades.map((t) => t.id), ['1']);

        tp.setSelectedAccountTagFilter(null);
        expect(tp.filteredTrades.length, 3);
      },
    );
  });

  group('AccountManagementScreen', () {
    testWidgets('renders registered accounts', (tester) async {
      // Hive writes are real async I/O; runAsync executes them outside
      // the FakeAsync zone so they actually complete.
      await tester.runAsync(
        () => LocalStorageService.saveAccount(
          AccountTag(
            id: 'a1',
            name: '키움증권',
            colorValue: 0xFF6C5CE7,
            createdAt: DateTime(2026, 1, 1),
          ),
        ),
      );
      await tester.runAsync(
        () => LocalStorageService.saveAccount(
          AccountTag(
            id: 'a2',
            name: '미래에셋 연금',
            createdAt: DateTime(2026, 1, 2),
          ),
        ),
      );
      await pumpWithProvider(tester, const AccountManagementScreen());

      expect(find.text('키움증권'), findsOneWidget);
      expect(find.text('미래에셋 연금'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    });

    testWidgets('shows empty-state message when no accounts exist', (
      tester,
    ) async {
      await pumpWithProvider(tester, const AccountManagementScreen());
      expect(find.text('등록된 계좌가 없습니다. 새 계좌을 추가해보세요.'), findsOneWidget);
    });
  });

  group('AccountPerformanceCard', () {
    TradeEntry closed(String id, double entry, double exit, String? tag) {
      return TradeEntry(
        id: id,
        stockSymbol: id,
        stockName: id,
        market: MarketType.kospi,
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: entry,
        exitPrice: exit,
        quantity: 10,
        entryDate: DateTime(2026, 1, 5),
        exitDate: DateTime(2026, 2, 5),
        result: exit > entry ? TradeResult.success : TradeResult.failure,
        isClosed: true,
        accountTag: tag,
      );
    }

    testWidgets('renders one row per account including the 미지정 bucket', (
      tester,
    ) async {
      final rows = TradeAnalyticsCalculator.computeAccountPerformance([
        closed('t1', 100, 120, '키움'),
        closed('t2', 100, 90, '키움'),
        closed('o1', 100, 105, null),
      ], const TradeAnalyticsFilter());

      await pumpWithProvider(
        tester,
        Scaffold(
          body: ListView(
            children: [
              AccountPerformanceCard(
                rows: rows,
                upColor: Colors.green,
                downColor: Colors.red,
                cardColor: Colors.white,
                textColor: Colors.black,
                subColor: Colors.grey,
                borderColor: Colors.black12,
              ),
            ],
          ),
        ),
      );

      expect(find.text('키움'), findsOneWidget);
      expect(find.text('미지정'), findsOneWidget);
    });
  });
}
