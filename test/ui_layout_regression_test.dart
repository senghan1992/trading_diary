// UI layout regression tests for the redesigned shell and screens.
//
// Verifies, at every shipped size class (phone → foldable → tablet → wide):
//   • all four primary tabs render with no layout overflow (light + dark);
//   • the shell mounts exactly one ad footer slot, directly above the
//     bottom nav bar on phones (never inside content);
//   • the resolved Ledger palette contract.
//
// Seeded with realistic multi-account, multi-market trade data so the
// narrowest grid cells and longest labels are actually exercised.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/main.dart' show MainShell;
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/providers/language_provider.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/analytics_screen.dart';
import 'package:trading_diary/screens/home_screen.dart';
import 'package:trading_diary/screens/journal_screen.dart';
import 'package:trading_diary/screens/settings_screen.dart';
import 'package:trading_diary/theme/app_theme.dart';
import 'package:trading_diary/widgets/ad_banner.dart';

const kTradesBox = 'trades';
const kAccountsBox = 'accounts';

Future<TradeProvider> seed(WidgetTester tester) async {
  final provider = TradeProvider();
  await tester.runAsync(() async {
    await provider.addAccount(
      name: '키움증권',
      colorValue: const Color(0xFF1E5B45).toARGB32(),
      memo: null,
    );
    await provider.addAccount(
      name: '미래에셋 ISA',
      colorValue: const Color(0xFF2E6F8E).toARGB32(),
      memo: null,
    );
    await provider.addTrade(
      stockSymbol: '005930',
      stockName: '삼성전자',
      market: MarketType.kospi,
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: 72000,
      exitPrice: 78400,
      quantity: 30,
      entryDate: DateTime(2026, 8, 20, 9, 10),
      exitDate: DateTime(2026, 8, 25, 15, 0),
      reason: '실적 발표 전 이익 실현, 추세선 지지 확인 후 재진입',
      strategy: '추세 추종',
      accountTag: '키움증권',
    );
    await provider.addTrade(
      stockSymbol: '035420',
      stockName: 'NAVER',
      market: MarketType.kospi,
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: 210000,
      exitPrice: 198000,
      quantity: 5,
      entryDate: DateTime(2026, 8, 18, 10, 0),
      exitDate: DateTime(2026, 8, 19, 14, 30),
      reason: '반등 시도 실패, 손절 규칙 준수',
      strategy: '단기 스캘핑',
      accountTag: '미래에셋 ISA',
    );
    await provider.addTrade(
      stockSymbol: 'AAPL',
      stockName: 'Apple Inc.',
      market: MarketType.nasdaq,
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: 225.5,
      exitPrice: 241.0,
      quantity: 10,
      entryDate: DateTime(2026, 8, 10, 22, 30),
      exitDate: DateTime(2026, 8, 14, 21, 45),
      reason: '실적 서프라이즈, 갭 상승 확인 후 추격 매수',
      strategy: '이벤트 드리븐',
      accountTag: '키움증권',
    );
    await provider.addPosition(
      stockSymbol: '373220',
      stockName: 'LG에너지솔루션',
      market: MarketType.kospi,
      type: TradeType.real,
      direction: TradeDirection.buy,
      entryPrice: 356000,
      quantity: 4,
      entryDate: DateTime(2026, 8, 28, 9, 5),
      reason: '배터리 수주 모멘텀, 5일선 위 지지',
      strategy: '스윙',
      accountTag: '키움증권',
    );
  });
  return provider;
}

Widget wrap(TradeProvider provider, Widget child, {bool dark = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
      ChangeNotifierProvider<TradeProvider>.value(value: provider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: child,
    ),
  );
}

void main() {
  late Directory tempDir;

  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_verify');
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

  const sizes = <(String, Size)>[
    ('phone', Size(390, 844)),
    ('foldable', Size(600, 800)),
    ('tablet', Size(1024, 1366)),
    ('wide', Size(1440, 900)),
  ];

  for (final (name, size) in sizes) {
    testWidgets('no overflow at $name for all four tabs', (tester) async {
      tester.view.physicalSize = Size(size.width * 3, size.height * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final provider = await seed(tester);

      for (final screen in <Widget>[
        const HomeScreen(),
        const JournalScreen(),
        const AnalyticsScreen(),
        const SettingsScreen(),
      ]) {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          errors.add(d);
          prev?.call(d);
        };
        await tester.pumpWidget(wrap(provider, screen));
        await tester.pump(const Duration(milliseconds: 500));
        FlutterError.onError = prev;
        final ex = tester.takeException();
        if (errors.isNotEmpty) {
          debugPrint(
            'FULL-ERR [$name/${screen.runtimeType}]: '
            '${errors.first.toString()} \n ${errors.first.exceptionAsString()}',
          );
        }
        expect(
          ex,
          isNull,
          reason: '$name · ${screen.runtimeType} threw: $ex',
        );
      }
    });
  }

  testWidgets('phone shell anchors ad directly above the nav bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final provider = await seed(tester);

    await tester.pumpWidget(wrap(provider, const MainShell()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    final contentBottom =
        tester.getBottomLeft(find.text('포트폴리오 요약')).dy + 200;
    final ad = find.byType(AdBanner);
    final nav = find.byType(NavigationBar);
    expect(ad, findsOneWidget, reason: 'shell mounts exactly one ad footer');
    expect(nav, findsOneWidget);

    final adTop = tester.getTopLeft(ad).dy;
    final navTop = tester.getTopLeft(nav).dy;
    final navBottom = tester.getBottomRight(nav).dy;
    final viewport = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;

    // Ad sits above the nav bar…
    expect(adTop, greaterThanOrEqualTo(navBottom * 0.5));
    expect(adTop, lessThan(navTop), reason: 'ad must sit above the nav bar');
    // …and the nav bar is the very last thing on screen.
    expect(navBottom, closeTo(viewport, 2));
    expect(contentBottom, lessThan(adTop));
  });

  testWidgets('dark mode renders every tab on phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final provider = await seed(tester);

    for (final screen in <Widget>[
      const HomeScreen(),
      const JournalScreen(),
      const AnalyticsScreen(),
      const SettingsScreen(),
    ]) {
      await tester.pumpWidget(wrap(provider, screen, dark: true));
      await tester.pump(const Duration(milliseconds: 500));
      final ex = tester.takeException();
      expect(ex, isNull, reason: 'dark ${screen.runtimeType} threw: $ex');
    }
  });

  testWidgets('resolved palette matches the Ledger contract', (tester) async {
    AppColors.setBrightness(Brightness.light);
    expect(AppColors.accent, const Color(0xFF1E5B45));
    expect(AppColors.bg, const Color(0xFFF6F4ED));
    expect(AppColors.gold, const Color(0xFFA68A3C));
    final theme = AppTheme.lightTheme;
    expect(theme.appBarTheme.titleTextStyle!.fontSize, 22);
    expect(theme.navigationBarTheme.height, 68);
  });
}