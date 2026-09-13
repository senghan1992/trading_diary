// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trading Diary';

  @override
  String get dashboard => 'Home';

  @override
  String get review => 'Review';

  @override
  String get resultFilter => 'Result';

  @override
  String get stateFilter => 'State';

  @override
  String get allResults => 'All Results';

  @override
  String get winsOnly => 'Profit Only';

  @override
  String get lossesOnly => 'Loss Only';

  @override
  String get pendingOnly => 'Pending';

  @override
  String get allStates => 'All';

  @override
  String get newestFirst => 'Newest First';

  @override
  String get oldestFirst => 'Oldest First';

  @override
  String get portfolioSummary => 'Portfolio Summary';

  @override
  String get total => 'Total';

  @override
  String get win => 'Gain';

  @override
  String get loss => 'Loss';

  @override
  String get winRate => 'Profit Rate';

  @override
  String get recentTrades => 'Recent Trades';

  @override
  String get virtual => 'Virtual';

  @override
  String get real => 'Real';

  @override
  String get noTradesYet => 'No trades yet. Start journaling!';

  @override
  String get learning => 'Learning';

  @override
  String get journal => 'Journal';

  @override
  String get addTrade => 'Record Trade';

  @override
  String get editTrade => 'Edit Record';

  @override
  String get stockName => 'Stock Name';

  @override
  String get direction => 'Direction';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get entryPrice => 'Buy Price';

  @override
  String get exitPrice => 'Sell Price';

  @override
  String get shares => 'Shares';

  @override
  String get sharesUnit => 'shares';

  @override
  String get entryDate => 'Buy Date';

  @override
  String get exitDate => 'Sell Date';

  @override
  String get profitLoss => 'Profit/Loss';

  @override
  String get profitLossPercent => 'P/L %';

  @override
  String get tradeType => 'Trade Type';

  @override
  String get notes => 'Notes';

  @override
  String get save => 'Complete';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Delete this trade?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get thisYear => 'This Year';

  @override
  String get all => 'All';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get date => 'Date';

  @override
  String get amount => 'Amount';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get korean => 'Korean';

  @override
  String get english => 'English';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get display => 'Display';

  @override
  String get displaySubtitle => 'Display and colors';

  @override
  String get priceColors => 'Price colors';

  @override
  String get priceColorsKorean => 'Korean (red up, blue down)';

  @override
  String get priceColorsWestern => 'Western (green up, red down)';

  @override
  String get languageSection => 'Language';

  @override
  String get languageSectionSubtitle => 'App interface language';

  @override
  String calendarMonthYear(Object month, Object year) {
    return '$year/$month';
  }

  @override
  String monthDayWeekday(Object day, Object month, Object weekday) {
    return '$month/$day ($weekday)';
  }

  @override
  String tradeCount(Object count) {
    return '· $count trades';
  }

  @override
  String get reviewEmptyHeader => 'Pick a date from the calendar';

  @override
  String get reviewEmptyBody =>
      'Trades made on the selected date will appear here.';

  @override
  String get reviewNoTradesTitle => 'No trades on this day';

  @override
  String get reviewNoTradesBody =>
      'Try a different date or change the filters.';

  @override
  String get reviewAddTradeForDay => 'Record trade for this day';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get totalTrades => 'Total Trades';

  @override
  String get winningTrades => 'Winning Trades';

  @override
  String get losingTrades => 'Losing Trades';

  @override
  String get averageProfit => 'Average Profit';

  @override
  String get averageLoss => 'Average Loss';

  @override
  String get bestTrade => 'Best Trade';

  @override
  String get worstTrade => 'Worst Trade';

  @override
  String get tradingIdea => 'Trading Idea';

  @override
  String get mistake => 'Mistake';

  @override
  String get lesson => 'Lesson';

  @override
  String get whatILearned => 'What I Learned';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get success => 'Saved successfully';

  @override
  String get failure => 'Failed to save';

  @override
  String get position => 'Position';

  @override
  String get openPosition => 'Open';

  @override
  String get closedPosition => 'Closed';

  @override
  String get marketValue => 'Market Value';

  @override
  String get addPosition => 'Record Entry';

  @override
  String get closePosition => 'Record Exit';

  @override
  String get entryOnly => 'Buy Only';

  @override
  String get withExit => 'Buy + Sell';

  @override
  String get more => 'More';

  @override
  String get tradeJournal => 'Trade Journal';

  @override
  String get analysisNote => 'Analysis Note';

  @override
  String get addAnalysisNote => 'Add Analysis Note';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabAnalysis => 'Analysis';

  @override
  String get tradeReasonLabel => 'Investment Rationale';

  @override
  String get tradeIdeaLabel => 'Investment Idea';

  @override
  String get tradeStatusClosed => 'Closed';

  @override
  String get tradeStatusOpen => 'Open';

  @override
  String sharesWithUnit(int count) {
    return '$count shares';
  }

  @override
  String get priceChart => 'Price Chart';

  @override
  String get pinchToZoom => 'Pinch to zoom';

  @override
  String get noChartData => 'No chart data';

  @override
  String get realizedPL => 'Realized P/L';

  @override
  String get unrealizedPLLabel => 'Unrealized P/L';

  @override
  String get journalCompleteness => 'Journal completeness';

  @override
  String get journalCompleteMessage =>
      'All sections complete. Excellent trade review!';

  @override
  String journalRemainingMessage(int count) {
    return 'How about filling in $count more sections?';
  }

  @override
  String get buyRationaleTitle => 'Buy Rationale';

  @override
  String get buyRationaleSubtitle =>
      'Why did you buy this stock? Summarize the core thesis.';

  @override
  String get buyRationaleHint1 => '• Chart patterns or technical signals';

  @override
  String get buyRationaleHint2 => '• Fundamentals, theme, or news catalysts';

  @override
  String get buyRationaleHint3 => '• Expected return and holding period';

  @override
  String get marketAnalysisTitle => 'Market Conditions';

  @override
  String get marketAnalysisSubtitle =>
      'What was the market and sector momentum at entry?';

  @override
  String get marketAnalysisHint1 => '• Overall market trend and sentiment';

  @override
  String get marketAnalysisHint2 => '• Related sector and theme dynamics';

  @override
  String get marketAnalysisHint3 => '• Evaluation of entry timing';

  @override
  String get riskManagementTitle => 'Risk Management';

  @override
  String get riskManagementSubtitle =>
      'How were your stop-loss and position size? Note any regrets.';

  @override
  String get riskManagementHint1 => '• Whether you set a stop-loss in advance';

  @override
  String get riskManagementHint2 => '• Position size and diversification';

  @override
  String get riskManagementHint3 => '• Where you broke your own trading rules';

  @override
  String get keyLessonsTitle => 'Key Lessons';

  @override
  String get keyLessonsSubtitle =>
      'What\'s the most important lesson from this trade?';

  @override
  String get keyLessonsHint1 => '• What went well — to repeat';

  @override
  String get keyLessonsHint2 => '• What went wrong — to avoid';

  @override
  String get keyLessonsHint3 => '• One-line summary of the lesson';

  @override
  String get nextTradePledgeTitle => 'Next-Trade Pledge';

  @override
  String get nextTradePledgeSubtitle =>
      'How will you apply this experience to the next trade?';

  @override
  String get nextTradePledgeHint1 => '• Specific strategy to apply';

  @override
  String get nextTradePledgeHint2 => '• Trading rules to change';

  @override
  String get nextTradePledgeHint3 => '• Metrics or patterns to track';

  @override
  String get tryThisHint => 'Try writing about...';

  @override
  String get enterAnalysisHint => 'Type your analysis here...';

  @override
  String charCount(int count) {
    return '$count chars';
  }

  @override
  String get resetButton => 'Reset';

  @override
  String noteCount(int count) {
    return '$count notes';
  }

  @override
  String noteSavedFormat(String title) {
    return '「$title」 saved';
  }

  @override
  String get recordButton => 'Save';

  @override
  String get writtenNotes => 'Saved Notes';

  @override
  String get emptyOpenPositions => 'No open positions';

  @override
  String get emptyClosedTrades => 'No closed trades yet';

  @override
  String get update => 'Update';

  @override
  String get later => 'Later';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateDefaultBody =>
      'A new version is available. Please update for the best experience.';

  @override
  String get updateFetchError =>
      'Couldn\'t load update info. Please try again.';

  @override
  String get updateStoreOpenError =>
      'Couldn\'t open the store. Please try again.';

  @override
  String get analytics => 'Analytics';

  @override
  String get tabAnalyticsSummary => 'Overview';

  @override
  String get tabTradeCalendar => 'Calendar';

  @override
  String get periodAll => 'All';

  @override
  String get period1Y => '1Y';

  @override
  String get period6M => '6M';

  @override
  String get period1M => '1M';

  @override
  String get period1W => '1W';

  @override
  String get marketAll => 'All markets';

  @override
  String get marketDomestic => 'Korea (KRX)';

  @override
  String get marketUS => 'US';

  @override
  String get profitFactor => 'Profit factor';

  @override
  String get payoffRatio => 'Win/Loss ratio';

  @override
  String get avgWin => 'Avg. win';

  @override
  String get avgLoss => 'Avg. loss';

  @override
  String get avgHoldingPeriod => 'Avg. holding';

  @override
  String daysUnit(int days) {
    return '${days}d';
  }

  @override
  String winStreakFormat(int count) {
    return '$count wins';
  }

  @override
  String lossStreakFormat(int count) {
    return '$count losses';
  }

  @override
  String get bestTradeLabel => 'Best trade';

  @override
  String get worstTradeLabel => 'Worst trade';

  @override
  String get cumulativePnLChart => 'Cumulative realised P&L';

  @override
  String get monthlyPnLChart => 'Monthly realised P&L';

  @override
  String get winLossDistribution => 'Win/Loss distribution';

  @override
  String get stockRankings => 'Performance by stock';

  @override
  String get strategyPerformance => 'Performance by strategy';

  @override
  String get weekdayPatterns => 'Patterns by weekday';

  @override
  String get topGainers => 'Top gainers';

  @override
  String get topLosers => 'Top losers';

  @override
  String get emptyAnalyticsTitle => 'No trades to aggregate yet';

  @override
  String get emptyAnalyticsSubtitle =>
      'Log a trade in the journal to unlock multi-dimensional analytics and performance insights.';

  @override
  String get uncategorisedStrategy => '(Uncategorised)';

  @override
  String get tradeTypeAll => 'All accounts';

  @override
  String get noClosedTrades => 'No closed trades in this window';

  @override
  String get infinitySymbol => '∞';

  @override
  String get accountTag => 'Account tag';

  @override
  String get accountManagement => 'Accounts & tags';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get unassignedAccount => '(Unassigned)';

  @override
  String get accountPerformance => 'Performance by account';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get accountName => 'Account name';

  @override
  String get accountProfitLoss => 'P&L';

  @override
  String get selectAccountTag => 'Select account / tag';

  @override
  String get accountNameHint => 'e.g. Kiwoom main';

  @override
  String get accountMemoHint => 'Memo (optional)';

  @override
  String get deleteAccountConfirmTitle => 'Delete this account?';

  @override
  String get deleteAccountConfirmBody =>
      'Existing trades are kept but may show as unassigned.';

  @override
  String get noAccountsRegistered => 'No accounts yet. Add one to get started.';

  @override
  String tradesCount(int count) {
    return '$count';
  }

  @override
  String openPositionsCount(int count) {
    return '$count open';
  }

  @override
  String get avgReturn => 'Avg return';

  @override
  String get viewTradesForAccount => 'View trades';

  @override
  String get myAccounts => 'My Accounts';

  @override
  String get totalInvested => 'Total Invested';

  @override
  String get recentStocks => 'Recent Stocks';

  @override
  String get investedCapital => 'Invested Capital';

  @override
  String get recoveredAmount => 'Recovered Amount';

  @override
  String heldForDaysFormat(int days) {
    return 'Held for $days days';
  }

  @override
  String get priceMovement => 'Price Movement';

  @override
  String get marketEtc => 'Other/Crypto';

  @override
  String get exportToExcel => 'Export to Excel (CSV)';

  @override
  String get exportCsvDescription =>
      'UTF-8 CSV that opens directly in Excel, Hancell, or Google Sheets';

  @override
  String get exportCopyClipboard => 'Copy to Clipboard';

  @override
  String get exportCopiedSnack => 'Excel (CSV) data copied to clipboard.';

  @override
  String exportTradeCount(int count) {
    return '$count trades included.';
  }

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get brokerAccount => 'Select Broker';

  @override
  String get accountType => 'Account Type';

  @override
  String get accountTypeCash => 'Cash Account';

  @override
  String get accountTypeIsa => 'ISA Account';

  @override
  String get accountTypePension => 'Pension Savings';

  @override
  String get accountTypeIrp => 'IRP';

  @override
  String get accountTypeCma => 'CMA';

  @override
  String get quickAddAccount => 'Add New Account';

  @override
  String addTradeOnDate(int month, int day) {
    return 'Record trade on $month/$day';
  }

  @override
  String tradesOnDate(int month, int day) {
    return 'Trades on $month/$day';
  }

  @override
  String get quickRecordTrade => 'Record Trade';

  @override
  String get manageAccounts => 'Manage Accounts';

  @override
  String get accountsOverview => 'Accounts Overview';

  @override
  String get openPositions => 'Open Positions';

  @override
  String get totalReturnPercent => 'Total Return';

  @override
  String get completedTrades => 'Completed Trades';

  @override
  String get holdingsCount => 'Holdings';

  @override
  String completedTradesCount(int count) {
    return '$count completed trades';
  }

  @override
  String get searchTrades => 'Search name, strategy, memo';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortByProfit => 'Best return';

  @override
  String get sortByLoss => 'Worst return';

  @override
  String get dataManagement => 'Data Management';
}
