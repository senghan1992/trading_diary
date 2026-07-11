import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/trade_provider.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';
import '../services/ad_service.dart';
import '../services/stock_api_service.dart';
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';

class AddTradeScreen extends StatefulWidget {
  const AddTradeScreen({super.key, this.initialEntryDate});

  final DateTime? initialEntryDate;

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entryPriceCtrl = TextEditingController();
  final _exitPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();

  Stock? _selectedStock;
  late DateTime _entryDate;
  late DateTime _exitDate;
  bool _isPositionOnly = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntryDate ?? DateTime.now();
    _entryDate = initial;
    _exitDate = initial;
  }

  @override
  void dispose() {
    _entryPriceCtrl.dispose();
    _exitPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _reasonCtrl.dispose();
    _strategyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor =
        isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final inputFill = isDark ? AppColors.darkSurface : AppColors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          l10n.addTrade,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: ResponsiveContainer(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDark) _HeroHeader(subColor: subColor),
                if (isDark) const SizedBox(height: AppSpacing.xl),
                _NumberedSectionHeader(
                  index: '01',
                  label: l10n.stockName,
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                _PremiumStockSelector(
                  stock: _selectedStock,
                  onTap: () => _showStockPicker(
                    context,
                    isDark,
                    bgColor,
                    textColor,
                    subColor,
                    cardColor,
                  ),
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                  cardColor: cardColor,
                ),
                const SizedBox(height: AppSpacing.xl),
                _NumberedSectionHeader(
                  index: '02',
                  label: '거래 방식',
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                _SegmentedTradeMode(
                  isPositionOnly: _isPositionOnly,
                  entryOnlyLabel: l10n.entryOnly,
                  withExitLabel: l10n.withExit,
                  onChanged: (v) => setState(() => _isPositionOnly = v),
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.xl),
                _NumberedSectionHeader(
                  index: '03',
                  label: '가격 & 수량',
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                if (context.isMediumOrUp) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PremiumInputField(
                          controller: _entryPriceCtrl,
                          label: l10n.entryPrice,
                          prefix: '${currencySymbolFor(_selectedStock?.market)} ',
                          icon: Icons.payments_outlined,
                          isDark: isDark,
                          textColor: textColor,
                          subColor: subColor,
                          fillColor: inputFill,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return l10n.error;
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return l10n.error;
                            return null;
                          },
                        ),
                      ),
                      if (!_isPositionOnly) ...[
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _PremiumInputField(
                            controller: _exitPriceCtrl,
                            label: l10n.exitPrice,
                            prefix: '${currencySymbolFor(_selectedStock?.market)} ',
                            icon: Icons.sell_outlined,
                            isDark: isDark,
                            textColor: textColor,
                            subColor: subColor,
                            fillColor: inputFill,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return l10n.error;
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return l10n.error;
                              return null;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _QuantityStepper(
                    controller: _quantityCtrl,
                    label: l10n.shares,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    fillColor: inputFill,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.error;
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return l10n.error;
                      return null;
                    },
                  ),
                ] else ...[
                  _PremiumInputField(
                    controller: _entryPriceCtrl,
                    label: l10n.entryPrice,
                    prefix: '${currencySymbolFor(_selectedStock?.market)} ',
                    icon: Icons.payments_outlined,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    fillColor: inputFill,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.error;
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return l10n.error;
                      return null;
                    },
                  ),
                  if (!_isPositionOnly) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PremiumInputField(
                      controller: _exitPriceCtrl,
                      label: l10n.exitPrice,
                      prefix: '${currencySymbolFor(_selectedStock?.market)} ',
                      icon: Icons.sell_outlined,
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                      fillColor: inputFill,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l10n.error;
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return l10n.error;
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _QuantityStepper(
                    controller: _quantityCtrl,
                    label: l10n.shares,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    fillColor: inputFill,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.error;
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return l10n.error;
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _OrderSummaryCard(
                  entryPriceCtrl: _entryPriceCtrl,
                  exitPriceCtrl: _exitPriceCtrl,
                  quantityCtrl: _quantityCtrl,
                  showPnl: !_isPositionOnly,
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                  market: _selectedStock?.market,
                ),
                const SizedBox(height: AppSpacing.xl),
                _NumberedSectionHeader(
                  index: '04',
                  label: '매매 일자',
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                _DatePickerRow(
                  entryDate: _entryDate,
                  exitDate: _exitDate,
                  showExit: !_isPositionOnly,
                  entryLabel: l10n.entryDate,
                  exitLabel: l10n.exitDate,
                  onPickEntry: (d) => setState(() => _entryDate = d),
                  onPickExit: (d) => setState(() => _exitDate = d),
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                  cardColor: cardColor,
                  l10n: l10n,
                ),
                const SizedBox(height: AppSpacing.xl),
                _NumberedSectionHeader(
                  index: '05',
                  label: '메모 & 교훈',
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                if (context.isMediumOrUp)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NotesArea(
                          controller: _reasonCtrl,
                          icon: Icons.lightbulb_outline,
                          hint: l10n.tradingIdea,
                          isDark: isDark,
                          textColor: textColor,
                          subColor: subColor,
                          cardColor: cardColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _NotesArea(
                          controller: _strategyCtrl,
                          icon: Icons.school_outlined,
                          hint: l10n.lesson,
                          isDark: isDark,
                          textColor: textColor,
                          subColor: subColor,
                          cardColor: cardColor,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _NotesArea(
                    controller: _reasonCtrl,
                    icon: Icons.lightbulb_outline,
                    hint: l10n.tradingIdea,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    cardColor: cardColor,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NotesArea(
                    controller: _strategyCtrl,
                    icon: Icons.school_outlined,
                    hint: l10n.lesson,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    cardColor: cardColor,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _PremiumCtaButton(
                  label: _isPositionOnly ? l10n.addPosition : l10n.save,
                  onPressed: _submitTrade,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStockPicker(
    BuildContext context,
    bool isDark,
    Color bgColor,
    Color textColor,
    Color subColor,
    Color cardColor,
  ) {
    // H12: previously the search TextEditingController was created in this
    // method's scope and inherited by a `StatefulBuilder`. If the user
    // dismissed via scrim (without picking a stock) the controller leaked.
    // A dedicated StatefulWidget now owns + disposes the controller.
    ResponsiveSheet.show<void>(
      context: context,
      builder: (_) => _StockPickerSheet(
        textColor: textColor,
        subColor: subColor,
        bgColor: bgColor,
        onSelected: (stock) {
          // Parent state update for the selected stock. Captured via the
          // outer `setState` (StatefulWidget State<...>_AddTradeScreenState).
          setState(() => _selectedStock = stock);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// H6: was previously `void` and called the provider's `addPosition` /
  /// `addTrade` without `await`. The Navigator.pop + success SnackBar ran
  /// BEFORE Hive had actually persisted anything, so any persistence failure
  /// was silent and the trade disappeared. We now await the save, only
  /// pop + show success on confirmed success, and surface failures via a
  /// red SnackBar so the user can retry.
  Future<void> _submitTrade() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final entryPrice = double.tryParse(_entryPriceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;

    if (entryPrice <= 0 || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
      return;
    }

    try {
      if (_isPositionOnly) {
        await context.read<TradeProvider>().addPosition(
          stockSymbol: _selectedStock!.symbol,
          stockName: _selectedStock!.nameKr ?? _selectedStock!.name,
          market: _selectedStock!.market,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: entryPrice,
          quantity: quantity,
          entryDate: _entryDate,
          reason: _reasonCtrl.text,
          strategy: _strategyCtrl.text,
        );
      } else {
        final exitPrice = double.tryParse(_exitPriceCtrl.text) ?? 0;
        if (exitPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.error)),
          );
          return;
        }
        await context.read<TradeProvider>().addTrade(
          stockSymbol: _selectedStock!.symbol,
          stockName: _selectedStock!.nameKr ?? _selectedStock!.name,
          market: _selectedStock!.market,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: entryPrice,
          exitPrice: exitPrice,
          quantity: quantity,
          entryDate: _entryDate,
          exitDate: _exitDate,
          reason: _reasonCtrl.text,
          strategy: _strategyCtrl.text,
        );
      }

      if (!mounted) return;
      // Persisted cleanly — only NOW do we leave the form and show success.
      // M2: capture the messenger BEFORE pop so the post-pop SnackBar
      // doesn't traverse a deactivated ancestor.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      AdService.instance.onEntrySaved();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.success), backgroundColor: AppColors.green),
      );
    } catch (e, st) {
      debugPrint('add_trade_screen _submitTrade failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장에 실패했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}

/// Modal stock picker shown from [_AddTradeScreenState._showStockPicker].
/// Owns its TextEditingController + in-flight search request so both are
/// disposed / cancelled cleanly even when the user dismisses the sheet via
/// scrim (the previous `StatefulBuilder` pattern leaked the controller on
/// every dismissal — H12).
///
/// Searches are routed to Finnhub's `/search` endpoint via
/// [StockApiService.searchStocksRemote], so the ticker list is never
/// hardcoded — adding the next market or removing a delisted symbol requires
/// no code change.
class _StockPickerSheet extends StatefulWidget {
  final Color textColor;
  final Color subColor;
  final Color bgColor;
  final void Function(Stock) onSelected;
  const _StockPickerSheet({
    required this.textColor,
    required this.subColor,
    required this.bgColor,
    required this.onSelected,
  });

  @override
  State<_StockPickerSheet> createState() => _StockPickerSheetState();
}

class _StockPickerSheetState extends State<_StockPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// Committed search query — only updated when the user explicitly confirms
  /// (presses the on-screen search button or the keyboard's search/enter
  /// action). Keeps the result list empty until the user has typed and
  /// confirmed something, instead of dumping a network request as soon as
  /// the sheet opens.
  String _committedQuery = '';

  /// Last fetched results for [_committedQuery]. `null` means we haven't
  /// hit the API for that query yet (initial state, or a fresh commit).
  List<Stock>? _results;

  bool _isSearching = false;

  /// User-facing error message for the most recent failed search. Cleared
  /// when a new search begins. Null means no error currently shown.
  String? _searchError;

  /// In-flight request token. Incremented on every commit; responses check
  /// the token and bail if the user has started a newer search in the
  /// meantime — prevents out-of-order writes when the API is slow.
  int _requestSeq = 0;

  /// Per-query result cache so flipping between two recent queries
  /// (e.g. "올릭스" then back to "삼성") doesn't re-hit the network.
  final Map<String, List<Stock>> _searchCache = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    // Bump the token so any pending HTTP response becomes a no-op.
    _requestSeq++;
    super.dispose();
  }

  Future<void> _commitSearch() async {
    final query = _searchCtrl.text.trim();

    // Empty commit = clear the view back to its initial prompt state.
    if (query.isEmpty) {
      setState(() {
        _committedQuery = '';
        _results = null;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    // Cache hit: render synchronously without a network round trip.
    final cached = _searchCache[query];
    if (cached != null) {
      setState(() {
        _committedQuery = query;
        _results = cached;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    final mySeq = ++_requestSeq;
    setState(() {
      _committedQuery = query;
      _isSearching = true;
      _searchError = null;
    });

    try {
      final fetched = await StockApiService.searchStocksRemote(query);
      // Drop the result if a newer search has started or the sheet was closed.
      if (!mounted || mySeq != _requestSeq) return;
      _searchCache[query] = fetched;
      setState(() {
        _isSearching = false;
        _results = fetched;
        if (fetched.isEmpty) {
          _searchError = StockApiService.getLastError();
        }
      });
    } catch (e) {
      if (!mounted || mySeq != _requestSeq) return;
      setState(() {
        _isSearching = false;
        _searchError = '검색에 실패했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetCardColor = widget.bgColor;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      // Wrap with Material so the ListTile's ink splashes can paint on a
      // proper Material ancestor. Previously the builder returned
      // `Container(color: ...)` which is a ColoredBox — the ListTile's
      // background / ripple was being painted UNDER that box and invisibly.
      builder: (_, scrollCtrl) => Material(
        color: sheetCardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.subColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                // Don't fire a network request on every keystroke — the
                // results stay empty until the user explicitly confirms
                // (Enter / search button). Keeps us well under the
                // Finnhub free-tier rate limit.
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _commitSearch(),
                textInputAction: TextInputAction.search,
                style: TextStyle(color: widget.textColor),
                decoration: InputDecoration(
                  hintText: l10n.searchPlaceholder,
                  hintStyle: TextStyle(color: widget.subColor),
                  prefixIcon: Icon(Icons.search, color: widget.subColor),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.arrow_forward_rounded,
                        color: widget.subColor),
                    onPressed: _commitSearch,
                    tooltip: l10n.search,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(l10n, scrollCtrl)),
            ],
          ),
        ),
      ),
    );
  }

  /// Body state machine:
  ///   1. Loading        → spinner
  ///   2. Error          → message + retry button
  ///   3. No query yet   → "type to search" placeholder
  ///   4. No results     → "no matches" placeholder (with the API's hint if any)
  ///   5. Results        → scrollable list
  void _selectManualStock(String query, MarketType market) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    
    final manualStock = Stock(
      symbol: cleanQuery.toUpperCase(), // 티커는 통상 대문자
      name: cleanQuery,
      nameKr: cleanQuery,
      market: market,
      currentPrice: 0,
      changePrice: 0,
      changePercent: 0,
      openPrice: 0,
      highPrice: 0,
      lowPrice: 0,
      prevClose: 0,
      volume: 0,
    );
    widget.onSelected(manualStock);
  }

  Widget _buildManualAddOptions(String query) {
    final q = query.trim();
    if (q.isEmpty) return const SizedBox();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          '찾으시는 종목이 목록에 없나요?',
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildManualChip(q, MarketType.kospi, 'KOSPI 수동 등록'),
            _buildManualChip(q, MarketType.kosdaq, 'KOSDAQ 수동 등록'),
            _buildManualChip(q, MarketType.nasdaq, 'NASDAQ 수동 등록'),
          ],
        ),
      ],
    );
  }

  Widget _buildManualChip(String query, MarketType market, String label) {
    return ActionChip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor: AppColors.purpleSubtle,
      side: BorderSide(color: AppColors.purple.withValues(alpha: 0.3)),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _selectManualStock(query, market),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ScrollController scrollCtrl) {
    if (_isSearching) {
      return Center(
        key: const ValueKey('searching'),
        child: CircularProgressIndicator(
          color: AppColors.purple,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_searchError != null) {
      // Same overflow fix as _buildEmptyPlaceholder — see the comment there.
      // Center → Padding → Column overflows in landscape-tablet dialogs when
      // the body has limited vertical space.
      return LayoutBuilder(
        key: const ValueKey('error'),
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: widget.subColor),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _searchError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: widget.subColor, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton.icon(
                      onPressed: _commitSearch,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.search),
                      style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                    ),
                    _buildManualAddOptions(_searchCtrl.text),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    final hasQuery = _committedQuery.isNotEmpty;
    if (!hasQuery) {
      return _buildEmptyPlaceholder(
        key: const ValueKey('idle'),
        icon: Icons.search_rounded,
        message: l10n.searchPlaceholder,
        subColor: widget.subColor,
      );
    }

    final results = _results ?? const <Stock>[];
    if (results.isEmpty) {
      return _buildEmptyPlaceholder(
        key: const ValueKey('empty'),
        icon: Icons.search_off_rounded,
        message: l10n.noResults,
        subColor: widget.subColor,
        extraChild: _buildManualAddOptions(_committedQuery),
      );
    }

    return ListView.builder(
      key: const ValueKey('results'),
      controller: scrollCtrl,
      itemCount: results.length + 1,
      itemBuilder: (_, i) {
        if (i == results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: _buildManualAddOptions(_committedQuery),
          );
        }
        final s = results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.purpleSubtle,
            radius: 16,
            child: Text(
              s.symbol.isEmpty ? '?' : s.symbol.substring(0, 1),
              style: const TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            s.nameKr ?? s.name,
            style: TextStyle(color: widget.textColor, fontSize: 14),
          ),
          subtitle: Text(
            '${s.symbol} · ${s.market.name.toUpperCase()}',
            style: TextStyle(fontSize: 12, color: widget.subColor),
          ),
          // Trailing price column — surfaces the quote Naver returned
          // alongside the listing so the user can confirm price level
          // before selecting. Green for up, red for down, neutral when
          // Naver gave us 0 (e.g. halted / pre-market).
          trailing: _buildPriceTrailing(s),
          onTap: () => widget.onSelected(s),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder({
    required Key key,
    required IconData icon,
    required String message,
    required Color subColor,
    Widget? extraChild,
  }) {
    // Previously a plain `Center` — overflowed in landscape-tablet dialogs
    // because the body sits inside an `Expanded` whose height is squeezed
    // (drag handle + search field eat the rest). The fixed-height Center
    // forces its child to fit, which the column cannot when the dialog
    // is short. The LayoutBuilder + ConstrainedBox pair here keeps the
    // old visual (vertically centered when the content fits) but lets the
    // SingleChildScrollView absorb any overflow instead of throwing a
    // RenderFlex overflow assertion.
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: subColor),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  extraChild ?? const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Right-side price column shown in each result tile. Renders the current
  /// quote (Naver for KOSPI/KOSDAQ, NASDAQ screener for NASDAQ) plus a
  /// colored change-% chip below. If the quote is 0 (halted stock,
  /// pre-market, Naver/NASDAQ returned nothing), we collapse to just the
  /// placeholder so the row doesn't look broken.
  ///
  /// Currency + decimal precision follow the row's market:
  ///   - KOSPI/KOSDAQ: ₩ + no decimals (`₩309,500`)
  ///   - NASDAQ:        $ + 2 decimals  (`$194.83`)
  /// Change % uses the same +X.XX%/-X.XX% format regardless of currency.
  Widget _buildPriceTrailing(Stock s) {
    if (s.currentPrice <= 0) {
      return Text(
        '—',
        style: TextStyle(
          color: widget.subColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final isKorean = s.market == MarketType.kospi ||
        s.market == MarketType.kosdaq;
    final currencySymbol = isKorean ? '₩' : r'$';
    // KRW is integer-denominated (`#309,500`); USD keeps cents (`$194.83`).
    final priceFmt = NumberFormat(isKorean ? '#,###' : '#,##0.00');
    final pctFmt = NumberFormat('+#,##0.00;-#,##0.00');

    final isUp = s.changePrice >= 0;
    final changeColor = s.changePrice == 0
        ? widget.subColor
        : (isUp ? Colors.green : Colors.red);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$currencySymbol${priceFmt.format(s.currentPrice)}',
          style: TextStyle(
            color: widget.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${pctFmt.format(s.changePercent)}%',
          style: TextStyle(
            color: changeColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SECTION WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final Color subColor;
  const _HeroHeader({required this.subColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: context.isMediumOrUp ? AppSpacing.xl : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.purpleSubtle,
                  AppColors.darkSurface.withValues(alpha: 0.6),
                ]
              : [
                  AppColors.purpleSubtle.withValues(alpha: 0.05),
                  AppColors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.purpleLight.withValues(alpha: 0.15)
              : AppColors.purpleLight.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.purpleLight, AppColors.purple],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 20,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '새로운 매매 기록',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '원칙을 지키는 투자의 시작',
                  style: TextStyle(
                    color: subColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedSectionHeader extends StatelessWidget {
  final String index;
  final String label;
  final Color subColor;
  const _NumberedSectionHeader({
    required this.index,
    required this.label,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.purpleLight : AppColors.purple;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            index,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PremiumStockSelector extends StatelessWidget {
  final Stock? stock;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _PremiumStockSelector({
    required this.stock,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final selected = stock != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.purpleLight.withValues(alpha: 0.35)
                  : (isDark
                      ? AppColors.white.withValues(alpha: 0.08)
                      : AppColors.lightBorder),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: selected
              ? Row(
                  children: [
                    _GradientAvatar(
                      text: stock!.symbol.substring(0, 1),
                      isDark: isDark,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stock!.nameKr ?? stock!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${stock!.symbol} · ${stock!.market.name.toUpperCase()}',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatTradeMoney(stock!.currentPrice, stock!.market),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (stock!.isPositive ? AppColors.green : AppColors.red)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                stock!.isPositive
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 10,
                                color: stock!.isPositive
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stock!.changePercent >= 0 ? '+' : ''}${stock!.changePercent.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: stock!.isPositive
                                      ? AppColors.green
                                      : AppColors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.chevron_right, color: subColor.withValues(alpha: 0.7), size: 18),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.purpleLight.withValues(alpha: 0.15),
                            AppColors.purple.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppColors.purpleLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '종목을 선택하세요',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '탭하여 검색 · KOSPI / KOSDAQ / NASDAQ',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: subColor.withValues(alpha: 0.7), size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String text;
  final bool isDark;
  const _GradientAvatar({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purpleLight.withValues(alpha: 0.25),
            AppColors.purple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.purpleLight,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

class _SegmentedTradeMode extends StatelessWidget {
  final bool isPositionOnly;
  final String entryOnlyLabel;
  final String withExitLabel;
  final ValueChanged<bool> onChanged;
  final Color cardColor;
  final Color textColor;
  final Color subColor;
  const _SegmentedTradeMode({
    required this.isPositionOnly,
    required this.entryOnlyLabel,
    required this.withExitLabel,
    required this.onChanged,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentItem(
              label: entryOnlyLabel,
              icon: Icons.login_rounded,
              active: isPositionOnly,
              onTap: () => onChanged(true),
              subColor: subColor,
              cardColor: cardColor,
            ),
          ),
          Expanded(
            child: _SegmentItem(
              label: withExitLabel,
              icon: Icons.swap_horizontal_circle_outlined,
              active: !isPositionOnly,
              onTap: () => onChanged(false),
              subColor: subColor,
              cardColor: cardColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color subColor;
  final Color cardColor;
  const _SegmentItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.subColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.purpleLight : AppColors.purple;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.15),
                    width: 1,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? activeColor : subColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? activeColor : subColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final IconData icon;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color fillColor;
  final FormFieldValidator<String>? validator;
  const _PremiumInputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.fillColor,
    this.prefix,
    this.validator,
  });

  @override
  State<_PremiumInputField> createState() => _PremiumInputFieldState();
}

class _PremiumInputFieldState extends State<_PremiumInputField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: widget.isDark ? 0.03 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: widget.textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: focused ? AppColors.purpleLight : widget.subColor,
            fontSize: 13,
            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: focused
                  ? AppColors.purpleLight.withValues(alpha: 0.1)
                  : widget.fillColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              color: focused ? AppColors.purpleLight : widget.subColor,
              size: 16,
            ),
          ),
          prefixText: widget.prefix,
          prefixStyle: TextStyle(
            color: widget.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: widget.fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(
              color: widget.isDark
                  ? AppColors.white.withValues(alpha: 0.15)
                  : AppColors.purple.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(
              color: widget.isDark
                  ? AppColors.white.withValues(alpha: 0.12)
                  : AppColors.purple.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.purpleLight,
              width: 1.5,
            ),
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}

class _QuantityStepper extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color fillColor;
  final FormFieldValidator<String>? validator;
  const _QuantityStepper({
    required this.controller,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.fillColor,
    this.validator,
  });

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: widget.isDark ? 0.03 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: widget.textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: focused ? AppColors.purpleLight : widget.subColor,
            fontSize: 13,
            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: focused
                  ? AppColors.purpleLight.withValues(alpha: 0.1)
                  : widget.fillColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tag_rounded,
              color: focused ? AppColors.purpleLight : widget.subColor,
              size: 16,
            ),
          ),
          filled: true,
          fillColor: widget.fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(
              color: widget.isDark
                  ? AppColors.white.withValues(alpha: 0.15)
                  : AppColors.purple.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(
              color: widget.isDark
                  ? AppColors.white.withValues(alpha: 0.12)
                  : AppColors.purple.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.purpleLight,
              width: 1.5,
            ),
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final TextEditingController entryPriceCtrl;
  final TextEditingController exitPriceCtrl;
  final TextEditingController quantityCtrl;
  final bool showPnl;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final MarketType? market;
  const _OrderSummaryCard({
    required this.entryPriceCtrl,
    required this.exitPriceCtrl,
    required this.quantityCtrl,
    required this.showPnl,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.market,
  });

  double _read(TextEditingController c) => double.tryParse(c.text) ?? 0;
  int _readInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: entryPriceCtrl,
      builder: (context, entryPrice, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: quantityCtrl,
          builder: (context, quantity, _) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: exitPriceCtrl,
              builder: (context, exitPrice, _) {
                final ep = _read(entryPriceCtrl);
                final qty = _readInt(quantityCtrl);
                final total = ep * qty;
                final hasValue = ep > 0 && qty > 0;

                final xp = _read(exitPriceCtrl);
                final pnl = showPnl ? (xp - ep) * qty : 0.0;
                final pnlPct = (showPnl && ep > 0 && qty > 0)
                    ? ((xp - ep) / ep) * 100.0
                    : 0.0;
                
                final isProfit = pnl >= 0;
                final pnlColor = isProfit ? AppColors.green : AppColors.red;
                final glowColor = isProfit 
                    ? AppColors.green.withValues(alpha: 0.08)
                    : AppColors.red.withValues(alpha: 0.08);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: showPnl && hasValue && xp > 0
                          ? pnlColor.withValues(alpha: 0.25)
                          : (isDark
                              ? AppColors.white.withValues(alpha: 0.06)
                              : AppColors.lightBorder),
                      width: showPnl && hasValue && xp > 0 ? 1.5 : 1,
                    ),
                    boxShadow: showPnl && hasValue && xp > 0
                        ? [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '총 투자금',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (hasValue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.purpleLight.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$qty주',
                                style: const TextStyle(
                                  color: AppColors.purpleLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasValue
                            ? formatTradeMoney(total, market)
                            : formatTradeMoney(0, market),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (showPnl && hasValue && xp > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          height: 1,
                          color: isDark
                              ? AppColors.white.withValues(alpha: 0.06)
                              : AppColors.lightBorder,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '예상 손익',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: pnlColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${pnl >= 0 ? '+' : ''}${formatTradeMoney(pnl, market)}',
                                    style: TextStyle(
                                      color: pnlColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      color: pnlColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final DateTime entryDate;
  final DateTime exitDate;
  final bool showExit;
  final String entryLabel;
  final String exitLabel;
  final ValueChanged<DateTime> onPickEntry;
  final ValueChanged<DateTime> onPickExit;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  final AppLocalizations l10n;
  const _DatePickerRow({
    required this.entryDate,
    required this.exitDate,
    required this.showExit,
    required this.entryLabel,
    required this.exitLabel,
    required this.onPickEntry,
    required this.onPickExit,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.l10n,
  });

  Future<void> _pick(BuildContext context, DateTime current, ValueChanged<DateTime> onPicked) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: AppColors.purpleLight,
                  onPrimary: Colors.white,
                  surface: AppColors.darkCard,
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: AppColors.purple,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppColors.lightText,
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final card = _DateCard(
      label: entryLabel,
      date: entryDate,
      onTap: () => _pick(context, entryDate, onPickEntry),
      isDark: isDark,
      textColor: textColor,
      subColor: subColor,
      cardColor: cardColor,
    );
    if (!showExit) return card;
    return Row(
      children: [
        Expanded(
          child: card,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DateCard(
            label: exitLabel,
            date: exitDate,
            onTap: () => _pick(context, exitDate, onPickExit),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
            cardColor: cardColor,
          ),
        ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _DateCard({
    required this.label,
    required this.date,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.06)
                  : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.purpleLight.withValues(alpha: 0.15),
                      AppColors.purple.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: isDark ? AppColors.purpleLight : AppColors.purple,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('M월 d일 (E)', 'ko').format(date),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: subColor.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesArea extends StatefulWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _NotesArea({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
  });

  @override
  State<_NotesArea> createState() => _NotesAreaState();
}

class _NotesAreaState extends State<_NotesArea> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final activeColor = widget.isDark ? AppColors.purpleLight : AppColors.purple;
    final unfocusedBorder = widget.isDark
        ? AppColors.white.withValues(alpha: 0.08)
        : AppColors.lightBorder;
    final borderColor = focused
        ? activeColor.withValues(alpha: 0.6)
        : unfocusedBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: focused ? 1.5 : 1),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: widget.isDark ? 0.03 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purpleSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 14,
                    color: widget.isDark ? AppColors.purpleLight : AppColors.purple,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  widget.hint,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              maxLines: 4,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 14,
                height: 1.6,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                hintText: '자유롭게 메모를 적어보세요...',
                hintStyle: TextStyle(
                  color: widget.subColor.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _PremiumCtaButton({required this.label, required this.onPressed});

  @override
  State<_PremiumCtaButton> createState() => _PremiumCtaButtonState();
}

class _PremiumCtaButtonState extends State<_PremiumCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Center(
          child: Container(
            width: context.isMediumOrUp ? 320 : double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.purple,
                  AppColors.purpleDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purpleDark.withValues(alpha: isDark ? 0.4 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
}
