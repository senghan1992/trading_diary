import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/ad_service.dart';
import 'services/local_storage_service.dart';
import 'services/update_service.dart';
import 'services/stock_data_service.dart';
import 'providers/trade_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/force_update_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/orientation_lock.dart';
import 'utils/responsive.dart';
import 'widgets/ad_banner.dart';
import 'widgets/update_dialog.dart';

/// Lightweight global router used to switch tabs programmatically
/// (e.g. drilling into Journal from Home or Account screens).
class MainTabRouter {
  MainTabRouter._();
  static final ValueNotifier<int?> switchToTab = ValueNotifier<int?>(null);

  static void jumpToJournal() {
    switchToTab.value = 1;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  await StockDataService.instance.init();
  await AdService.instance.init();
  // Lock orientation by form factor BEFORE the first frame. Phones stay
  // portrait; tablets get all four orientations. The OrientationLock
  // widget below keeps this in sync if the size class changes at runtime
  // (foldable unfolding, split-screen resize).
  await applyInitialOrientation();

  final tradeProvider = TradeProvider();

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
          optionalUpdateLanguageCode: Localizations.localeOf(
            context,
          ).languageCode,
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

class TradingDiaryApp extends StatefulWidget {
  final TradeProvider tradeProvider;
  const TradingDiaryApp({super.key, required this.tradeProvider});

  @override
  State<TradingDiaryApp> createState() => _TradingDiaryAppState();
}

class _TradingDiaryAppState extends State<TradingDiaryApp> {
  @override
  void initState() {
    super.initState();
    // The iOS ATT prompt must only be requested AFTER the first frame is
    // mounted; otherwise the system silently drops the request because no
    // UI window is attached. AdService.init() already ran in main() so the
    // SDK is ready - we only need the OS-level permission here. Fire-and-
    // forget; the future resolves regardless of user choice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      AdService.instance.requestTrackingPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationLock(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: widget.tradeProvider),
        ],
        child: Consumer<LanguageProvider>(
          builder: (context, languageProvider, _) {
            return Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return MaterialApp(
                  title: 'Trading Diary',
                  debugShowCheckedModeBanner: false,
                  // Dual-theme app: system / light / dark, resolved by
                  // ThemeProvider and persisted across launches.
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeProvider.themeMode,
                  themeAnimationDuration: Duration.zero,
                  locale: languageProvider.locale,
                  supportedLocales: const [Locale('ko'), Locale('en')],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) {
                    // Keep the AppColors facade in lockstep with the
                    // resolved theme so every static AppColors.* read
                    // returns light or dark values consistently. With
                    // themeAnimationDuration: Duration.zero, the theme change
                    // updates Theme.of(context).brightness on the immediate frame.
                    AppColors.setBrightness(Theme.of(context).brightness);
                    return SystemBarInsetGuard(child: child!);
                  },
                  home: const AppGate(),
                );
              },
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
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowOptionalUpdateDialog();
    });

    MainTabRouter.switchToTab.addListener(_onTabRouterChanged);
  }

  void _maybeShowOptionalUpdateDialog() {
    final config = widget.optionalUpdateConfig;
    if (config == null) return;
    final lang =
        widget.optionalUpdateLanguageCode ??
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
    MainTabRouter.switchToTab.removeListener(_onTabRouterChanged);
    super.dispose();
  }

  void _onTabRouterChanged() {
    if (!mounted) return;
    final targetTab = MainTabRouter.switchToTab.value;
    if (targetTab != null) {
      setState(() => _currentIndex = targetTab);
      MainTabRouter.switchToTab.value = null;
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
        icon: const Icon(Icons.analytics_outlined),
        selectedIcon: const Icon(Icons.analytics),
        label: Text(l10n.analytics),
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
          icon: const Icon(Icons.analytics_outlined),
          selectedIcon: const Icon(Icons.analytics),
          label: l10n.analytics,
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
          if (showRail) const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _screens[_currentIndex]),
                // On tablet/desktop (no bottom bar) the ad anchors to the
                // bottom of the content column instead of sitting above it.
                if (!context.isCompact) const _AdFooter(showHairline: true),
              ],
            ),
          ),
        ],
      ),
      // Phone-only NavigationBar. On tablet/desktop the NavigationRail
      // owns selection so the bottom slot is empty.
      bottomNavigationBar: context.isCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Advertising lives at the quiet edge of the screen: a slim
                // banner directly above the nav bar, never inside content.
                const _AdFooter(showHairline: true),
                navBar,
              ],
            )
          : null,
    );
  }
}

/// A slim, quiet footer slot for the banner ad. Pinned to the very bottom
/// of the screen (above the nav bar on phones, below the content column on
/// tablet/rail layouts) so it never interrupts reading. Renders nothing
/// until the ad loads, so there is no layout jump.
class _AdFooter extends StatelessWidget {
  const _AdFooter({required this.showHairline});

  final bool showHairline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: showHairline
            ? Border(
                top: BorderSide(color: theme.dividerColor, width: 0.5),
              )
            : null,
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(child: AdBanner()),
      ),
    );
  }
}

/// Consumes the system bar insets (navigation bar on Android, home
/// indicator on iOS) once at the app root so no screen, pushed route, or
/// bottom sheet ever draws underneath them. Top is left untouched:
/// AppBars already handle the status bar inset themselves.
class SystemBarInsetGuard extends StatelessWidget {
  const SystemBarInsetGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, child: child),
    );
  }
}
