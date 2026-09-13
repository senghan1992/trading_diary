import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/stock.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Sort order selector for the per-stock performance list. Controls the
/// ranking without changing the underlying filter.
enum _StockSort {
  /// Highest realised P&L first.
  pnlDesc,

  /// Lowest realised P&L first (biggest losses).
  pnlAsc,

  /// Most trades first.
  tradeCount,
}

/// Per-stock performance ranking card. Shows a sort selector and a
/// scrollable list of [StockPerformanceSummary] rows; tapping a row
/// invokes [onTap] (typically to filter the journal or open the
/// detail screen for that stock).
class StockPerformanceList extends StatefulWidget {
  const StockPerformanceList({
    super.key,
    required this.rows,
    required this.upColor,
    required this.downColor,
    this.onTap,
  });

  final List<StockPerformanceSummary> rows;
  final Color upColor;
  final Color downColor;
  final void Function(StockPerformanceSummary row)? onTap;

  @override
  State<StockPerformanceList> createState() => _StockPerformanceListState();
}

class _StockPerformanceListState extends State<StockPerformanceList> {
  _StockSort _sort = _StockSort.pnlDesc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = AppColors.card;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final borderColor = AppColors.border;

    final sorted = [...widget.rows];
    switch (_sort) {
      case _StockSort.pnlDesc:
        sorted.sort((a, b) => b.totalProfitLoss.compareTo(a.totalProfitLoss));
        break;
      case _StockSort.pnlAsc:
        sorted.sort((a, b) => a.totalProfitLoss.compareTo(b.totalProfitLoss));
        break;
      case _StockSort.tradeCount:
        sorted.sort((a, b) => b.tradeCount.compareTo(a.tradeCount));
        break;
    }

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.stockRankings,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              _buildSortMenu(l10n, textColor, subColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  l10n.noClosedTrades,
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ),
            )
          else
            ...sorted
                .take(20)
                .map(
                  (row) => _StockRow(
                    summary: row,
                    textColor: textColor,
                    subColor: subColor,
                    upColor: widget.upColor,
                    downColor: widget.downColor,
                    borderColor: borderColor,
                    onTap: widget.onTap == null
                        ? null
                        : () => widget.onTap!(row),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSortMenu(
    AppLocalizations l10n,
    Color textColor,
    Color subColor,
  ) {
    return PopupMenuButton<_StockSort>(
      tooltip: l10n.sort,
      icon: Icon(Icons.sort_rounded, color: subColor, size: 20),
      color: AppColors.card,
      onSelected: (s) => setState(() => _sort = s),
      itemBuilder: (context) => [
        PopupMenuItem(value: _StockSort.pnlDesc, child: Text(l10n.topGainers)),
        PopupMenuItem(value: _StockSort.pnlAsc, child: Text(l10n.topLosers)),
        PopupMenuItem(
          value: _StockSort.tradeCount,
          child: Text(l10n.totalTrades),
        ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.summary,
    required this.textColor,
    required this.subColor,
    required this.upColor,
    required this.downColor,
    required this.borderColor,
    this.onTap,
  });

  final StockPerformanceSummary summary;
  final Color textColor;
  final Color subColor;
  final Color upColor;
  final Color downColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pnlColor = summary.totalProfitLoss > 0
        ? upColor
        : summary.totalProfitLoss < 0
        ? downColor
        : subColor;
    final marketLabel = summary.market == null
        ? ''
        : (summary.market == MarketType.kospi
              ? 'KOSPI'
              : summary.market == MarketType.kosdaq
              ? 'KOSDAQ'
              : 'NASDAQ');

    final sign = summary.totalProfitLoss >= 0 ? '+' : '-';
    final fmt = summary.market == MarketType.nasdaq
        ? NumberFormat.currency(symbol: r'$', decimalDigits: 2)
        : NumberFormat.currency(symbol: '₩', decimalDigits: 0);
    final amountText = '$sign${fmt.format(summary.totalProfitLoss.abs())}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary.stockName.isNotEmpty
                              ? summary.stockName
                              : summary.stockSymbol,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (marketLabel.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: subColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            marketLabel,
                            style: TextStyle(
                              color: subColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.tradeCount}회 · 승률 ${summary.winRate.toStringAsFixed(0)}%',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.averageReturnPercent.toStringAsFixed(1)}%',
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
