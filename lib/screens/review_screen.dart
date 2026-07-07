import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/trade_provider.dart';
import '../models/trade_entry.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../widgets/ad_banner.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/trade_detail_screen.dart';
import 'add_trade_screen.dart';

enum _StateFilter { all, closed, open }

enum _ResultFilter { all, wins, losses, pending }

enum _SortOrder { newestFirst, oldestFirst }

List<String> _weekdayShortList(AppLocalizations l10n) => <String>[
  l10n.weekdayShortMon,
  l10n.weekdayShortTue,
  l10n.weekdayShortWed,
  l10n.weekdayShortThu,
  l10n.weekdayShortFri,
  l10n.weekdayShortSat,
  l10n.weekdayShortSun,
];

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _StateFilter _stateFilter = _StateFilter.all;
  _ResultFilter _resultFilter = _ResultFilter.all;
  _SortOrder _sortOrder = _SortOrder.newestFirst;

  /// Currently displayed month — first day of that month.
  late DateTime _calendarMonth;

  /// Day the user tapped in the calendar. Drives the entries list below.
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onFilterChanged() => setState(() {});

  List<TradeEntry> _applyFilters(TradeProvider provider) {
    final filtered = provider.filteredTrades.where((t) {
      switch (_stateFilter) {
        case _StateFilter.all:
          break;
        case _StateFilter.closed:
          if (!t.isClosed) return false;
          break;
        case _StateFilter.open:
          if (t.isClosed) return false;
          break;
      }
      switch (_resultFilter) {
        case _ResultFilter.all:
          break;
        case _ResultFilter.wins:
          if (t.result != TradeResult.success) return false;
          break;
        case _ResultFilter.losses:
          if (t.result != TradeResult.failure) return false;
          break;
        case _ResultFilter.pending:
          if (t.result != TradeResult.pending) return false;
          break;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.exitDate ?? a.entryDate;
      final bDate = b.exitDate ?? b.entryDate;
      return _sortOrder == _SortOrder.newestFirst
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });
    return filtered;
  }

  /// Groups filtered trades by their order date (exitDate if closed, otherwise
  /// entryDate). Each value list is sorted by that same key, ascending, so
  /// the day's chronology reads top-to-bottom inside the date card.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final borderColor = isDark ? Colors.transparent : AppColors.lightBorder;

    final entries = _applyFilters(provider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (context.isExpandedOrUp) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          title: Text(
            l10n.review,
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCalendar(
                  l10n: l10n,
                  entries: entries,
                  today: today,
                  isDark: isDark,
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                  borderColor: borderColor,
                  cellHeight: 56,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  children: [
                    _buildFilterRow(context, l10n, isDark, textColor, subColor),
                    _buildSelectedDayContent(
                      context,
                      entries,
                      isDark,
                      cardColor,
                      textColor,
                      subColor,
                      borderColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          l10n.review,
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
        ),
        centerTitle: false,
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: AdBanner(),
            ),
            _buildFilterRow(context, l10n, isDark, textColor, subColor),
            _buildCalendar(
              l10n: l10n,
              entries: entries,
              today: today,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
            ),
            _buildSelectedDayContent(
              context,
              entries,
              isDark,
              cardColor,
              textColor,
              subColor,
              borderColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, AppLocalizations l10n, bool isDark, Color textColor, Color subColor) {
    final stateGroup = <(_StateFilter, IconData, String)>[
      (_StateFilter.all, Icons.all_inclusive_rounded, l10n.allStates),
      (_StateFilter.closed, Icons.check_circle_outline_rounded, l10n.closedPosition),
      (_StateFilter.open, Icons.timelapse_rounded, l10n.openPosition),
    ];
    final resultGroup = <(_ResultFilter, IconData, String)>[
      (_ResultFilter.all, Icons.all_inclusive_rounded, l10n.allResults),
      (_ResultFilter.wins, Icons.trending_up_rounded, l10n.winsOnly),
      (_ResultFilter.losses, Icons.trending_down_rounded, l10n.lossesOnly),
      (_ResultFilter.pending, Icons.hourglass_top_rounded, l10n.pendingOnly),
    ];
    final sortGroup = <(_SortOrder, IconData, String)>[
      (_SortOrder.newestFirst, Icons.arrow_downward_rounded, l10n.newestFirst),
      (_SortOrder.oldestFirst, Icons.arrow_upward_rounded, l10n.oldestFirst),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChipGroup(
              context: context,
              label: l10n.stateFilter,
              options: stateGroup,
              current: _stateFilter,
              onSelected: (v) {
                _stateFilter = v;
                _onFilterChanged();
              },
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildChipGroup(
              context: context,
              label: l10n.resultFilter,
              options: resultGroup,
              current: _resultFilter,
              onSelected: (v) {
                _resultFilter = v;
                _onFilterChanged();
              },
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildChipGroup(
              context: context,
              label: l10n.sort,
              options: sortGroup,
              current: _sortOrder,
              onSelected: (v) {
                _sortOrder = v;
                _onFilterChanged();
              },
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipGroup<T>({
    required BuildContext context,
    required String label,
    required List<(T, IconData, String)> options,
    required T current,
    required ValueChanged<T> onSelected,
    required bool isDark,
    required Color textColor,
    required Color subColor,
  }) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: subColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final opt = entry.value;
          final isSelected = opt.$1 == current;
          return Padding(
            padding: EdgeInsets.only(right: idx == options.length - 1 ? 0 : AppSpacing.xs),
            child: _buildFilterChip(
              icon: opt.$2,
              label: opt.$3,
              isSelected: isSelected,
              onTap: () => onSelected(opt.$1),
              isDark: isDark,
              borderColor: borderColor,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color borderColor,
  }) {
    final selectedBg = AppColors.purple;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? selectedBg : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? AppColors.silverBlue : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : (isDark ? AppColors.silverBlue : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Calendar widget
  // ─────────────────────────────────────────────────────────────────────

  Map<DateTime, List<TradeEntry>> _buildDayEntriesMap(List<TradeEntry> entries) {
    final map = <DateTime, List<TradeEntry>>{};
    for (final t in entries) {
      final key = t.exitDate ?? t.entryDate;
      final day = DateTime(key.year, key.month, key.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    return map;
  }

  Color? _computeDayMarkerColor(List<TradeEntry> dayEntries) {
    if (dayEntries.isEmpty) return null;
    final closed = dayEntries.where((t) => t.isClosed).toList();
    final hasPending = dayEntries.any((t) => !t.isClosed);
    if (closed.isEmpty) {
      return hasPending ? AppColors.purpleLight : null;
    }
    final pnl = closed.fold(0.0, (s, t) => s + t.profitLoss);
    if (pnl > 0) return AppColors.green;
    if (pnl < 0) return AppColors.red;
    return AppColors.blue;
  }

  Widget _buildCalendar({
    required AppLocalizations l10n,
    required List<TradeEntry> entries,
    required DateTime today,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    double cellHeight = 44,
  }) {
    final dayEntriesMap = _buildDayEntriesMap(entries);
    final monthStart = _calendarMonth;
    final daysInMonth =
        DateTime(monthStart.year, monthStart.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7. Map Sun to 0 via % 7.
    final firstWeekday =
        DateTime(monthStart.year, monthStart.month, 1).weekday % 7;

    final cells = <(DateTime?, bool)>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add((null, false));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add((DateTime(monthStart.year, monthStart.month, d), true));
    }
    while (cells.length < 42) {
      cells.add((null, false));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: _buildCalendarMonthNav(l10n: l10n, textColor: textColor, subColor: subColor),
          ),
          _buildCalendarWeekdayHeader(l10n: l10n, subColor: subColor),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                for (var row = 0; row < 6; row++)
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        _buildCalendarDayCell(
                          day: cells[row * 7 + col].$1,
                          isCurrentMonth: cells[row * 7 + col].$2,
                          today: today,
                          dayEntriesMap: dayEntriesMap,
                          textColor: textColor,
                          subColor: subColor,
                          cellHeight: cellHeight,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarMonthNav({
    required AppLocalizations l10n,
    required Color textColor,
    required Color subColor,
  }) {
    final now = DateTime.now();
    final isCurrentMonth = _calendarMonth.year == now.year &&
        _calendarMonth.month == now.month;

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 22, color: subColor),
          onPressed: () {
            setState(() {
              _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month - 1,
                1,
              );
              // H13: clear the stale day selection when the user navigates
              // between months. Otherwise the day-content panel below the
              // grid shows "no trades" for a day that isn't even rendered.
              _selectedDay = null;
            });
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          splashRadius: 18,
        ),
        Expanded(
          child: Center(
              child: Text(
              l10n.calendarMonthYear(_calendarMonth.month, _calendarMonth.year),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        if (!isCurrentMonth)
          TextButton(
            onPressed: () {
              setState(() {
                _calendarMonth = DateTime(now.year, now.month, 1);
                _selectedDay = DateTime(now.year, now.month, now.day);
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              l10n.today,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.purple,
              ),
            ),
          ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, size: 22, color: subColor),
          onPressed: () {
            setState(() {
              _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month + 1,
                1,
              );
              // H13: clear the stale day selection when the user navigates
              // between months. Otherwise the day-content panel below the
              // grid shows "no trades" for a day that isn't even rendered.
              _selectedDay = null;
            });
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          splashRadius: 18,
        ),
      ],
    );
  }

  Widget _buildCalendarWeekdayHeader({required AppLocalizations l10n, required Color subColor}) {
    final weekdays = _weekdayShortList(l10n);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  weekdays[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    // M20: Korean market calendar convention. The list is
                    // ordered Mon-first, so Saturday sits at index 5 and
                    // Sunday at index 6. Colour them so Sunday (6) reads
                    // as a market-closed day in red and Saturday (5) in
                    // blue. The previous code painted Mon=0 red and
                    // Sun=6 blue — visually misleading and the opposite of
                    // what Korean calendars show.
                    color: i == 5
                        ? AppColors.blue.withValues(alpha: 0.85)
                        : i == 6
                            ? AppColors.red.withValues(alpha: 0.85)
                            : subColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime? day,
    required bool isCurrentMonth,
    required DateTime today,
    required Map<DateTime, List<TradeEntry>> dayEntriesMap,
    required Color textColor,
    required Color subColor,
    double cellHeight = 44,
  }) {
    if (day == null || !isCurrentMonth) {
      return const Expanded(child: SizedBox.shrink());
    }

    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final isSelected = _selectedDay != null &&
        day.year == _selectedDay!.year &&
        day.month == _selectedDay!.month &&
        day.day == _selectedDay!.day;

    final dayEntries = dayEntriesMap[day] ?? const <TradeEntry>[];
    final markerColor = _computeDayMarkerColor(dayEntries);
    final hasEntries = dayEntries.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDay = DateTime(day.year, day.month, day.day);
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: cellHeight,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purpleLight.withValues(alpha: 0.18)
                : Colors.transparent,
            border: isToday
                ? Border.all(
                    color: AppColors.purpleLight.withValues(alpha: 0.5),
                    width: 1.2,
                  )
                : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.purple
                      : (isToday ? AppColors.purple : textColor),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              if (hasEntries && markerColor != null)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 4),
              const SizedBox(height: 3),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Selected-day content (below the calendar)
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildSelectedDayContent(
    BuildContext context,
    List<TradeEntry> entries,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color borderColor,
  ) {
    if (_selectedDay == null) {
      return _buildSelectDayPrompt(context, cardColor, textColor, subColor);
    }

    final dayKey = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final dayTrades = entries.where((t) {
      final k = t.exitDate ?? t.entryDate;
      return k.year == dayKey.year && k.month == dayKey.month && k.day == dayKey.day;
    }).toList();

    if (dayTrades.isEmpty) {
      return _buildNoEntriesForDay(context, dayKey, cardColor, textColor, subColor);
    }

    return _buildSelectedDayList(
      context,
      dayKey,
      dayTrades,
      cardColor,
      textColor,
      subColor,
      borderColor,
    );
  }

  Widget _buildSelectDayPrompt(
    BuildContext context,
    Color cardColor,
    Color textColor,
    Color subColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.touch_app_rounded,
                  size: 32,
                  color: subColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.reviewEmptyHeader,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.reviewEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoEntriesForDay(
    BuildContext context,
    DateTime selectedDay,
    Color cardColor,
    Color textColor,
    Color subColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_busy_rounded,
                  size: 32,
                  color: subColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.reviewNoTradesTitle,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.reviewNoTradesBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTradeScreen(initialEntryDate: selectedDay),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.reviewAddTradeForDay),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayList(
    BuildContext context,
    DateTime day,
    List<TradeEntry> trades,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color borderColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###');

    final sorted = [...trades]..sort((a, b) {
      final aKey = a.exitDate ?? a.entryDate;
      final bKey = b.exitDate ?? b.entryDate;
      return _sortOrder == _SortOrder.newestFirst
          ? bKey.compareTo(aKey)
          : aKey.compareTo(bKey);
    });

    final closedPnL =
        sorted.where((t) => t.isClosed).fold(0.0, (s, t) => s + t.profitLoss);
    final isProfit = closedPnL > 0;
    final isLossDay = closedPnL < 0;
    final dailyColor = isProfit
        ? AppColors.green
        : (isLossDay ? AppColors.red : AppColors.purpleLight);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top accent strip — same color logic as old date card
            Container(
              height: 3,
              width: double.infinity,
              color: dailyColor,
            ),
            // Compact date header (no calendar-cell, no aggregate P&L)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.monthDayWeekday(day.day, day.month, _weekdayShortList(l10n)[day.weekday - 1]),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.tradeCount(sorted.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: subColor.withValues(alpha: 0.12),
            ),
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                  color: subColor.withValues(alpha: 0.06),
                ),
              _buildDateTradeRow(
                context,
                l10n,
                sorted[i],
                formatter,
                false,
                textColor,
                subColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTradeRow(
    BuildContext context,
    AppLocalizations l10n,
    TradeEntry trade,
    NumberFormat formatter,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final isWin = trade.result == TradeResult.success;
    final isLoss = trade.result == TradeResult.failure;
    final isPending = trade.result == TradeResult.pending;

    final Color resultColor;
    final String resultLabel;
    if (isWin) {
      resultColor = AppColors.green;
      resultLabel = l10n.win;
    } else if (isLoss) {
      resultColor = AppColors.red;
      resultLabel = l10n.loss;
    } else {
      resultColor = AppColors.purpleLight;
      resultLabel = l10n.pendingOnly;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TradeDetailScreen(trade: trade)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg + AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: _buildCardHeader(
            trade: trade,
            isWin: isWin,
            isLoss: isLoss,
            isPending: isPending,
            resultColor: resultColor,
            resultLabel: resultLabel,
            formatter: formatter,
            textColor: textColor,
            subColor: subColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required TradeEntry trade,
    required bool isWin,
    required bool isLoss,
    required bool isPending,
    required Color resultColor,
    required String resultLabel,
    required NumberFormat formatter,
    required Color textColor,
    required Color subColor,
  }) {
    final dirColor = trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red;
    final dirIcon = trade.direction == TradeDirection.buy
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final dirLabel = trade.direction == TradeDirection.buy ? 'BUY' : 'SELL';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: dirColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(dirIcon, size: 18, color: dirColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.stockName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    trade.stockSymbol,
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildDirectionTag(dirLabel, dirColor),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMiniTag(resultLabel, resultColor),
            const SizedBox(height: AppSpacing.xs),
            if (trade.isClosed)
              Text(
                '${trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(trade.profitLoss, trade.market ?? inferMarketFromSymbol(trade.stockSymbol))}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: resultColor,
                  letterSpacing: -0.2,
                ),
              ),
            if (trade.isClosed)
              Text(
                '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: resultColor,
                ),
              )
            else
              Text(
                formatter.format(trade.entryPrice * trade.quantity),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectionTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
