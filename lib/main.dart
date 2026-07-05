import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/ad_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'providers/market_provider.dart';
import 'providers/trade_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/force_update_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/orientation_lock.dart';
import 'utils/responsive.dart';
import 'widgets/update_dialog.dart';

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

/// Resolves the install-version-vs-server-status before the user can reach
/// any other UI. Three branches:
///
///   * loading - splash screen while the config fetch is in flight.
///   * required - the server says we're below [UpdateConfig.minimumVersion]
///     or has flagged a force update. Show [ForceUpdateScreen] which blocks
///     all app UI.
///   * optional / upToDate - render [MainShell]. When the status was
///     "optional" we forward the [UpdateConfig] down so MainShell can show
///     a one-shot "Update available" dialog after the first frame.
///
/// The whole gate is intentionally not aware of auth or onboarding - those
/// live downstream of the version gate because every install needs the
/// version check, even first-launch users.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

enum _GateState { loading, required, optional, upToDate }

class _AppGateState extends State<AppGate> {
  _GateState _state = _GateState.loading;
  UpdateConfig? _config;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _GateState.loading);
    final config = await UpdateService.instance.getConfig();
    if (!mounted) return;
    if (config == null) {
      // No config reachable (placeholder URL, offline, parse error). Don't
      // block the user - just show the app.
      setState(() => _state = _GateState.upToDate);
      return;
    }
    final version = await UpdateService.instance.currentVersion();
    if (!mounted) return;
    final status = UpdateService.instance.checkStatus(config, version);
    setState(() {
      _config = config;
      _state = switch (status) {
        UpdateStatus.required => _GateState.required,
        UpdateStatus.optional => _GateState.optional,
        UpdateStatus.upToDate => _GateState.upToDate,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return const _SplashLoading();
      case _GateState.required:
        return ForceUpdateScreen(config: _config);
      case _GateState.optional:
        return MainShell(
          optionalUpdateConfig: _config,
          optionalUpdateLanguageCode:
              Localizations.localeOf(context).languageCode,
        );
      case _GateState.upToDate:
        return const MainShell();
    }
  }
}

/// Minimal splash shown while [AppGate] waits on the network. Intentionally
/// brand-light - the real branding comes from the actual screens.
class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
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
            home: const AppGate(),
          );
        },
      ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.optionalUpdateConfig,
    this.optionalUpdateLanguageCode,
  });

  /// When non-null, MainShell shows an "Update available" dialog once the
  /// first frame is up. Supplied by [AppGate] when the server config says
  /// the app is up-to-date but a newer version exists.
  final UpdateConfig? optionalUpdateConfig;
  final String? optionalUpdateLanguageCode;

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
      if (!mounted) return;
      final id = NotificationService.instance.consumeLaunchReminderId();
      if (id != null) {
        setState(() => _currentIndex = 1);
        NotificationRouter.lastTappedReminderId.value = id;
      }
      _maybeShowOptionalUpdateDialog();
    });

    // Also handle taps that arrive while the app is in the background/foreground.
    NotificationRouter.lastTappedReminderId.addListener(_onRouterChanged);
  }

  void _maybeShowOptionalUpdateDialog() {
    final config = widget.optionalUpdateConfig;
    if (config == null) return;
    final lang = widget.optionalUpdateLanguageCode ??
        Localizations.localeOf(context).languageCode;
    final message = config.messageFor(lang);
    // ignore: discarded_futures
    UpdateDialog.show(
      context,
      required: false,
      message: message.isEmpty ? null : message,
    );
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
