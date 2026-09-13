import 'package:flutter/material.dart';

import '../models/trade_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/review_calendar_panel.dart';

/// Builds a date → trades map. A trade contributes to BOTH its entry day
/// and (when closed) its exit day — entering a position on Monday and
/// closing it Friday means the trade lights up the calendar on both
/// days. The day's chrome reads chronologically: entry-only (pending)
/// uses the indigo "open" marker on the entry day, and the result color
/// on the exit day.
///
/// Exposed at file scope (rather than as a `_ReviewScreenState` method) so
/// a unit test can exercise it without spinning up a full Flutter widget
/// tree. The behavior is identical to what the widget renders.
@visibleForTesting
Map<DateTime, List<TradeEntry>> buildDayEntriesMapForReview(
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

/// Picks the strongest signal among all trades on a day so the marker
/// colour communicates the day's outcome at a glance:
///   • emerald green   → at least one closed trade with positive P&L
///   • rose red        → at least one closed trade with negative P&L
///   • indigo blue     → only open positions / pending trades (entry-only)
@visibleForTesting
Color? reviewDayMarkerColor(List<TradeEntry> dayEntries) {
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

/// The review screen is now just a thin wrapper around the shared
/// [ReviewCalendarPanel]. The panel widget lives under `lib/widgets/`
/// so the analytics screen can embed it as a tab body without
/// duplicating the calendar UX.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewCalendarPanel();
  }
}
