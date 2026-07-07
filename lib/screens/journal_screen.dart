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

/// M6: timestamp of the last FAB tap, used to debounce rapid double-pushes.
/// Static so the value survives a parent rebuild (MainShell rebuilds
/// tabs when the notification-tap deep-link fires). One JournalScreen
/// instance exists in the app, so the static is safe.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});
  static DateTime? _lastFabTap;

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
    final tabColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          title: Text(l10n.journal, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
          centerTitle: false,
          actions: [],
        ),
        body: ResponsiveContainer(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AdBanner(),
              ),
              TabBar(
                indicatorColor: AppColors.purple,
                labelColor: AppColors.purple,
                unselectedLabelColor: subColor,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_outlined, size: 18, color: subColor),
                        const SizedBox(width: 6),
                        Text('${l10n.openPosition} (${provider.openPositions.length})', style: TextStyle(color: subColor)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: subColor),
                        const SizedBox(width: 6),
                        Text('${l10n.closedPosition} (${provider.closedPositions.length})', style: TextStyle(color: subColor)),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOpenPositions(context, provider, isDark, bgColor, cardColor, textColor, subColor, borderColor, tabColor),
                    _buildClosedTrades(context, provider, isDark, bgColor, cardColor, textColor, subColor, borderColor, tabColor),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          // M6: debounce rapid double-taps so the user doesn't stack duplicate
          // AddTradeScreen instances on the navigator. Tapping again within
          // 600 ms is a no-op; the spinner/transition takes longer than that
          // anyway, so it never feels unresponsive.
          onPressed: () {
            final now = DateTime.now();
            if (_lastFabTap != null &&
                now.difference(_lastFabTap!) < const Duration(milliseconds: 600)) {
              return;
            }
            _lastFabTap = now;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTradeScreen()),
            );
          },
          backgroundColor: AppColors.purple,
          icon: const Icon(Icons.add),
          label: Text(l10n.addTrade),
        ),
      ),
    );
  }

  Widget _buildOpenPositions(BuildContext context, TradeProvider provider, bool isDark, Color bgColor, Color cardColor, Color textColor, Color subColor, Color borderColor, Color tabColor) {
    final l10n = AppLocalizations.of(context)!;
    final positions = provider.openPositions;

    if (positions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: l10n.noTradesYet,
        subtitle: l10n.emptyOpenPositions,
        textColor: textColor,
        subColor: subColor,
        cardColor: cardColor,
      );
    }

    return _buildCardList(
      context,
      positions,
      (ctx, trade) => _buildPositionCard(ctx, trade, provider, isDark, bgColor, cardColor, textColor, subColor, borderColor),
    );
  }

  Widget _buildClosedTrades(BuildContext context, TradeProvider provider, bool isDark, Color bgColor, Color cardColor, Color textColor, Color subColor, Color borderColor, Color tabColor) {
    final l10n = AppLocalizations.of(context)!;
    final trades = provider.closedPositions;

    if (trades.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book_outlined,
        title: l10n.noTradesYet,
        subtitle: l10n.emptyClosedTrades,
        textColor: textColor,
        subColor: subColor,
        cardColor: cardColor,
      );
    }

    return _buildCardList(
      context,
      trades,
      (ctx, trade) => _buildTradeCard(ctx, trade, provider, isDark, bgColor, cardColor, textColor, subColor, borderColor),
    );
  }

  Widget _buildCardList(
    BuildContext context,
    List<TradeEntry> trades,
    Widget Function(BuildContext, TradeEntry) itemBuilder,
  ) {
    if (context.isMediumOrUp) {
      // Tablet grid. The trade cards' content height is fixed by the layout
      // (Row of stock info + close-position button + 3 info chips for closed
      // trades), so we use `mainAxisExtent` (fixed height in dp) instead of
      // `childAspectRatio`. The previous childAspectRatio: 2.2 produced
      // ~138-dp cells on iPad landscape (3 columns of ~304 dp), but the
      // card content needs ~162 dp — Padding(32) + Row(44) + gap(12) +
      // OutlinedButton(40) + InfoChips row(44). That overflowed every card
      // and triggered a RenderFlex assertion in iPad landscape.
      //
      // 178 dp gives ~16 dp of slack for longer stock names or labels that
      // push a text line onto two lines.
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 178,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
        ),
        itemCount: trades.length,
        itemBuilder: (_, i) => itemBuilder(context, trades[i]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: trades.length,
      itemBuilder: (_, i) => itemBuilder(context, trades[i]),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle, required Color textColor, required Color subColor, required Color cardColor}) {
    // Same overflow guard as `_StockPickerSheet._buildEmptyPlaceholder`:
    // the parent is an Expanded inside the tab view, so on a short
    // landscape-tablet viewport the previous Center could not fit its
    // column. LayoutBuilder + ConstrainedBox keeps the centered layout
    // when the content fits and falls back to scrolling when it doesn't.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 36, color: subColor.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionCard(BuildContext context, TradeEntry trade, TradeProvider provider, bool isDark, Color bgColor, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###');
    final dirColor = trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red;

    return Dismissible(
      key: Key(trade.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      // B4 guard: previously fire-and-forget so a Hive failure surfaced as
      // an unhandled future error and left the in-memory list out of sync
      // with disk. Now awaited inside a guarded async lambda.
      onDismissed: (_) async {
        try {
          await provider.deleteTrade(trade.id);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TradeDetailScreen(trade: trade)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: dirColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          trade.direction == TradeDirection.buy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: dirColor,
                          size: 20,
                        ),
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
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildMiniTag(l10n.openPosition, AppColors.purpleLight),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTradeMoney(trade.entryPrice * trade.quantity, trade.market ?? inferMarketFromSymbol(trade.stockSymbol)),
                            maxLines: 1,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${trade.quantity}${l10n.sharesUnit} @ ${formatter.format(trade.entryPrice)}',
                            maxLines: 1,
                            style: TextStyle(
                              color: subColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showClosePositionDialog(context, trade, provider),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: Text(l10n.closePosition),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green,
                        side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeCard(BuildContext context, TradeEntry trade, TradeProvider provider, bool isDark, Color bgColor, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    final l10n = AppLocalizations.of(context)!;
    final isWin = trade.result == TradeResult.success;
    final resultColor = isWin ? AppColors.green : AppColors.red;

    return Dismissible(
      key: Key(trade.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      // B4 guard: see _buildPositionCard above for the rationale.
      onDismissed: (_) async {
        try {
          await provider.deleteTrade(trade.id);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TradeDetailScreen(trade: trade)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          isWin ? Icons.emoji_events_outlined : Icons.trending_down_rounded,
                          color: resultColor,
                          size: 20,
                        ),
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
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildMiniTag(
                              isWin ? 'WIN' : 'LOSS',
                              resultColor,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(trade.profitLoss, trade.market ?? inferMarketFromSymbol(trade.stockSymbol))}',
                            maxLines: 1,
                            style: TextStyle(
                              color: resultColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                            maxLines: 1,
                            style: TextStyle(
                              color: resultColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(l10n.entryPrice, formatTradeMoney(trade.entryPrice, trade.market ?? inferMarketFromSymbol(trade.stockSymbol)), bgColor, textColor, subColor),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildInfoChip(l10n.exitPrice, trade.exitPrice != null ? formatTradeMoney(trade.exitPrice!, trade.market ?? inferMarketFromSymbol(trade.stockSymbol)) : '—', bgColor, textColor, subColor),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildInfoChip(l10n.shares, '${trade.quantity}${l10n.sharesUnit}', bgColor, textColor, subColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color bgColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: subColor,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showClosePositionDialog(BuildContext context, TradeEntry trade, TradeProvider provider) {
    // H12: the sheet body used to be inline `StatefulBuilder` with a
    // TextEditingController created in this method's scope. When the user
    // dismissed via scrim, the controller was never disposed. We now push a
    // dedicated StatefulWidget that owns + disposes the controller.
    ResponsiveSheet.show<void>(
      context: context,
      builder: (_) => _ClosePositionSheet(trade: trade, provider: provider),
    );
  }
}

/// Modal sheet for closing an open position. Owns its TextEditingController
/// so it is disposed cleanly even when the user dismisses via scrim (the
/// previous StatefulBuilder pattern leaked the controller on every dismissal).
class _ClosePositionSheet extends StatefulWidget {
  final TradeEntry trade;
  final TradeProvider provider;
  const _ClosePositionSheet({required this.trade, required this.provider});

  @override
  State<_ClosePositionSheet> createState() => _ClosePositionSheetState();
}

class _ClosePositionSheetState extends State<_ClosePositionSheet> {
  late final TextEditingController _exitPriceCtrl;
  late DateTime _exitDate;

  @override
  void initState() {
    super.initState();
    _exitPriceCtrl = TextEditingController();
    _exitDate = DateTime.now();
  }

  @override
  void dispose() {
    _exitPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.closePosition, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(widget.trade.stockName, style: TextStyle(color: subColor, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _exitPriceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: l10n.exitPrice,
              labelStyle: TextStyle(color: subColor),
              prefixText:
                  '${currencySymbolFor(widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol))} ',
              prefixStyle: TextStyle(color: textColor),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _exitDate,
                firstDate: widget.trade.entryDate,
                lastDate: DateTime.now(),
                builder: (_, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(primary: AppColors.purple),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _exitDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.exitDate, style: TextStyle(color: subColor)),
                  Row(
                    children: [
                      Text(DateFormat('yyyy-MM-dd').format(_exitDate), style: TextStyle(color: textColor)),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today, color: subColor, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDark ? AppColors.borderGray : AppColors.lightBorder),
                  ),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // M3: trim before parse so " 1000" works, and surface
                    // a SnackBar when the input is bad instead of the
                    // silent no-op the previous code did.
                    final exitPrice =
                        double.tryParse(_exitPriceCtrl.text.trim());
                    if (exitPrice == null || exitPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('올바른 매도가를 입력해주세요.'),
                          backgroundColor: AppColors.red,
                        ),
                      );
                      return;
                    }
                    // B3 guard: previously fire-and-forget, so any throw
                    // inside closePosition surfaced as an unhandled future
                    // error and the sheet silently closed without saving.
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    try {
                      await widget.provider.closePosition(
                        tradeId: widget.trade.id,
                        exitPrice: exitPrice,
                        exitDate: _exitDate,
                      );
                      if (!mounted) return;
                      navigator.pop();
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('저장에 실패했습니다. 잠시 후 다시 시도해주세요.'),
                          backgroundColor: AppColors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
