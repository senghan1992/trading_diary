import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../providers/trade_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/responsive_layout.dart';
import 'trade_action_sheet.dart';

class TradeDetailScreen extends StatefulWidget {
  final TradeEntry trade;

  const TradeDetailScreen({super.key, required this.trade});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Local mirror of the trade's account tag so the badge updates
  /// immediately after the user reassigns it (the parent passes an
  /// immutable TradeEntry that won't rebuild this screen).
  String? _accountTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _accountTag = widget.trade.accountTag;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final upColor = themeProvider.upColor;
    final downColor = themeProvider.downColor;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          widget.trade.stockName,
          style:  TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(text: l10n.tabOverview),
            Tab(text: l10n.tabAnalysis),
          ],
        ),
      ),
      body: ResponsiveContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(context, l10n, upColor, downColor),
            _buildAnalysisTab(context, l10n, provider, upColor, downColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    AppLocalizations l10n,
    Color upColor,
    Color downColor,
  ) {
    final provider = context.watch<TradeProvider>();
    final currentTrade = provider.trades.where((t) => t.id == widget.trade.id).firstOrNull ?? widget.trade;
    final formatter = NumberFormat('#,###');
    final isWin = currentTrade.profitLoss >= 0;
    final resultColor = currentTrade.isClosed
        ? (isWin ? upColor : downColor)
        : AppColors.accent;
    final notes = provider.getNotesForTrade(currentTrade.id);
    final thesisNotes = notes.where((n) => n.category == 'thesis').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(currentTrade, l10n, formatter, isWin, resultColor),
          if (!currentTrade.isClosed) ...[
            const SizedBox(height: 12),
            _buildQuickActionButtons(context, currentTrade, upColor, downColor),
          ],
          const SizedBox(height: 20),
          _buildExecutionHistoryCard(context, currentTrade, l10n, formatter, upColor, downColor),
          const SizedBox(height: 20),
          TradeVisualizerCard(
            trade: currentTrade,
            upColor: upColor,
            downColor: downColor,
            accountTag: _accountTag,
            accountColor: _resolveAccountColor(),
          ),
          const SizedBox(height: 20),
          if (currentTrade.reason != null && currentTrade.reason!.isNotEmpty) ...[
            _buildInfoCard(
              l10n.tradeReasonLabel,
              currentTrade.reason!,
              Icons.lightbulb_outline,
              AppColors.orange,
            ),
            const SizedBox(height: 16),
          ],
          if (thesisNotes.isNotEmpty) ...[
            _buildNotesSection(l10n.tradeIdeaLabel, thesisNotes),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(
    BuildContext context,
    TradeEntry currentTrade,
    Color upColor,
    Color downColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => TradeActionSheet.show(
              context,
              trade: currentTrade,
              initialTab: TradeActionTab.buy,
            ),
            icon: Icon(Icons.add_circle_outline, size: 18, color: upColor),
            label: Text(
              '추가 매수',
              style: TextStyle(
                color: upColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: upColor.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => TradeActionSheet.show(
              context,
              trade: currentTrade,
              initialTab: TradeActionTab.sell,
            ),
            icon: const Icon(Icons.sell_outlined, size: 18, color: Colors.white),
            label: const Text(
              '분할 / 전량 매도',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: downColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Brand color of the account tag currently assigned to this trade,
  /// looked up from [TradeProvider.accounts]; null when unassigned.
  Color? _resolveAccountColor() {
    final tag = _accountTag;
    if (tag == null || tag.isEmpty) return null;
    final match = context
        .read<TradeProvider>()
        .accounts
        .where((a) => a.name == tag)
        .firstOrNull;
    return match?.colorValue != null ? Color(match!.colorValue!) : null;
  }

  Widget _buildSummaryCard(
    TradeEntry currentTrade,
    AppLocalizations l10n,
    NumberFormat formatter,
    bool isWin,
    Color resultColor,
  ) {
    final isClosed = currentTrade.isClosed;
    final statusText = isClosed
        ? l10n.tradeStatusClosed
        : l10n.tradeStatusOpen;
    final market =
        currentTrade.market ?? inferMarketFromSymbol(currentTrade.stockSymbol);
    final heldQty = currentTrade.remainingQuantity > 0
        ? currentTrade.remainingQuantity
        : currentTrade.quantity;
    final positionValue = currentTrade.entryPrice * heldQty;

    // 헤더 카테고리 라벨, 메인 텍스트, 서브 위젯 결정
    final String headerCategoryLabel;
    final String headerMainText;
    final Color headerMainColor;
    final Widget? headerSubWidget;

    if (isClosed) {
      headerCategoryLabel = l10n.realizedPL;
      final sign = currentTrade.profitLoss > 0
          ? '+'
          : (currentTrade.profitLoss < 0 ? '-' : '');
      headerMainText =
          '$sign${formatTradeMoney(currentTrade.profitLoss.abs(), market)}';
      headerMainColor = resultColor;
      headerSubWidget = Text(
        '${currentTrade.profitLossPercent >= 0 ? '+' : ''}${currentTrade.profitLossPercent.toStringAsFixed(2)}%',
        maxLines: 1,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: resultColor,
        ),
      );
    } else if (currentTrade.profitLoss != 0) {
      // 진행중이지만 분할 매도로 실현손익이 일부 발생한 경우
      headerCategoryLabel = '보유 금액';
      headerMainText = formatTradeMoney(positionValue, market);
      headerMainColor = AppColors.text;
      final sign = currentTrade.profitLoss > 0 ? '+' : '-';
      headerSubWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '실현 $sign${formatTradeMoney(currentTrade.profitLoss.abs(), market)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: resultColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${currentTrade.profitLossPercent >= 0 ? '+' : ''}${currentTrade.profitLossPercent.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: resultColor,
            ),
          ),
        ],
      );
    } else {
      // 진행중이며 매도 전 (스크린샷 상태: 0원 대신 총 매수 금액 명확히 표시)
      headerCategoryLabel = '총 매수 금액';
      headerMainText = formatTradeMoney(positionValue, market);
      headerMainColor = AppColors.text;

      final heldDays =
          DateTime.now().difference(currentTrade.entryDate).inDays;
      final dayText = heldDays == 0 ? '오늘 매수' : '$heldDays일째 보유 중';

      headerSubWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accentSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              '$dayText · ${formatter.format(heldQty)}주',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card, AppColors.card.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBadge(statusText, resultColor),
                  const SizedBox(height: 8),
                  Text(
                    currentTrade.stockSymbol,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAccountBadge(l10n),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headerCategoryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      headerMainText,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: headerMainColor,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  headerSubWidget,
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  currentTrade.hasExecutions ? '평균 매수가' : l10n.entryPrice,
                  formatTradeMoney(currentTrade.entryPrice, market),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  currentTrade.hasExecutions ? '평균 매도가' : l10n.exitPrice,
                  currentTrade.exitPrice != null
                      ? formatTradeMoney(currentTrade.exitPrice!, market)
                      : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  currentTrade.hasExecutions && !currentTrade.isClosed
                      ? '잔여 / 총수량'
                      : l10n.shares,
                  currentTrade.hasExecutions && !currentTrade.isClosed
                      ? '${formatter.format(currentTrade.remainingQuantity)} / ${formatter.format(currentTrade.quantity)}주'
                      : l10n.sharesWithUnit(currentTrade.quantity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  l10n.entryDate,
                  DateFormat('yyyy.MM.dd').format(currentTrade.entryDate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  currentTrade.isClosed ? '최종 청산일' : l10n.exitDate,
                  currentTrade.exitDate != null
                      ? DateFormat('yyyy.MM.dd').format(currentTrade.exitDate!)
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionHistoryCard(
    BuildContext context,
    TradeEntry currentTrade,
    AppLocalizations l10n,
    NumberFormat formatter,
    Color upColor,
    Color downColor,
  ) {
    final market = currentTrade.market ?? inferMarketFromSymbol(currentTrade.stockSymbol);
    final symbol = currencySymbolFor(market);
    final snapshots = currentTrade.getExecutionSnapshots();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '체결 및 분할 매매 내역',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      currentTrade.hasExecutions
                          ? '총 ${snapshots.length}회의 체결 기록'
                          : (currentTrade.isClosed ? '총 2회의 체결 기록' : '1차 진입 체결 완료'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!currentTrade.isClosed)
                TextButton.icon(
                  onPressed: () => TradeActionSheet.show(
                    context,
                    trade: currentTrade,
                    initialTab: TradeActionTab.buy,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('기록 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (currentTrade.hasExecutions) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshots.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Container(
                  width: 2,
                  height: 16,
                  color: AppColors.border,
                ),
              ),
              itemBuilder: (ctx, index) {
                final snap = snapshots[index];
                final exec = snap.execution;
                final isBuy = exec.action == TradeExecutionAction.buy;
                final actionColor = isBuy ? upColor : downColor;
                final actionText = isBuy
                    ? (snap.stepIndex == 1 ? '1차 매수' : '${snap.stepIndex}차 추가매수')
                    : (snap.remainingSharesAfter == 0 ? '전량 매도 (청산)' : '${snap.stepIndex}차 분할매도');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              actionText,
                              style: TextStyle(
                                color: actionColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy.MM.dd').format(exec.date),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$symbol${formatter.format(exec.price.round())} · ${formatter.format(exec.quantity)}주',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (snapshots.length > 1) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: AppColors.textMuted,
                              tooltip: '체결 내역 삭제',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => _confirmDeleteExecution(context, currentTrade, exec),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 체결 후 상태
                      Row(
                        children: [
                          Icon(
                            isBuy ? Icons.arrow_forward : Icons.trending_up,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isBuy
                                ? '체결 후: 총 ${formatter.format(snap.remainingSharesAfter)}주 (평단가 $symbol${formatter.format(snap.averagePriceAfter.round())})'
                                : '실현: ${snap.stepRealizedPnl! >= 0 ? '+' : ''}$symbol${formatter.format(snap.stepRealizedPnl!.round())} (${snap.stepReturnPercent! >= 0 ? '+' : ''}${snap.stepReturnPercent!.toStringAsFixed(2)}%) · 잔여 ${formatter.format(snap.remainingSharesAfter)}주',
                            style: TextStyle(
                              color: isBuy ? AppColors.textMuted : actionColor,
                              fontSize: 12,
                              fontWeight: isBuy ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (exec.memo != null && exec.memo!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exec.memo!,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            // 단일 거래인 경우
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: upColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '1차 매수 (진입)',
                          style: TextStyle(
                            color: upColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy.MM.dd').format(currentTrade.entryDate),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '$symbol${formatter.format(currentTrade.entryPrice.round())} · ${formatter.format(currentTrade.quantity)}주',
                        style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (currentTrade.isClosed && currentTrade.exitPrice != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(width: 2, height: 16, color: AppColors.border),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: downColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '전량 매도 (청산)',
                            style: TextStyle(
                              color: downColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentTrade.exitDate != null ? DateFormat('yyyy.MM.dd').format(currentTrade.exitDate!) : '',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          '$symbol${formatter.format(currentTrade.exitPrice!.round())} · ${formatter.format(currentTrade.quantity)}주',
                          style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDeleteExecution(BuildContext context, TradeEntry currentTrade, TradeExecution exec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('체결 내역 삭제'),
        content: Text('${DateFormat('yyyy.MM.dd').format(exec.date)} ${exec.action == TradeExecutionAction.buy ? '매수' : '매도'} (${exec.quantity}주) 기록을 삭제할까요? 삭제 후 평단가 및 잔여 수량이 재계산됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<TradeProvider>().deleteTradeExecution(
                tradeId: currentTrade.id,
                executionId: exec.id,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 🏷 account-tag badge shown in the overview summary card. Tap to
  /// reassign (or clear) the trade's account via [TradeProvider.
  /// updateTradeAccountTag]; falls back to a "미지정" label when unset.
  Widget _buildAccountBadge(AppLocalizations l10n) {
    final provider = context.watch<TradeProvider>();
    final accounts = provider.accounts;
    final tag = _accountTag;
    final match = tag == null
        ? null
        : accounts.where((a) => a.name == tag).firstOrNull;
    final color = match?.colorValue != null
        ? Color(match!.colorValue!)
        : AppColors.textMuted;
    final label = (tag == null || tag.isEmpty)
        ? '🏷 ${l10n.unassignedAccount}'
        : '🏷 $tag';

    return ActionChip(
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(
        label,
        style:  TextStyle(color: AppColors.text, fontSize: 12),
      ),
      side:  BorderSide(color: AppColors.border),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetCtx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final account in accounts)
                  ListTile(
                    leading: account.colorValue != null
                        ? CircleAvatar(
                            backgroundColor: Color(account.colorValue!),
                            radius: 8,
                          )
                        : const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                          ),
                    title: Text(account.name),
                    trailing: account.name == tag
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () => Navigator.of(sheetCtx).pop(account.name),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.block, size: 20),
                  title: Text(l10n.unassignedAccount),
                  onTap: () => Navigator.of(sheetCtx).pop(''),
                ),
              ],
            ),
          ),
        );
        if (selected == null || !mounted) return;
        final newTag = selected.isEmpty ? null : selected;
        // '' sentinel means "unassign".
        setState(() => _accountTag = newTag);
        await context.read<TradeProvider>().updateTradeAccountTag(
          widget.trade.id,
          newTag,
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style:  TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String content,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style:  TextStyle(
              color: AppColors.text,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, List<AnalysisNote> notes) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.edit_note, color: AppColors.accent, size: 18),
              Expanded(
                child: Text(
                  title,
                  style:  TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...notes.map(
            (note) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.content,
                    style:  TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt),
                    style:  TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab(
    BuildContext context,
    AppLocalizations l10n,
    TradeProvider provider,
    Color upColor,
    Color downColor,
  ) {
    final allNotes = provider.getNotesForTrade(widget.trade.id);
    final categories = ['thesis', 'analysis', 'mistake', 'lesson', 'action'];
    int completedSections = 0;
    for (final cat in categories) {
      if (allNotes.any((n) => n.category == cat)) completedSections++;
    }
    final progress = completedSections / categories.length;

    final journalSections = [
      _buildJournalSection(
        context: context,
        l10n: l10n,
        title: l10n.buyRationaleTitle,
        subtitle: l10n.buyRationaleSubtitle,
        prompts: [
          l10n.buyRationaleHint1,
          l10n.buyRationaleHint2,
          l10n.buyRationaleHint3,
        ],
        icon: Icons.psychology,
        color: AppColors.accent,
        sectionIndex: 1,
        category: 'thesis',
        provider: provider,
      ),
      _buildJournalSection(
        context: context,
        l10n: l10n,
        title: l10n.marketAnalysisTitle,
        subtitle: l10n.marketAnalysisSubtitle,
        prompts: [
          l10n.marketAnalysisHint1,
          l10n.marketAnalysisHint2,
          l10n.marketAnalysisHint3,
        ],
        icon: Icons.insights,
        color: AppColors.blue,
        sectionIndex: 2,
        category: 'analysis',
        provider: provider,
      ),
      _buildJournalSection(
        context: context,
        l10n: l10n,
        title: l10n.riskManagementTitle,
        subtitle: l10n.riskManagementSubtitle,
        prompts: [
          l10n.riskManagementHint1,
          l10n.riskManagementHint2,
          l10n.riskManagementHint3,
        ],
        icon: Icons.shield,
        color: AppColors.red,
        sectionIndex: 3,
        category: 'mistake',
        provider: provider,
      ),
      _buildJournalSection(
        context: context,
        l10n: l10n,
        title: l10n.keyLessonsTitle,
        subtitle: l10n.keyLessonsSubtitle,
        prompts: [
          l10n.keyLessonsHint1,
          l10n.keyLessonsHint2,
          l10n.keyLessonsHint3,
        ],
        icon: Icons.lightbulb,
        color: AppColors.orange,
        sectionIndex: 4,
        category: 'lesson',
        provider: provider,
      ),
      _buildJournalSection(
        context: context,
        l10n: l10n,
        title: l10n.nextTradePledgeTitle,
        subtitle: l10n.nextTradePledgeSubtitle,
        prompts: [
          l10n.nextTradePledgeHint1,
          l10n.nextTradePledgeHint2,
          l10n.nextTradePledgeHint3,
        ],
        icon: Icons.flag,
        color: AppColors.green,
        sectionIndex: 5,
        category: 'action',
        provider: provider,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 심플해진 상단 일지 완성도 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.auto_stories,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tradeJournal,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '매매 복기 및 5가지 분석 일지',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: progress == 1.0
                            ? AppColors.green.withValues(alpha: 0.15)
                            : AppColors.accentSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$completedSections / ${categories.length} 완료',
                        style: TextStyle(
                          color: progress == 1.0
                              ? AppColors.green
                              : AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? AppColors.green : AppColors.accent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 5개 섹션 리스트
          for (int i = 0; i < journalSections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            journalSections[i],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildJournalSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required String title,
    required String subtitle,
    required List<String> prompts,
    required IconData icon,
    required Color color,
    required int sectionIndex,
    required String category,
    required TradeProvider provider,
  }) {
    final categoryNotes = provider
        .getNotesForTrade(widget.trade.id)
        .where((n) => n.category == category)
        .toList();
    final isCompleted = categoryNotes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCompleted ? color.withValues(alpha: 0.3) : AppColors.border,
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          sectionIndex.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  TextButton.icon(
                    onPressed: () => _showAddNoteDialog(
                      context: context,
                      title: title,
                      subtitle: subtitle,
                      prompts: prompts,
                      icon: icon,
                      color: color,
                      category: category,
                      provider: provider,
                      l10n: l10n,
                    ),
                    icon: Icon(Icons.add, size: 14, color: color),
                    label: Text(
                      '추가',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 본문 영역: 작성된 노트가 있으면 카드 표시, 없으면 탭하여 모달 여는 심플 타일
            if (isCompleted) ...[
              for (int i = 0; i < categoryNotes.length; i++)
                _buildNoteItem(
                  context: context,
                  note: categoryNotes[i],
                  index: i,
                  iconColor: color,
                  provider: provider,
                ),
            ] else ...[
              InkWell(
                onTap: () => _showAddNoteDialog(
                  context: context,
                  title: title,
                  subtitle: subtitle,
                  prompts: prompts,
                  icon: icon,
                  color: color,
                  category: category,
                  provider: provider,
                  l10n: l10n,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '탭하여 $title 작성하기...',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '작성',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem({
    required BuildContext context,
    required AnalysisNote note,
    required int index,
    required Color iconColor,
    required TradeProvider provider,
  }) {
    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note.content,
                  style:  TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 14, color: AppColors.textMuted),
                onPressed: () =>
                    provider.deleteAnalysisNote(widget.trade.id, note.id),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 14,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt),
              style:  TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddNoteDialog({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<String> prompts,
    required IconData icon,
    required Color color,
    required String category,
    required TradeProvider provider,
    required AppLocalizations l10n,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _AddNoteDialog(
        title: title,
        subtitle: subtitle,
        prompts: prompts,
        icon: icon,
        color: color,
        category: category,
        tradeId: widget.trade.id,
        l10n: l10n,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(l10n.noteSavedFormat(title)),
            ],
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> prompts;
  final IconData icon;
  final Color color;
  final String category;
  final String tradeId;
  final AppLocalizations l10n;

  const _AddNoteDialog({
    required this.title,
    required this.subtitle,
    required this.prompts,
    required this.icon,
    required this.color,
    required this.category,
    required this.tradeId,
    required this.l10n,
  });

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    final provider = context.read<TradeProvider>();
    await provider.addAnalysisNote(
      widget.tradeId,
      text,
      category: widget.category,
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final canSave = text.isNotEmpty && !_isSaving;

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 가이드 힌트
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: widget.color),
                        const SizedBox(width: 4),
                        Text(
                          widget.l10n.tryThisHint,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final p in widget.prompts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $p',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 텍스트 필드
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 7,
                minLines: 4,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: widget.l10n.enterAnalysisHint,
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: widget.color, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 8),
              // 글자 수
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  widget.l10n.charCount(text.length),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 액션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      widget.l10n.cancel,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: canSave ? _handleSave : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(widget.l10n.recordButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Input-data-only visualization card for a single trade ("매매 결과 &
/// 가격 시각화 카드"). Replaces the old external-API candlestick chart:
/// everything rendered here derives from the user-entered
/// [TradeEntry] fields (entry/exit prices, quantity, dates, account
/// tag) — no network access involved.
///
/// Sections:
///  1. Price-movement gauge: fills the span between entry and exit with
///     [upColor] (profit) or [downColor] (loss). Open positions show the
///     entry price only.
///  2. Realized P/L + return-rate badge.
///  3. Invested capital (entry × qty) vs recovered amount (exit × qty).
///  4. Holding timeline with [AppLocalizations.heldForDaysFormat].
///  5. Account-tag badge (+ optional strategy/lesson memos).
class TradeVisualizerCard extends StatelessWidget {
  const TradeVisualizerCard({
    super.key,
    required this.trade,
    required this.upColor,
    required this.downColor,
    this.accountTag,
    this.accountColor,
  });

  final TradeEntry trade;

  /// Rising-color (한국형 빨강 / 서구형 초록 등) resolved by the caller
  /// from [ThemeProvider].
  final Color upColor;

  /// Falling-color resolved by the caller from [ThemeProvider].
  final Color downColor;

  /// Account tag *name* assigned to this trade (null → 미지정).
  final String? accountTag;

  /// Brand color of the account tag, resolved by the caller from
  /// [TradeProvider.accounts]; null renders a muted dot.
  final Color? accountColor;

  Color get _resultColor => trade.isClosed
      ? (trade.profitLoss >= 0 ? upColor : downColor)
      : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final market = trade.market ?? inferMarketFromSymbol(trade.stockSymbol);
    final isClosedWithExit = trade.isClosed && trade.exitPrice != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.price_change_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.priceMovement,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      isClosedWithExit
                          ? '진입가 대비 청산가 변동 및 정산'
                          : '포지션 보유 중 (청산 시 손익 확정)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _accountBadge(l10n),
            ],
          ),
          const SizedBox(height: 16),
          // 1. Entry → exit price-movement gauge (closed trades only;
          //    open positions show the entry price alone below).
          if (isClosedWithExit) ...[
            _priceGauge(trade.entryPrice, trade.exitPrice!),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _priceLabel(
                  l10n.entryPrice,
                  formatTradeMoney(trade.entryPrice, market),
                ),
                _priceLabel(
                  l10n.exitPrice,
                  formatTradeMoney(trade.exitPrice!, market),
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // 2. Realized P/L + return rate badge.
          _plBlock(l10n, market, isClosedWithExit),
          const SizedBox(height: 12),
          // 3. Invested capital vs recovered amount.
          Row(
            children: [
              Expanded(
                child: _tile(
                  l10n.investedCapital,
                  formatTradeMoney(trade.entryPrice * trade.quantity, market),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tile(
                  l10n.recoveredAmount,
                  isClosedWithExit
                      ? formatTradeMoney(
                          trade.exitPrice! * trade.quantity,
                          market,
                        )
                      : '—',
                  hint: isClosedWithExit ? null : '(청산 시 회수)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4. Holding timeline.
          _timeline(l10n),
          // Optional strategy / lesson memos entered by the user.
          if (_hasText(trade.strategy))
            _memoRow(Icons.bolt, AppColors.accent, trade.strategy!),
          if (_hasText(trade.lesson))
            _memoRow(Icons.school, AppColors.blue, trade.lesson!),
        ],
      ),
    );
  }

  static bool _hasText(String? s) => s != null && s.isNotEmpty;

  Widget _accountBadge(AppLocalizations l10n) {
    final dotColor = accountColor ?? AppColors.textMuted;
    final label = (accountTag == null || accountTag!.isEmpty)
        ? l10n.unassignedAccount
        : accountTag!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('visualizer_account_dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:  TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal track spanning [lo..hi] (with breathing room); the
  /// segment between the entry and exit marks is filled with the trade's
  /// result color.
  Widget _priceGauge(double entryPrice, double exitPrice) {
    final lo = math.min(entryPrice, exitPrice);
    final hi = math.max(entryPrice, exitPrice);
    final range = hi - lo;
    // Margin around the tracked range; degenerate (breakeven) trades
    // still need a non-zero window so the fill stays visible.
    final margin = range > 0
        ? range * 0.15
        : math.max(entryPrice.abs() * 0.05, 1.0);
    final total = (hi + margin) - (lo - margin);

    final entryPos = ((entryPrice - (lo - margin)) / total).clamp(0.0, 1.0);
    final exitPos = ((exitPrice - (lo - margin)) / total).clamp(0.0, 1.0);
    final fillStart = math.min(entryPos, exitPos);
    final fillSpan = (exitPos - entryPos).abs().clamp(0.02, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 12,
        child: Stack(
          children: [
             Positioned.fill(child: ColoredBox(color: AppColors.surface)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment(-1 + 2 * fillStart, 0),
                widthFactor: fillSpan,
                heightFactor: 1,
                child: Container(
                  key: const ValueKey('visualizer_gauge_fill'),
                  decoration: BoxDecoration(color: _resultColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceLabel(String caption, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style:  TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style:  TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _plBlock(
    AppLocalizations l10n,
    MarketType? market,
    bool isClosedWithExit,
  ) {
    if (!isClosedWithExit) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              l10n.unrealizedPLLabel,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '—',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '매도 청산 완료 시 실현 손익이 확정됩니다',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final pl = trade.profitLoss;
    final sign = pl > 0 ? '+' : (pl < 0 ? '-' : '');
    final plText = '$sign${formatTradeMoney(pl.abs(), market)}';
    final percentText =
        '$sign${trade.profitLossPercent.abs().toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _resultColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            l10n.realizedPL,
            style:  TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              plText,
              style: TextStyle(
                color: _resultColor,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _resultColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              percentText,
              style: TextStyle(
                color: _resultColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, {String? hint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:  TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              if (hint != null) ...[
                const SizedBox(width: 4),
                Text(
                  hint,
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeline(AppLocalizations l10n) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final endDate = trade.exitDate ?? DateTime.now();
    final heldDays = endDate.difference(trade.entryDate).inDays;
    final rangeText =
        '${dateFormat.format(trade.entryDate)} ~ ${trade.exitDate != null ? dateFormat.format(trade.exitDate!) : l10n.today}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
           Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rangeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentSubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              l10n.heldForDaysFormat(heldDays),
              style:  TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style:  TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
