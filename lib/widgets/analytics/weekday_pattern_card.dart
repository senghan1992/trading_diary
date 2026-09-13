import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Per-weekday performance card. Renders 7 mini bars (Mon..Sun) where
/// each bar's height encodes the win rate and the bar's colour encodes
/// the net P&L (positive → [upColor], negative → [downColor]).
///
/// Hover/tap is not implemented — the card is intentionally
/// read-only and sized small enough that adding touch handling would
/// make the tap target ambiguous inside a list.
class WeekdayPatternCard extends StatelessWidget {
  const WeekdayPatternCard({
    super.key,
    required this.rows,
    required this.upColor,
    required this.downColor,
    this.embedded = false,
  });

  final List<WeekdayPerformanceSummary> rows;
  final Color upColor;
  final Color downColor;
  final bool embedded;

  static const _shortNames = <String>[
    '월', // placeholder; replaced with localised strings at build time
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = AppColors.card;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final borderColor = AppColors.border;

    final names = <String>[
      l10n.weekdayShortMon,
      l10n.weekdayShortTue,
      l10n.weekdayShortWed,
      l10n.weekdayShortThu,
      l10n.weekdayShortFri,
      l10n.weekdayShortSat,
      l10n.weekdayShortSun,
    ];
    // Defensive: rows should always be 7 entries from the calculator;
    // fall back to a zero row if a malformed list sneaks through.
    final padded = List<WeekdayPerformanceSummary?>.filled(8, null);
    for (final r in rows) {
      if (r.weekday >= 1 && r.weekday <= 7) padded[r.weekday] = r;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.weekdayPatterns,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: List.generate(7, (i) {
            final weekday = i + 1;
            final row = padded[weekday];
            final name = i < names.length ? names[i] : _shortNames[i];
            return Expanded(
              child: _DayCell(
                name: name,
                summary: row,
                upColor: upColor,
                downColor: downColor,
                textColor: textColor,
                subColor: subColor,
              ),
            );
          }),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: content,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.name,
    required this.summary,
    required this.upColor,
    required this.downColor,
    required this.textColor,
    required this.subColor,
  });

  final String name;
  final WeekdayPerformanceSummary? summary;
  final Color upColor;
  final Color downColor;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final winRate = s?.winRate ?? 0;
    final net = s?.totalProfitLoss ?? 0;
    final hasTrades = (s?.tradeCount ?? 0) > 0;
    final barColor = net > 0
        ? upColor
        : net < 0
        ? downColor
        : subColor.withValues(alpha: 0.4);
    // Win rate -> bar height; clamp to 5..78 so the bar is always
    // visible but never overflows the row.
    final height = (winRate.clamp(0, 100) / 100) * 60 + 8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 68,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 12,
                height: hasTrades ? height : 6,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: hasTrades ? 1.0 : 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            hasTrades ? '${s!.tradeCount}' : '-',
            style: TextStyle(color: subColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
