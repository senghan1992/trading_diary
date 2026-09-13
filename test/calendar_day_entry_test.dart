// Widget flow test: calendar day tap → selected-day card shows the
// "record trade on {month}/{day}" button → tapping it pushes AddTradeScreen
// with that date pre-selected.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/add_trade_screen.dart';
import 'package:trading_diary/theme/app_theme.dart';
import 'package:trading_diary/widgets/review_calendar_panel.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_cal');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('trades');
    await Hive.openBox<dynamic>('accounts');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Widget wrap(TradeProvider provider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<TradeProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: const Scaffold(body: ReviewCalendarPanel()),
      ),
    );
  }

  testWidgets('day tap opens the add-trade flow with the tapped date', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);

    final provider = TradeProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the 15th of the displayed (current) month.
    final now = DateTime.now();
    await tester.tap(find.text('15').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    // The selected-day card offers a one-tap record action with the date
    // baked into its label.
    expect(
      find.textContaining('${now.month}월 15일에 매매 기록하기'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('매매 기록하기'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AddTradeScreen), findsOneWidget);
  });
}
