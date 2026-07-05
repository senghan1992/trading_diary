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
  String get searchPlaceholder => 'Search by stock name or code';

  @override
  String get resultFilter => 'Result';

  @override
  String get stateFilter => 'State';

  @override
  String get allResults => 'All Results';

  @override
  String get winsOnly => 'Wins';

  @override
  String get lossesOnly => 'Losses';

  @override
  String get pendingOnly => 'Open';

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
  String get win => 'Win';

  @override
  String get loss => 'Loss';

  @override
  String get winRate => 'Win Rate';

  @override
  String get marketIndices => 'Market Indices';

  @override
  String get recentTrades => 'Recent Trades';

  @override
  String get virtual => 'Virtual';

  @override
  String get real => 'Real';

  @override
  String get noTradesYet => 'No trades yet. Start journaling!';

  @override
  String get reminders => 'Reminders';

  @override
  String get noPendingReminders => 'No pending reminders';

  @override
  String get learning => 'Learning';

  @override
  String get journal => 'Journal';

  @override
  String get addTrade => 'Add Trade';

  @override
  String get editTrade => 'Edit Trade';

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
  String get save => 'Save';

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
  String get theme => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get display => 'Display';

  @override
  String get displaySubtitle => 'Display and colors';

  @override
  String get screenMode => 'Screen mode';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

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
  String get reviewAddTradeForDay => 'Add trade for this day';

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
  String get search => 'Search';

  @override
  String get noResults => 'No Results';

  @override
  String get kospi => 'KOSPI';

  @override
  String get kosdaq => 'KOSDAQ';

  @override
  String get nasdaq => 'NASDAQ';

  @override
  String get sp500 => 'S&P 500';

  @override
  String get dowJones => 'Dow Jones';

  @override
  String get lastUpdated => 'Last Updated';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get success => 'Success';

  @override
  String get failure => 'Failure';

  @override
  String get position => 'Position';

  @override
  String get positionEntry => 'Position Entry';

  @override
  String get positionClose => 'Position Close';

  @override
  String get openPosition => 'Open';

  @override
  String get closedPosition => 'Closed';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get unrealizedPL => 'Unrealized P/L';

  @override
  String get marketValue => 'Market Value';

  @override
  String get holdings => 'Holdings';

  @override
  String get addPosition => 'Add Position';

  @override
  String get closePosition => 'Close Position';

  @override
  String get simulate => 'Simulate';

  @override
  String get trackPosition => 'Track';

  @override
  String get updatePosition => 'Update Position';

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
  String get reminderTitle => 'Reminder Title';

  @override
  String get reminderNote => 'Reminder Note';

  @override
  String get reminderDate => 'Reminder Date';

  @override
  String get setReminder => 'Set Reminder';

  @override
  String get reminderFor => 'Reminder';

  @override
  String get deleteReminder => 'Delete Reminder';

  @override
  String get deleteReminderConfirm =>
      'Delete this reminder? It will no longer fire.';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Trade reminders and review alerts';

  @override
  String get notificationsEnabled => 'Enable notifications';

  @override
  String get notificationsEnabledSubtitle =>
      'Get reminded about trades, reviews, and positions';

  @override
  String get notificationsPermissionDenied =>
      'Notification permission is off. Tap to open settings.';

  @override
  String get notificationsOpenSettings => 'Open Settings';

  @override
  String get notificationsReschedule => 'Reschedule pending reminders';

  @override
  String notificationsRescheduleDone(int count) {
    return '$count reminders scheduled';
  }

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
  String get setRemindersLabel => 'Set Reminders';

  @override
  String get noRemindersSet => 'No reminders set yet';

  @override
  String get newReminderHeader => 'New Reminder';

  @override
  String get reminderTitleHint =>
      'Reminder title (e.g., re-check this stock in 3 days)';

  @override
  String get reminderNoteHint => 'Notes (optional)';

  @override
  String get enterReminderTitle => 'Please enter a reminder title';

  @override
  String reminderSetFormat(String date) {
    return 'Reminder set for $date';
  }

  @override
  String get reminderOverdue => 'Overdue';

  @override
  String get emptyOpenPositions => 'No open positions';

  @override
  String get emptyClosedTrades => 'No closed trades yet';

  @override
  String get snoozeOneDay => 'Snooze 1 day';

  @override
  String get snoozeOneWeek => 'Snooze 1 week';

  @override
  String get snoozeOneMonth => 'Snooze 1 month';

  @override
  String get snoozeThreeMonths => 'Snooze 3 months';

  @override
  String get snoozePickerTitle => 'Snooze reminder';

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
}
