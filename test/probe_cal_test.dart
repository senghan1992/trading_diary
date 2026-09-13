import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/theme/app_theme.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:trading_diary/widgets/review_calendar_panel.dart';

void main() {
  late Directory tempDir;
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('calprobe');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('trades');
    await Hive.openBox<dynamic>('accounts');
  });

  testWidgets('probe day tap', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);
    final provider = TradeProvider();
    await tester.pumpWidget(
      MultiProvider(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final f15 = find.text('15');
    // ignore: avoid_print
    print('COUNT15: ${f15.evaluate().length}');
    await tester.tap(f15.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      if ((t.data ?? '').contains('매매') || (t.data ?? '').contains('15일')) {
        // ignore: avoid_print
        print('T: ${t.data}');
      }
    }
    // ignore: avoid_print
    print('DONE');
  });
}
