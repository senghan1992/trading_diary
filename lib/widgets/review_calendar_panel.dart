import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/stock.dart';
import '../models/trade_entry.dart';
import '../providers/trade_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'responsive_layout.dart';
import 'trade_detail_screen.dart';
import '../screens/add_trade_screen.dart';

/// State filter for the trade calendar sub-view.
enum ReviewStateFilter { all, closed, open }

/// Result filter for the trade calendar sub-view.
enum ReviewResultFilter { all, wins, losses, pending }

/// Sort order for the trade calendar sub-view.
enum ReviewSortOrder { newestFirst, oldestFirst }

/// Reusable review-calendar panel: month grid + filter chips + the
/// "selected day" trade list. Lifted out of `ReviewScreen` so the new
/// `AnalyticsScreen` can embed it as a tab body without duplicating
/// the calendar UX or the helpers that build day-entries maps.
class ReviewCalendarPanel extends StatefulWidget {
  const ReviewCalendarPanel({super.key});

  @override
  State<ReviewCalendarPanel> createState() => _ReviewCalendarPanelState();
}

class _ReviewCalendarPanelState extends State<ReviewCalendarPanel> {
  ReviewStateFilter _stateFilter = ReviewStateFilter.all;
  ReviewResultFilter _resultFilter = ReviewResultFilter.all;
  ReviewSortOrder _sortOrder = ReviewSortOrder.newestFirst;

  /// Optional account filter for the calendar chips row. Null = all
  /// accounts.
  String? _accountFilter;

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

