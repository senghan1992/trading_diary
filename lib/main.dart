import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/ad_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'providers/market_provider.dart';
import 'providers/trade_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/home_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/orientation_lock.dart';
import 'utils/responsive.dart';

/// Lightweight global router used by [NotificationService] when a delivered
/// notification is tapped. The settings/build code wires the active shell
/// into this; the notification tap fires the callback which the shell uses
/// to switch to the Journal tab.
class NotificationRouter {
  NotificationRouter._();
  static final ValueNotifier<String?> lastTappedReminderId =
      ValueNotifier<String?>(null);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  await AdService.instance.init();
  await NotificationService.instance.init();
  // Lock orientation by form factor BEFORE the first frame. Phones stay
  // portrait; tablets get all four orientations. The OrientationLock
  // widget below keeps this in sync if the size class changes at runtime
  // (foldable unfolding, split-screen resize).
  await applyInitialOrientation();

  // Re-sync the OS scheduler to the locally stored reminders. This is
  // idempotent and covers cold reboot (Android clears scheduled alarms),
  // app updates that may have dropped pending intents, and the first launch
  // after install.
  final tradeProvider = TradeProvider();
  // TradeProvider's constructor already loads reminders; calling
  // loadReminders() again here was redundant.
  if (tradeProvider.reminders.isNotEmpty) {
    // Run async, don't block UI startup. Errors are swallowed; the toggle
    // in settings is the user's recovery path.
    // ignore: discarded_futures
    tradeProvider.rescheduleAllReminders();
  }

  // Tapping a delivered notification pushes the reminder id here so the
  // active shell can route to it.
  NotificationService.instance.onNotificationTap = (reminder) {
    NotificationRouter.lastTappedReminderId.value = reminder.id;
  };

  runApp(TradingDiaryApp(tradeProvider: tradeProvider));
}

class TradingDiaryApp extends StatelessWidget {
  final TradeProvider tradeProvider;
  const TradingDiaryApp({super.key, required this.tradeProvider});

  @override
  Widget build(BuildContext context) {
    return OrientationLock(
      child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
        ChangeNotifierProvider.value(value: tradeProvider),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return MaterialApp(
            title: 'Trading Diary',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('ko'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainShell(),
          );
        },
      ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    JournalScreen(),
    ReviewScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // If the app was cold-started by tapping a notification, jump to the
    // Journal tab once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = NotificationService.instance.consumeLaunchReminderId();
      if (id != null && mounted) {
        setState(() => _currentIndex = 1);
        NotificationRouter.lastTappedReminderId.value = id;
      }
    });

    // Also handle taps that arrive while the app is in the background/foreground.
    NotificationRouter.lastTappedReminderId.addListener(_onRouterChanged);
  }

  @override
  void dispose() {
    NotificationRouter.lastTappedReminderId.removeListener(_onRouterChanged);
    super.dispose();
  }

  void _onRouterChanged() {
    if (!mounted) return;
    if (NotificationRouter.lastTappedReminderId.value != null) {
      setState(() => _currentIndex = 1);
      NotificationRouter.lastTappedReminderId.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showRail = !context.isCompact;
    // True on iPad-portrait-class devices and up: switch the rail to its
    // extended mode (labels inline next to icons, 220 dp wide).
    final extendedRail = context.isExpandedOrUp;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(l10n.dashboard),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.book_outlined),
        selectedIcon: const Icon(Icons.book),
        label: Text(l10n.journal),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.auto_stories_outlined),
        selectedIcon: const Icon(Icons.auto_stories),
        label: Text(l10n.review),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(l10n.settings),
      ),
    ];

    final navBar = NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.dashboard,
        ),
        NavigationDestination(
          icon: const Icon(Icons.book_outlined),
          selectedIcon: const Icon(Icons.book),
          label: l10n.journal,
        ),
        NavigationDestination(
          icon: const Icon(Icons.auto_stories_outlined),
          selectedIcon: const Icon(Icons.auto_stories),
          label: l10n.review,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settings,
        ),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          if (showRail)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              // labelType is forced to `none` when `extended` is true by
              // the NavigationRail contract; we set it explicitly so the
              // intent reads clearly at the call site.
              labelType: extendedRail
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              extended: extendedRail,
              minExtendedWidth: 220,
              destinations: destinations,
            ),
          if (showRail)
            const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      // Phone-only NavigationBar. On tablet/desktop the NavigationRail
      // owns selection so the bottom slot is empty.
      bottomNavigationBar: context.isCompact
          ? Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: navBar,
            )
          : null,
    );
  }
}