import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account_tag.dart';
import '../l10n/app_localizations.dart';
import '../services/trade_analytics_calculator.dart' show kUnassignedAccount;
import '../providers/trade_provider.dart';
import '../providers/theme_provider.dart';
import '../models/trade_entry.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../services/excel_export_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/trade_action_sheet.dart';
import '../widgets/trade_detail_screen.dart';
import 'add_trade_screen.dart';

/// M6: timestamp of the last FAB tap, used to debounce rapid double-pushes.
/// Static so the value survives a parent rebuild. One JournalScreen
/// instance exists in the app, so the static is safe.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  static DateTime? _lastFabTap;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

/// Sheet-style ordering for the journal list.
enum _SortMode { newest, profit, loss }

class _JournalScreenState extends State<JournalScreen> {
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.newest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text(
            l10n.journal,
            style:  TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l10n.exportToExcel,
              icon: const Icon(Icons.table_view_rounded),
              color: AppColors.text,
              onPressed: () => ExcelExportService.showExportDialog(
                context,
                _applySearchSort(provider.closedPositions),
              ),
            ),
          ],
        ),

        body: ResponsiveContainer(
          child: Column(
            children: [
              _buildAccountFilterBar(context, provider),
              _buildSearchSortBar(context, provider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TabBar(
                  indicatorColor: AppColors.accent,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(text: '${l10n.openPosition} (${provider.openPositions.length})'),
                    Tab(text: '${l10n.closedPosition} (${provider.closedPositions.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOpenPositions(context, provider),
                    _buildClosedTrades(context, provider),
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
            if (JournalScreen._lastFabTap != null &&
                now.difference(JournalScreen._lastFabTap!) <
                    const Duration(milliseconds: 600)) {
              return;
            }
            JournalScreen._lastFabTap = now;
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddTradeScreen()));
          },
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add),
          label: Text(l10n.addTrade),
        ),
      ),
    );
  }

  /// Excel-sheet style search + sort row: a compact text field filtering
  /// by stock name / symbol / memo, plus a sort selector (newest, best
  /// return, worst return).
  Widget _buildSearchSortBar(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.searchTrades,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<_SortMode>(
            tooltip: l10n.sortBy,
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortMode.newest,
                child: Text(l10n.newestFirst),
              ),
              PopupMenuItem(
                value: _SortMode.profit,
                child: Text(l10n.sortByProfit),
              ),
              PopupMenuItem(value: _SortMode.loss, child: Text(l10n.sortByLoss)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    switch (_sortMode) {
                      _SortMode.newest => l10n.newestFirst,
                      _SortMode.profit => l10n.sortByProfit,
                      _SortMode.loss => l10n.sortByLoss,
                    },
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
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

  /// Applies the search query and sort mode to a trade list.
  List<TradeEntry> _applySearchSort(List<TradeEntry> trades) {
    final query = _searchQuery.trim().toLowerCase();
    var result = trades;
    if (query.isNotEmpty) {
      result = result.where((t) {
        return t.stockName.toLowerCase().contains(query) ||
            t.stockSymbol.toLowerCase().contains(query) ||
            (t.reason ?? '').toLowerCase().contains(query) ||
            (t.strategy ?? '').toLowerCase().contains(query) ||
            (t.accountTag ?? '').toLowerCase().contains(query);
      }).toList();
    }
    switch (_sortMode) {
      case _SortMode.newest:
        result.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      case _SortMode.profit:
        result.sort((a, b) => b.profitLossPercent.compareTo(
              a.profitLossPercent,
            ));
      case _SortMode.loss:
        result.sort((a, b) => a.profitLossPercent.compareTo(
              b.profitLossPercent,
            ));
    }
    return result;
  }

  Widget _buildOpenPositions(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final positions = _applySearchSort(provider.openPositions);

    if (positions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: l10n.noTradesYet,
        subtitle: l10n.emptyOpenPositions,
      );
    }

    return _buildCardList(
      context,
      positions,
      (ctx, trade) => _buildPositionCard(ctx, trade, provider),
    );
  }

  Widget _buildClosedTrades(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final trades = _applySearchSort(provider.closedPositions);

    if (trades.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book_outlined,
        title: l10n.noTradesYet,
        subtitle: l10n.emptyClosedTrades,
      );
    }

    return _buildCardList(
      context,
      trades,
      (ctx, trade) => _buildTradeCard(ctx, trade, provider),
    );
  }

  Widget _buildCardList(
    BuildContext context,
    List<TradeEntry> trades,
    Widget Function(BuildContext, TradeEntry) itemBuilder,
  ) {
    if (context.isMediumOrUp) {
      // Tablet grid. Trade cards stack a header row + close button/info
      // chips + an optional one-line reason preview, so we use a generous
      // fixed `mainAxisExtent` instead of `childAspectRatio` (the old
      // aspect-ratio cells overflowed in iPad landscape).
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 232,
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // Same overflow guard as the old stock-picker placeholder:
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
                    decoration:  BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    style:  TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style:  TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Premium white card shell shared by position & closed-trade cards.
  Widget _cardShell({
    required BuildContext context,
    required TradeEntry trade,
    required TradeProvider provider,
    required Widget child,
  }) {
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
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TradeDetailScreen(trade: trade),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// One-line reason preview shared by both card types.
  Widget _reasonPreview(String? reason) {
    final trimmed = reason?.trim() ?? '';
    if (trimmed.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
           Icon(
            Icons.sticky_note_2_outlined,
            size: 12,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              trimmed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(
    BuildContext context,
    TradeEntry trade,
    TradeProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###');

    return _cardShell(
      context: context,
      trade: trade,
      provider: provider,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  trade.direction == TradeDirection.buy
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: AppColors.accent,
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
                      style:  TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildMiniTag(l10n.openPosition, AppColors.accent),
                    _buildAccountBadge(trade, context),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatTradeMoney(
                        trade.entryPrice * trade.quantity,
                        trade.market ??
                            inferMarketFromSymbol(trade.stockSymbol),
                      ),
                      maxLines: 1,
                      style:  TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${trade.quantity}${l10n.sharesUnit} @ ${formatter.format(trade.entryPrice)}',
                      maxLines: 1,
                      style:  TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _reasonPreview(trade.reason),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showClosePositionDialog(context, trade, provider),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: Text(l10n.closePosition),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: BorderSide(
                  color: AppColors.green.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(
    BuildContext context,
    TradeEntry trade,
    TradeProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isWin = trade.result == TradeResult.success;
    final themeProvider = context.watch<ThemeProvider>();
    final pnlColor = isWin ? themeProvider.upColor : themeProvider.downColor;

    return _cardShell(
      context: context,
      trade: trade,
      provider: provider,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pnlColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  isWin
                      ? Icons.emoji_events_outlined
                      : Icons.trending_down_rounded,
                  color: pnlColor,
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
                      style:  TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildMiniTag(isWin ? 'WIN' : 'LOSS', pnlColor),
                    _buildAccountBadge(trade, context),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(trade.profitLoss, trade.market ?? inferMarketFromSymbol(trade.stockSymbol))}',
                      maxLines: 1,
                      style: TextStyle(
                        color: pnlColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                      maxLines: 1,
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
                child: _buildInfoChip(
                  l10n.entryPrice,
                  formatTradeMoney(
                    trade.entryPrice,
                    trade.market ?? inferMarketFromSymbol(trade.stockSymbol),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildInfoChip(
                  l10n.exitPrice,
                  trade.exitPrice != null
                      ? formatTradeMoney(
                          trade.exitPrice!,
                          trade.market ??
                              inferMarketFromSymbol(trade.stockSymbol),
                        )
                      : '—',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildInfoChip(
                  l10n.shares,
                  '${trade.quantity}${l10n.sharesUnit}',
                ),
              ),
            ],
          ),
          _reasonPreview(trade.reason),
        ],
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

  /// Horizontal account filter bar. Default selection is `null` =
  /// "전체 계좌" (all accounts combined). Each chip carries the account's
  /// brand color dot and the number of matching trades; untagged history
  /// gets its own [unassignedAccount] chip; the trailing gear chip opens
  /// [AccountManagementScreen].
  Widget _buildAccountFilterBar(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    // Counts must be computed on the type-filtered list (NOT
    // filteredTrades) so tapping a chip doesn't change the numbers.
    Iterable<TradeEntry> base = provider.trades;
    switch (provider.filter) {
      case TradeFilter.real:
        base = base.where((t) => t.type == TradeType.real);
      case TradeFilter.virtual:
        base = base.where((t) => t.type == TradeType.virtual);
      case TradeFilter.all:
        break;
    }
    final all = base.toList();
    final selected = provider.selectedAccountTagFilter;

    Widget chip({
      required String? tag,
      required int count,
      String? label,
      Color? dotColor,
    }) {
      final isSelected = selected == tag;
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
              Text('$label ($count)'),
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.text : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          selectedColor: isSelected ? AppColors.accentSubtle : AppColors.card,
          side: BorderSide(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => provider.setSelectedAccountTagFilter(tag),
        ),
      );
    }

    final accounts = provider.accounts;
    int countFor(String? tag) => all.where((t) {
      final tTag = (t.accountTag == null || t.accountTag!.isEmpty)
          ? null
          : t.accountTag;
      return tag == null ? true : tTag == tag;
    }).length;
    final unassignedCount = all
        .where((t) => t.accountTag == null || t.accountTag!.isEmpty)
        .length;

    if (accounts.isEmpty && unassignedCount == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        physics: const BouncingScrollPhysics(),
        children: [
          chip(tag: null, count: all.length, label: l10n.allAccounts),
          for (final AccountTag account in accounts)
            chip(
              tag: account.name,
              count: countFor(account.name),
              label: account.name,
              dotColor: account.colorValue != null
                  ? Color(account.colorValue!)
                  : AppColors.textMuted,
            ),
          if (unassignedCount > 0)
            chip(
              tag: kUnassignedAccount,
              count: unassignedCount,
              label: l10n.unassignedAccount,
              dotColor: AppColors.textMuted,
            ),
        ],
      ),
    );
  }

  /// Account badge rendered on every trade card: colored dot + account
  /// name when the tag matches a registered account, muted gray with the
  /// [unassignedAccount] label otherwise (orphaned names stay visible).
  Widget _buildAccountBadge(TradeEntry trade, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tag = trade.accountTag;
    final accounts = context.read<TradeProvider>().accounts;
    final match = (tag == null || tag.isEmpty)
        ? null
        : accounts.where((a) => a.name == tag).firstOrNull;
    final color = match?.colorValue != null ? Color(match!.colorValue!) : null;
    final label =
        match?.name ??
        ((tag == null || tag.isEmpty) ? l10n.unassignedAccount : tag);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color ?? AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              style:  TextStyle(
                color: AppColors.text,
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
              style:  TextStyle(
                color: AppColors.textMuted,
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

  void _showClosePositionDialog(
    BuildContext context,
    TradeEntry trade,
    TradeProvider provider,
  ) {
    TradeActionSheet.show(context, trade: trade);
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
                child:  Icon(Icons.flag, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.closePosition,
                      style:  TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.trade.stockName,
                      style:  TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _exitPriceCtrl,
            keyboardType: TextInputType.number,
            style:  TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              labelText: l10n.exitPrice,
              labelStyle:  TextStyle(color: AppColors.textMuted),
              prefixText:
                  '${currencySymbolFor(widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol))} ',
              prefixStyle:  TextStyle(color: AppColors.text),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
                    colorScheme: ColorScheme.light(primary: AppColors.accent),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _exitDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.exitDate,
                    style:  TextStyle(color: AppColors.textMuted),
                  ),
                  Row(
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(_exitDate),
                        style:  TextStyle(color: AppColors.text),
                      ),
                      const SizedBox(width: 8),
                       Icon(
                        Icons.calendar_today,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
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
                    side:  BorderSide(color: AppColors.border),
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
                    final exitPrice = double.tryParse(
                      _exitPriceCtrl.text.trim(),
                    );
                    if (exitPrice == null || exitPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
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
                         SnackBar(
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