  List<TradeEntry> _applyFilters(TradeProvider provider) {
    final filtered = provider.filteredTrades.where((t) {
      final tag = _accountFilter;
      if (tag != null && t.accountTag != tag) return false;
      switch (_stateFilter) {
        case ReviewStateFilter.all:
          break;
        case ReviewStateFilter.closed:
          if (!t.isClosed) return false;
          break;
        case ReviewStateFilter.open:
          if (t.isClosed) return false;
          break;
      }
      switch (_resultFilter) {
        case ReviewResultFilter.all:
          break;
        case ReviewResultFilter.wins:
          if (t.result != TradeResult.success) return false;
          break;
        case ReviewResultFilter.losses:
          if (t.result != TradeResult.failure) return false;
          break;
        case ReviewResultFilter.pending:
          if (t.result != TradeResult.pending) return false;
          break;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.exitDate ?? a.entryDate;
      final bDate = b.exitDate ?? b.entryDate;
      return _sortOrder == ReviewSortOrder.newestFirst
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();
    final bgColor = AppColors.bg;
    final cardColor = AppColors.card;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final borderColor = AppColors.border;

    final entries = _applyFilters(provider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (context.isExpandedOrUp) {
      return Container(
        color: bgColor,
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCalendar(
                  l10n: l10n,
                  provider: provider,
                  entries: entries,
                  today: today,
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
                    _buildSelectedDayContent(
                      context,
                      entries,
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

    return Container(
      color: bgColor,
      child: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            _buildFilterRow(context, l10n, textColor, subColor),
            _buildCalendar(
              l10n: l10n,
              provider: provider,
              entries: entries,
              today: today,
              cardColor: cardColor,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
            ),
            _buildSelectedDayContent(
              context,
              entries,
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

  Widget _buildFilterRow(
    BuildContext context,
    AppLocalizations l10n,
    Color textColor,
    Color subColor,
  ) {
    final stateGroup = <(ReviewStateFilter, IconData, String)>[
      (ReviewStateFilter.all, Icons.all_inclusive_rounded, l10n.allStates),
      (
        ReviewStateFilter.closed,
        Icons.check_circle_outline_rounded,
        l10n.closedPosition,
      ),
      (ReviewStateFilter.open, Icons.access_time_rounded, l10n.openPosition),
    ];
    final resultGroup = <(ReviewResultFilter, IconData, String)>[
      (ReviewResultFilter.all, Icons.all_inclusive_rounded, l10n.allResults),
      (ReviewResultFilter.wins, Icons.trending_up_rounded, l10n.winsOnly),
      (ReviewResultFilter.losses, Icons.trending_down_rounded, l10n.lossesOnly),
      (ReviewResultFilter.pending, Icons.access_time_rounded, l10n.pendingOnly),
    ];
    final sortGroup = <(ReviewSortOrder, IconData, String)>[
      (
        ReviewSortOrder.newestFirst,
        Icons.arrow_downward_rounded,
        l10n.newestFirst,
      ),
      (
        ReviewSortOrder.oldestFirst,
        Icons.arrow_upward_rounded,
        l10n.oldestFirst,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipGroup<ReviewStateFilter>(
            context: context,
            label: l10n.stateFilter,
            options: stateGroup,
            current: _stateFilter,
            textColor: textColor,
            subColor: subColor,
            onSelected: (v) {
              setState(() => _stateFilter = v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildChipGroup<ReviewResultFilter>(
            context: context,
            label: l10n.resultFilter,
            options: resultGroup,
            current: _resultFilter,
            textColor: textColor,
            subColor: subColor,
            onSelected: (v) {
              setState(() => _resultFilter = v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildChipGroup<ReviewSortOrder>(
            context: context,
            label: l10n.sort,
            options: sortGroup,
            current: _sortOrder,
            textColor: textColor,
            subColor: subColor,
            onSelected: (v) {
              setState(() => _sortOrder = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup<T>({
    required BuildContext context,
    required String label,
    required List<(T, IconData, String)> options,
    required T current,
    required Color textColor,
    required Color subColor,
    required ValueChanged<T> onSelected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subColor,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opt in options)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _buildFilterChip(
                      icon: opt.$2,
                      label: opt.$3,
                      isSelected: opt.$1 == current,
                      onTap: () => onSelected(opt.$1),
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Horizontal account-filter chips shown at the top of the calendar so
  /// the user can view a single broker/account's monthly history.
  Widget _buildCalendarAccountChips(TradeProvider provider, Color subColor) {
    final accounts = provider.accounts;
    if (accounts.isEmpty) return const SizedBox.shrink();
    Widget chip(String? tag, String label, Color? dotColor) {
      final isSelected = _accountFilter == tag;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          selectedColor: AppColors.accentSubtle,
          side: BorderSide(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _accountFilter = tag),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        physics: const BouncingScrollPhysics(),
        children: [
          chip(null, AppLocalizations.of(context)!.allAccounts, null),
          for (final a in accounts)
            chip(
              a.name,
              a.name,
              a.colorValue != null ? Color(a.colorValue!) : subColor,
            ),
        ],
      ),
    );
  }


  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subColor,
  }) {
    final accent = AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? accent : subColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? accent : subColor.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? accent : subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar({
    required AppLocalizations l10n,
    required TradeProvider provider,
    required List<TradeEntry> entries,
    required DateTime today,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    double cellHeight = 44,
  }) {
    final dayEntriesMap = _buildDayEntriesMap(entries);
    final monthStart = _calendarMonth;
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
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
        boxShadow: AppColors.cardShadow,
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
            child: _buildCalendarMonthNav(
              l10n: l10n,
              textColor: textColor,
              subColor: subColor,
            ),
          ),
          _buildCalendarAccountChips(provider, subColor),
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

  Map<DateTime, List<TradeEntry>> _buildDayEntriesMap(
    List<TradeEntry> entries,
  ) {
    final map = <DateTime, List<TradeEntry>>{};
    for (final t in entries) {
      final entryDay = DateTime(
        t.entryDate.year,
        t.entryDate.month,
        t.entryDate.day,
      );
      map.putIfAbsent(entryDay, () => []).add(t);
      final exitDate = t.exitDate;
      if (exitDate != null) {
        final exitDay = DateTime(exitDate.year, exitDate.month, exitDate.day);
        if (exitDay != entryDay) {
          map.putIfAbsent(exitDay, () => []).add(t);
        }
      }
    }
    return map;
  }

  Widget _buildCalendarMonthNav({
    required AppLocalizations l10n,
    required Color textColor,
    required Color subColor,
  }) {
    final now = DateTime.now();
    final isCurrentMonth =
        _calendarMonth.year == now.year && _calendarMonth.month == now.month;

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
                color: AppColors.accent,
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

  Widget _buildCalendarWeekdayHeader({
    required AppLocalizations l10n,
    required Color subColor,
  }) {
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

  List<String> _weekdayShortList(AppLocalizations l10n) => <String>[
    l10n.weekdayShortMon,
    l10n.weekdayShortTue,
    l10n.weekdayShortWed,
    l10n.weekdayShortThu,
    l10n.weekdayShortFri,
    l10n.weekdayShortSat,
    l10n.weekdayShortSun,
  ];

  Widget _buildCalendarDayCell({
    required DateTime? day,
    required bool isCurrentMonth,
    required DateTime today,
    required Map<DateTime, List<TradeEntry>> dayEntriesMap,
    required Color textColor,
    required Color subColor,
    required double cellHeight,
  }) {
    if (day == null) {
      return Expanded(child: SizedBox(height: cellHeight));
    }
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final isSelected =
        _selectedDay != null &&
        _selectedDay!.year == day.year &&
        _selectedDay!.month == day.month &&
        _selectedDay!.day == day.day;
    final dayEntries = dayEntriesMap[day] ?? const [];
    final marker = _dayMarkerColor(dayEntries);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDay = day);
        },
        child: Container(
          height: cellHeight,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isToday
                ? Border.all(color: AppColors.accent, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrentMonth
                      ? textColor
                      : subColor.withValues(alpha: 0.5),
                ),
              ),
              if (marker != null) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _dayCellBadge(dayEntries),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: marker,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color? _dayMarkerColor(List<TradeEntry> dayEntries) {
    if (dayEntries.isEmpty) return null;
    final closed = dayEntries.where((t) => t.isClosed).toList();
    final hasPending = dayEntries.any((t) => !t.isClosed);
    if (closed.isEmpty) {
      return hasPending ? AppColors.markerNeutral : null;
    }
    final pnl = closed.fold(0.0, (s, t) => s + t.profitLoss);
    if (pnl > 0) return AppColors.markerWin;
    if (pnl < 0) return AppColors.markerLoss;
    return AppColors.markerNeutral;
  }

  /// Compact per-day badge: realized P&L when the day has closed trades,
  /// otherwise the open-position count.
  String _dayCellBadge(List<TradeEntry> dayEntries) {
    final closed = dayEntries.where((t) => t.isClosed).toList();
    if (closed.isEmpty) return '${dayEntries.length}건';
    final pnl = closed.fold(0.0, (s, t) => s + t.profitLoss);
    final sign = pnl > 0 ? '+' : '';
    return '$sign${NumberFormat.compact().format(pnl)}';
  }
  Widget _buildSelectedDayContent(
    BuildContext context,
    List<TradeEntry> entries,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color borderColor,
  ) {
    final day = _selectedDay;
    if (day == null) {
      return _buildSelectDayPrompt(
        context,
        cardColor,
        textColor,
        subColor,
        borderColor,
      );
    }

    final dayKey = DateTime(day.year, day.month, day.day);
    final dayTrades = entries.where((t) {
      final entryDay = DateTime(
        t.entryDate.year,
        t.entryDate.month,
        t.entryDate.day,
      );
      if (entryDay == dayKey) return true;
      if (t.exitDate == null) return false;
      final exitDay = DateTime(
        t.exitDate!.year,
        t.exitDate!.month,
        t.exitDate!.day,
      );
      return exitDay == dayKey;
    }).toList();

    if (dayTrades.isEmpty) {
      return _buildNoEntriesForDay(
        context,
        day,
        cardColor,
        textColor,
        subColor,
        borderColor,
      );
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
    Color borderColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviewEmptyHeader,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.reviewEmptyBody,
            style: TextStyle(color: subColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEntriesForDay(
    BuildContext context,
    DateTime selectedDay,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color borderColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final weekday = DateFormat(
      'E',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(selectedDay);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.monthDayWeekday(selectedDay.month, selectedDay.day, weekday),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.reviewNoTradesBody,
            style: TextStyle(color: subColor, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddTradeScreen(initialEntryDate: selectedDay),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              l10n.addTradeOnDate(selectedDay.month, selectedDay.day),
            ),
          ),
        ],
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
    final weekday = DateFormat(
      'E',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(day);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.monthDayWeekday(day.month, day.day, weekday),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTradeScreen(initialEntryDate: day),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    l10n.reviewAddTradeForDay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < trades.length; i++) ...[
            _buildDateTradeRow(
              context,
              l10n,
              trades[i],
              textColor,
              subColor,
              borderColor,
            ),
            if (i < trades.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Divider(height: 1, thickness: 0.5, color: borderColor),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildDateTradeRow(
    BuildContext context,
    AppLocalizations l10n,
    TradeEntry trade,
    Color textColor,
    Color subColor,
    Color borderColor,
  ) {
    final isWin = trade.profitLoss > 0;
    final isLoss = trade.profitLoss < 0;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TradeDetailScreen(trade: trade)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: _buildCardHeader(
          trade: trade,
          isWin: isWin,
          isLoss: isLoss,
          textColor: textColor,
          subColor: subColor,
          l10n: l10n,
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required TradeEntry trade,
    required bool isWin,
    required bool isLoss,
    required Color textColor,
    required Color subColor,
    required AppLocalizations l10n,
  }) {
    final directionLabel = trade.direction == TradeDirection.buy
        ? l10n.buy
        : l10n.sell;
    final directionColor = trade.direction == TradeDirection.buy
        ? AppColors.red
        : AppColors.blue;

    final pnlColor = isWin
        ? AppColors.green
        : isLoss
        ? AppColors.red
        : subColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                trade.stockName.isNotEmpty
                    ? trade.stockName
                    : trade.stockSymbol,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            _buildDirectionTag(directionLabel, directionColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              trade.isClosed ? l10n.realizedPL : l10n.unrealizedPLLabel,
              style: TextStyle(color: subColor, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Text(
              trade.isClosed
                  ? '${trade.profitLoss >= 0 ? '+' : '-'}${_shortAmount(trade.profitLoss.abs(), trade.market)}'
                  : '-',
              style: TextStyle(
                color: pnlColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              l10n.sharesWithUnit(trade.quantity),
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${l10n.entryPrice} ${_shortAmount(trade.entryPrice, trade.market)}',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            if (trade.exitPrice != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${l10n.exitPrice} ${_shortAmount(trade.exitPrice!, trade.market)}',
                style: TextStyle(color: subColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _shortAmount(double amount, MarketType? market) {
    final symbol = market == MarketType.nasdaq ? r'$' : '₩';
    final isInt = market != MarketType.nasdaq;
    final formatted = isInt
        ? NumberFormat('#,##0').format(amount)
        : NumberFormat('#,##0.00').format(amount);
    return '$symbol$formatted';
  }

  Widget _buildDirectionTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
