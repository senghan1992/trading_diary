import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../providers/trade_provider.dart';
import '../providers/theme_provider.dart';
import '../services/stock_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import 'candlestick_chart.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';

class TradeDetailScreen extends StatefulWidget {
  final TradeEntry trade;

  const TradeDetailScreen({super.key, required this.trade});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> with SingleTickerProviderStateMixin {
  final _thesisCtrl = TextEditingController();
  final _analysisCtrl = TextEditingController();
  final _lessonCtrl = TextEditingController();
  final _mistakeCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _reminderTitleCtrl = TextEditingController();
  final _reminderNoteCtrl = TextEditingController();

  List<DailyPrice> _prices = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _thesisCtrl.addListener(_onTextChanged);
    _analysisCtrl.addListener(_onTextChanged);
    _lessonCtrl.addListener(_onTextChanged);
    _mistakeCtrl.addListener(_onTextChanged);
    _actionCtrl.addListener(_onTextChanged);
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    // Pass `widget.trade.market` so the API dispatcher routes to Naver for
    // KOSPI/KOSDAQ and Finnhub for NASDAQ, even when the user added a
    // symbol that isn't in the static mock-stock list (the previous
    // version fell back to a raw Yahoo call without the `.KS` suffix
    // and silently returned no data — which is why the chart appeared
    // empty on freshly-added entries).
    final market = widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol);
    final prices = await StockApiService.getHistoricalPrices(
      widget.trade.stockSymbol,
      market: market,
    );
    if (mounted) setState(() { _prices = prices; });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _thesisCtrl.removeListener(_onTextChanged);
    _analysisCtrl.removeListener(_onTextChanged);
    _lessonCtrl.removeListener(_onTextChanged);
    _mistakeCtrl.removeListener(_onTextChanged);
    _actionCtrl.removeListener(_onTextChanged);
    _thesisCtrl.dispose();
    _analysisCtrl.dispose();
    _lessonCtrl.dispose();
    _mistakeCtrl.dispose();
    _actionCtrl.dispose();
    _reminderTitleCtrl.dispose();
    _reminderNoteCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upColor = themeProvider.upColor;
    final downColor = themeProvider.downColor;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final borderColor = isDark ? Colors.transparent : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(widget.trade.stockName, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        actions: [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.purple,
          labelColor: AppColors.purple,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: l10n.tabOverview),
            Tab(text: l10n.tabAnalysis),
            Tab(text: l10n.reminders),
          ],
        ),
      ),
      body: ResponsiveContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(context, l10n, isDark, cardColor, textColor, subColor, borderColor, upColor, downColor),
            _buildAnalysisTab(context, l10n, provider, isDark, cardColor, textColor, subColor, borderColor, upColor, downColor),
            _buildRemindersTab(context, l10n, provider, isDark, cardColor, textColor, subColor, borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, AppLocalizations l10n, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor, Color upColor, Color downColor) {
    final formatter = NumberFormat('#,###');
    final isWin = widget.trade.profitLoss >= 0;
    final resultColor = widget.trade.isClosed ? (isWin ? upColor : downColor) : AppColors.purple;
    final notes = context.watch<TradeProvider>().getNotesForTrade(widget.trade.id);
    final thesisNotes = notes.where((n) => n.category == 'thesis').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical-stack layout for ALL form factors per the user's
          // explicit request — "기존 대로 아래로 내려서 보이도록" (show
          // the chart below as before). Summary card on top, chart
          // card below, full-width. Side-by-side was abandoned because
          // the candlestick + entry/exit price lines need the full
          // screen width to be readable on tablet too.
          _buildSummaryCard(l10n, formatter, isWin, resultColor, isDark, cardColor, textColor, subColor, borderColor),
          const SizedBox(height: 20),
          _buildChartCard(context, l10n, isDark, cardColor, textColor, subColor, borderColor, upColor: upColor, downColor: downColor),
          const SizedBox(height: 20),
          if (widget.trade.reason != null && widget.trade.reason!.isNotEmpty) ...[
            _buildInfoCard(l10n.tradeReasonLabel, widget.trade.reason!, Icons.lightbulb_outline, AppColors.orange, isDark, cardColor, textColor, subColor, borderColor),
            const SizedBox(height: 16),
          ],
          if (thesisNotes.isNotEmpty) ...[
            _buildNotesSection(l10n.tradeIdeaLabel, thesisNotes, isDark, cardColor, textColor, subColor, borderColor),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, NumberFormat formatter, bool isWin, Color resultColor, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    final statusText = widget.trade.isClosed ? l10n.tradeStatusClosed : l10n.tradeStatusOpen;
    final plText = '${widget.trade.profitLoss >= 0 ? '+' : ''}${formatter.format(widget.trade.profitLoss)}';
    final plPercentText = '${widget.trade.profitLossPercent >= 0 ? '+' : ''}${widget.trade.profitLossPercent.toStringAsFixed(2)}%';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, cardColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
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
                  Text(widget.trade.stockSymbol, style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      plText,
                      maxLines: 1,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: widget.trade.isClosed ? resultColor : textColor, height: 1.1),
                    ),
                  ),
                  if (widget.trade.isClosed) ...[
                    const SizedBox(height: 2),
                    Text(
                      plPercentText,
                      maxLines: 1,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: resultColor),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  l10n.entryPrice,
                  formatTradeMoney(widget.trade.entryPrice,
                      widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol)),
                  isDark, textColor, subColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  l10n.exitPrice,
                  widget.trade.exitPrice != null
                      ? formatTradeMoney(widget.trade.exitPrice!,
                          widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol))
                      : '—',
                  isDark, textColor, subColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildStatBox(l10n.shares, l10n.sharesWithUnit(widget.trade.quantity), isDark, textColor, subColor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatBox(l10n.entryDate, DateFormat('yyyy.MM.dd').format(widget.trade.entryDate), isDark, textColor, subColor)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatBox(l10n.exitDate, widget.trade.exitDate != null ? DateFormat('yyyy.MM.dd').format(widget.trade.exitDate!) : '—', isDark, textColor, subColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, bool isDark, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: subColor, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color borderColor, {
    double chartHeight = 320,
    required Color upColor,
    required Color downColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.candlestick_chart, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(l10n.priceChart, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Text(l10n.pinchToZoom, style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_prices.isEmpty)
            Container(
              width: double.infinity,
              height: chartHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: subColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(l10n.noChartData, style: TextStyle(color: subColor)),
                ],
              ),
            )
          else
            // IMPORTANT: width: double.infinity pins the chart container to
            // the full width of its parent Column. Without this, the chart's
            // child chain (ClipRRect → InteractiveViewer → Padding →
            // AxisChartScaffoldWidget which is LayoutBuilder+Stack →
            // CandlestickChart) collapses to 0 px wide: a CustomPaint has
            // no intrinsic size, and Stack under loose horizontal
            // constraints sizes to 0. The user reported the price-movement
            // graph was missing inside the chart section on iPad — the
            // chart container was rendering with the header and legend
            // visible, but the graph itself was 0×0. Pinning width fixes
            // that.
            Container(
              width: double.infinity,
              height: chartHeight,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: _buildInteractiveChart(
                    isDark,
                    l10n,
                    textColor,
                    subColor,
                    upColor,
                    downColor,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem(l10n.entryPrice, AppColors.purple, subColor),
              if (widget.trade.isClosed) ...[
                const SizedBox(width: 20),
                _buildLegendItem(l10n.exitPrice, downColor, subColor),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart(
    bool isDark,
    AppLocalizations l10n,
    Color textColor,
    Color subColor,
    Color upColor,
    Color downColor,
  ) {
    if (_prices.isEmpty) return const SizedBox();

    // Compute the price range from all OHLC values plus the entry/exit
    // reference lines so nothing gets clipped at the top or bottom of the
    // chart.
    final entryPrice = widget.trade.entryPrice;
    final exitPrice = widget.trade.exitPrice;

    final highsForRange = <double>[
      for (final p in _prices) p.high,
      entryPrice,
      ?exitPrice,
    ];
    final lowsForRange = <double>[
      for (final p in _prices) p.low,
      entryPrice,
      ?exitPrice,
    ];
    final priceMax = highsForRange.reduce((a, b) => a > b ? a : b);
    final priceMin = lowsForRange.reduce((a, b) => a < b ? a : b);

    // Add 5 % headroom so the highest wick and the price reference lines
    // are not flush against the chart border.
    final rawMin = priceMin - (priceMax - priceMin) * 0.05;
    final rawMax = priceMax + (priceMax - priceMin) * 0.05;
    // Guard against a flat price range producing a 0-axis chart.
    final safeMin = priceMax == priceMin ? priceMin - 1 : rawMin;
    final safeMax = priceMax == priceMin ? priceMax + 1 : rawMax;

    final spots = <CandlestickSpot>[
      for (var i = 0; i < _prices.length; i++)
        CandlestickSpot(
          x: i.toDouble(),
          date: _prices[i].date,
          open: _prices[i].open,
          high: _prices[i].high,
          low: _prices[i].low,
          close: _prices[i].close,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox.expand(
        child: CandlestickChart(
          spots: spots,
          minY: safeMin,
          maxY: safeMax,
          bullColor: upColor,
          bearColor: downColor,
          entryPrice: entryPrice,
          exitPrice: exitPrice,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color subColor) {
    return Row(
      children: [
        Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: subColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color iconColor, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                child: Text(title, style: TextStyle(color: iconColor, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, List<AnalysisNote> notes, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: AppColors.purple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...notes.map((note) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.content, style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt), style: TextStyle(color: subColor, fontSize: 11)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab(BuildContext context, AppLocalizations l10n, TradeProvider provider, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor, Color upColor, Color downColor) {
    final isWin = widget.trade.profitLoss >= 0;
    final resultColor = widget.trade.isClosed ? (isWin ? upColor : downColor) : AppColors.purple;

    final allNotes = provider.getNotesForTrade(widget.trade.id);
    final categories = ['thesis', 'analysis', 'mistake', 'lesson', 'action'];
    int completedSections = 0;
    for (final cat in categories) {
      if (allNotes.any((n) => n.category == cat)) completedSections++;
    }
    final progress = completedSections / categories.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= Breakpoints.compact;

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
              color: AppColors.purple,
              sectionIndex: 1,
              controller: _thesisCtrl,
              category: 'thesis',
              provider: provider,
              isDark: isDark, cardColor: cardColor, textColor: textColor, subColor: subColor, borderColor: borderColor,
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
              controller: _analysisCtrl,
              category: 'analysis',
              provider: provider,
              isDark: isDark, cardColor: cardColor, textColor: textColor, subColor: subColor, borderColor: borderColor,
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
              controller: _mistakeCtrl,
              category: 'mistake',
              provider: provider,
              isDark: isDark, cardColor: cardColor, textColor: textColor, subColor: subColor, borderColor: borderColor,
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
              controller: _lessonCtrl,
              category: 'lesson',
              provider: provider,
              isDark: isDark, cardColor: cardColor, textColor: textColor, subColor: subColor, borderColor: borderColor,
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
              controller: _actionCtrl,
              category: 'action',
              provider: provider,
              isDark: isDark, cardColor: cardColor, textColor: textColor, subColor: subColor, borderColor: borderColor,
            ),
          ];

          Widget journalContent;
          if (isWide) {
            final rows = <Widget>[];
            for (int i = 0; i < journalSections.length; i += 2) {
              if (i > 0) rows.add(const SizedBox(height: 16));
              if (i + 1 < journalSections.length) {
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: journalSections[i]),
                      const SizedBox(width: 16),
                      Expanded(child: journalSections[i + 1]),
                    ],
                  ),
                );
              } else {
                rows.add(journalSections[i]);
              }
            }
            journalContent = Column(children: rows);
          } else {
            journalContent = Column(
              children: [
                for (int i = 0; i < journalSections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  journalSections[i],
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cardColor, cardColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.purpleSubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_stories, color: AppColors.purple, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tradeJournal,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.trade.stockName} · ${DateFormat('yyyy.MM.dd').format(widget.trade.entryDate)}',
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (widget.trade.isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: resultColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.trade.profitLossPercent >= 0 ? '+' : ''}${widget.trade.profitLossPercent.toStringAsFixed(2)}%',
                              style: TextStyle(color: resultColor, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildJournalStat(
                          l10n.entryPrice,
                          formatTradeMoney(widget.trade.entryPrice,
                              widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol)),
                          subColor, textColor,
                        ),
                        Container(width: 1, height: 28, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _buildJournalStat(l10n.shares, l10n.sharesWithUnit(widget.trade.quantity), subColor, textColor),
                        Container(width: 1, height: 28, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _buildJournalStat(
                          widget.trade.isClosed ? l10n.realizedPL : l10n.unrealizedPLLabel,
                          '${widget.trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(widget.trade.profitLoss, widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol))}',
                          subColor, resultColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.journalCompleteness,
                              style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$completedSections / ${categories.length}',
                              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: subColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? AppColors.green : AppColors.purple,
                            ),
                          ),
                        ),
                        if (progress >= 1.0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.green, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                l10n.journalCompleteMessage,
                                style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ] else if (completedSections > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.journalRemainingMessage(categories.length - completedSections),
                            style: TextStyle(color: subColor, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              journalContent,
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJournalStat(String label, String value, Color subColor, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: subColor, fontSize: 11)),
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
    required TextEditingController controller,
    required String category,
    required TradeProvider provider,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final categoryNotes = provider.getNotesForTrade(widget.trade.id).where((n) => n.category == category).toList();
    final noteBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final subtleBg = color.withValues(alpha: 0.08);
    final isCompleted = categoryNotes.isNotEmpty;
    final hasDraft = controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? color.withValues(alpha: 0.3) : borderColor,
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : subtleBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        sectionIndex.toString().padLeft(2, '0'),
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.2)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: subColor, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted && !hasDraft) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: subtleBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates_outlined, color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          l10n.tryThisHint,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...prompts.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        p,
                        style: TextStyle(color: subColor, fontSize: 12, height: 1.4),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 3,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: l10n.enterAnalysisHint,
                    hintStyle: TextStyle(color: subColor.withValues(alpha: 0.6), fontSize: 13),
                    filled: true,
                    fillColor: noteBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: color, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasDraft || categoryNotes.isNotEmpty) ...[
                      Row(
                        children: [
                          if (hasDraft)
                            Text(
                              l10n.charCount(controller.text.trim().length),
                              style: TextStyle(color: subColor, fontSize: 11),
                            ),
                          if (hasDraft)
                            TextButton.icon(
                              onPressed: () => controller.clear(),
                              icon: Icon(Icons.close, size: 14, color: subColor),
                              label: Text(l10n.resetButton, style: TextStyle(color: subColor, fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          const Spacer(),
                          if (categoryNotes.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.noteCount(categoryNotes.length),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    ElevatedButton.icon(
                      onPressed: hasDraft ? () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        await provider.addAnalysisNote(widget.trade.id, text, category: category);
                        if (context.mounted) {
                          controller.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } : null,
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text(l10n.recordButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: color.withValues(alpha: 0.3),
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (categoryNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 1,
              color: borderColor,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.writtenNotes,
                    style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  ...categoryNotes.asMap().entries.map((entry) {
                    return _buildNoteItem(
                      context: context,
                      note: entry.value,
                      index: entry.key,
                      iconColor: color,
                      provider: provider,
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteItem({
    required BuildContext context,
    required AnalysisNote note,
    required int index,
    required Color iconColor,
    required TradeProvider provider,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
  }) {
    final noteBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: noteBg,
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
                width: 6, height: 6,
                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note.content,
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.5),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 14, color: subColor),
                onPressed: () => provider.deleteAnalysisNote(widget.trade.id, note.id),
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
              style: TextStyle(color: subColor, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersTab(BuildContext context, AppLocalizations l10n, TradeProvider provider, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    final reminders = provider.reminders.where((r) => !r.isRead).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReminderInputCard(context, l10n, provider, isDark, cardColor, textColor, subColor, borderColor),
          const SizedBox(height: 20),
          Text(l10n.setRemindersLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            _buildEmptyState(l10n.noRemindersSet, subColor, cardColor)
          else
            ...reminders.map((r) => _buildReminderCard(r, l10n, provider, isDark, cardColor, textColor, subColor, borderColor)),
        ],
      ),
    );
  }

  Widget _buildReminderInputCard(BuildContext context, AppLocalizations l10n, TradeProvider provider, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    return StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Text(l10n.newReminderHeader, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reminderTitleCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: l10n.reminderTitleHint,
                hintStyle: TextStyle(color: subColor, fontSize: 13),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reminderNoteCtrl,
              maxLines: 2,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: l10n.reminderNoteHint,
                hintStyle: TextStyle(color: subColor, fontSize: 13),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (pickerCtx, child) {
                    final parentTheme = Theme.of(pickerCtx);
                    return Theme(
                      data: parentTheme.copyWith(
                        colorScheme: parentTheme.brightness == Brightness.dark
                          ? ColorScheme.dark(
                              primary: AppColors.purple,
                              onPrimary: Colors.white,
                              surface: AppColors.darkCard,
                              onSurface: AppColors.white,
                            )
                          : ColorScheme.light(
                              primary: AppColors.purple,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppColors.lightText,
                            ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: parentTheme.brightness == Brightness.dark
                            ? AppColors.darkCard
                            : Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      selectedDate.hour,
                      selectedDate.minute,
                    );
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.orange, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: subColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(selectedDate),
                  builder: (pickerCtx, child) {
                    final parentTheme = Theme.of(pickerCtx);
                    return Theme(
                      data: parentTheme.copyWith(
                        colorScheme: parentTheme.brightness == Brightness.dark
                          ? ColorScheme.dark(
                              primary: AppColors.purple,
                              onPrimary: Colors.white,
                              surface: AppColors.darkCard,
                              onSurface: AppColors.white,
                            )
                          : ColorScheme.light(
                              primary: AppColors.purple,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppColors.lightText,
                            ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: parentTheme.brightness == Brightness.dark
                            ? AppColors.darkCard
                            : Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      picked.hour,
                      picked.minute,
                    );
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.orange, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('HH:mm').format(selectedDate), style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: subColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_reminderTitleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.enterReminderTitle), backgroundColor: AppColors.red),
                    );
                    return;
                  }
                  provider.addReminder(
                    _reminderTitleCtrl.text.trim(),
                    _reminderNoteCtrl.text.trim(),
                    selectedDate,
                    tradeId: widget.trade.id, // H8: link reminder to this trade so deleteTrade cascades it.
                  );
                  _reminderTitleCtrl.clear();
                  _reminderNoteCtrl.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.reminderSetFormat(DateFormat('M월 d일 HH:mm').format(selectedDate))),
                        ],
                      ),
                      backgroundColor: AppColors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.add_alarm, size: 18),
                label: Text(l10n.setReminder),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, AppLocalizations l10n, TradeProvider provider, bool isDark, Color cardColor, Color textColor, Color subColor, Color borderColor) {
    final isPast = reminder.remindAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPast ? AppColors.red.withValues(alpha: 0.3) : borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isPast ? AppColors.red.withValues(alpha: 0.15) : AppColors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isPast ? Icons.warning_amber : Icons.notifications_active, color: isPast ? AppColors.red : AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                if (reminder.note != null && reminder.note!.isNotEmpty)
                  Text(reminder.note!, style: TextStyle(color: subColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: isPast ? AppColors.red : subColor),
                    const SizedBox(width: 4),
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(reminder.remindAt), style: TextStyle(color: isPast ? AppColors.red : subColor, fontSize: 11)),
                    if (isPast) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(l10n.reminderOverdue, style: const TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPast)
                IconButton(
                  // M9: only show snooze for overdue reminders; the user's
                  // intent is "I missed this, push it later". The picker
                  // surfaces the four durations most relevant for the
                  // long-term-investor use case (the app's primary audience):
                  // 1 day, 1 week, 1 month, 3 months.
                  icon: Icon(Icons.snooze, color: AppColors.orange),
                  tooltip: l10n.snoozePickerTitle,
                  onPressed: () async {
                    final picked = await _showSnoozePicker(
                      context: context,
                      reminder: reminder,
                      provider: provider,
                      l10n: l10n,
                      textColor: textColor,
                      subColor: subColor,
                      cardColor: cardColor,
                    );
                    if (picked == null || !mounted) return;
                    final newTime = reminder.remindAt.add(picked);
                    final messenger = ScaffoldMessenger.of(context);
                    await provider.snoozeReminder(reminder.id, picked);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.reminderSetFormat(
                            DateFormat('M월 d일').format(newTime),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: Icon(Icons.check_circle_outline, color: AppColors.green),
                tooltip: 'mark as read',
                onPressed: () => provider.markReminderRead(reminder.id),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.red),
                tooltip: l10n.deleteReminder,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteReminder),
                      content: Text(l10n.deleteReminderConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.red),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await provider.deleteReminder(reminder.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Modal sheet that lets the user pick how far to push an overdue
  /// reminder. Long-term investors use this more than day-traders — the
  /// +1 day / +1 week / +1 month / +3 months cadence matches their review
  /// rhythm (next earnings, monthly portfolio review, quarterly checkup).
  ///
  /// Returns the chosen [Duration], or null if dismissed.
  static Future<Duration?> _showSnoozePicker({
    required BuildContext context,
    required Reminder reminder,
    required TradeProvider provider,
    required AppLocalizations l10n,
    required Color textColor,
    required Color subColor,
    required Color cardColor,
  }) async {
    final options = <(String, Duration)>[
      (l10n.snoozeOneDay, const Duration(days: 1)),
      (l10n.snoozeOneWeek, const Duration(days: 7)),
      (l10n.snoozeOneMonth, const Duration(days: 30)),
      (l10n.snoozeThreeMonths, const Duration(days: 90)),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.purple;

    return showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.snooze, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.snoozePickerTitle,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final o in options)
              ListTile(
                leading: Icon(Icons.schedule, color: accent),
                title: Text(
                  o.$1,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(o.$2),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildEmptyState(String message, Color subColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: subColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: subColor, fontSize: 14)),
        ],
      ),
    );
  }
}
