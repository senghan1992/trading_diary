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
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/stock_autocomplete_field.dart';
import 'account_management_screen.dart';

class AddTradeScreen extends StatefulWidget {
  const AddTradeScreen({super.key, this.initialEntryDate});

  final DateTime? initialEntryDate;

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  static const _sectionTradeMode = '거래 방식';
  static const _sectionPriceQty = '가격 및 수량';
  static const _sectionDates = '매매 일자';
  static const _sectionSplitTrades = '분할 매매 체결 내역 (선택)';
  static const _sectionNotes = '전략 및 복기';

  final _formKey = GlobalKey<FormState>();
  final _stockNameCtrl = TextEditingController();
  final _entryPriceCtrl = TextEditingController();
  final _exitPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();

  late DateTime _entryDate;
  late DateTime _exitDate;
  bool _isPositionOnly = true;

  /// 추가 매수 및 분할 매도 체결 목록
  final List<TradeExecution> _additionalExecutions = [];

  /// 선택된 마켓. 국내(KOSPI/KOSDAQ) / 미국(NASDAQ) / 기타·가상자산(null).
  /// 저장 시 [inferMarketFromSymbol] 패턴(.KQ 등 코스닥 표기)을 참고해
  /// kosdaq으로 재추론할 수 있다.
  MarketType? _selectedMarket = MarketType.kospi;

  /// 자동완성으로 선택된 종목 코드 (예: 005930, AAPL). null일 경우 종목명을 심볼로 사용.
  String? _selectedStockCode;

  /// 선택된 계좌 태그 이름. null = 미지정.
  String? _selectedAccountTag;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntryDate ?? DateTime.now();
    _entryDate = initial;
    _exitDate = initial;
    // 최근 사용한 계좌 태그를 기본 선택값으로 자동 지정.
    final provider = context.read<TradeProvider>();
    final trades = provider.trades;
    if (trades.isNotEmpty) {
      final lastTag = trades.last.accountTag;
      if (lastTag != null && provider.accounts.any((a) => a.name == lastTag)) {
        _selectedAccountTag = lastTag;
      }
    }
  }

  @override
  void dispose() {
    _stockNameCtrl.dispose();
    _entryPriceCtrl.dispose();
    _exitPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _reasonCtrl.dispose();
    _strategyCtrl.dispose();
    super.dispose();
  }

  /// 최근 입력한 종목명 (중복 제거, 최근순, 최대 8개).
  List<String> _recentStockNames(List<TradeEntry> trades) {
    final sorted = [...trades]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    final seen = <String>{};
    final names = <String>[];
    for (final t in sorted) {
      final name = t.stockName.trim();
      if (name.isEmpty) continue;
      if (seen.add(name)) names.add(name);
      if (names.length >= 8) break;
    }
    return names;
  }

  /// 칩에서 고른 마켓 + 사용자가 입력한 심볼(=종목명)을 조합해 최종 마켓 결정.
  /// 국내 선택 시 .KQ 등 코스닥 패턴이면 kosdaq으로 추론한다.
  MarketType? _resolveMarket(String symbol) {
    switch (_selectedMarket) {
      case MarketType.kosdaq:
        return MarketType.kosdaq;
      case MarketType.nasdaq:
        return MarketType.nasdaq;
      case MarketType.kospi:
        final upper = symbol.toUpperCase();
        if (upper.endsWith('.KQ') || upper.endsWith('.KOSDAQ')) {
          return MarketType.kosdaq;
        }
        return MarketType.kospi;
      case null:
        // 기타/가상자산 — 마켓 미지정으로 저장(표시 시 폴백 추론).
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgColor = AppColors.bg;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final cardColor = AppColors.card;
    final inputFill = AppColors.surface;
    final recentStocks = _recentStockNames(
      context.watch<TradeProvider>().trades,
    );

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
                // ── 01. 거래 계좌 선택 ──
                _NumberedSectionHeader(
                  index: '01',
                  label: l10n.selectAccountTag,
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildAccountSelector(),
                const SizedBox(height: AppSpacing.xl),

                // ── 02. 종목 정보 ──
                _NumberedSectionHeader(
                  index: '02',
                  label: l10n.stockName,
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                StockAutocompleteField(
                  controller: _stockNameCtrl,
                  labelText: l10n.stockName,
                  currentMarket: _selectedMarket,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.error : null,
                  onSelected: (stock) {
                    setState(() {
                      _selectedStockCode = stock.code;
                      _selectedMarket = stock.market;
                    });
                  },
                ),
                if (recentStocks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.recentStocks,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final name in recentStocks)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ActionChip(
                                label: Text(name),
                                labelStyle: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: cardColor,
                                side: BorderSide(color: AppColors.border),
                                onPressed: () =>
                                    setState(() => _stockNameCtrl.text = name),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.marketDomestic),
                      selected:
                          _selectedMarket == MarketType.kospi ||
                          _selectedMarket == MarketType.kosdaq,
                      selectedColor: AppColors.accentSubtle,
                      checkmarkColor: AppColors.accent,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color:
                            (_selectedMarket == MarketType.kospi ||
                                _selectedMarket == MarketType.kosdaq)
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedMarket = MarketType.kospi),
                    ),
                    ChoiceChip(
                      label: Text(l10n.marketUS),
                      selected: _selectedMarket == MarketType.nasdaq,
                      selectedColor: AppColors.accentSubtle,
                      checkmarkColor: AppColors.accent,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: _selectedMarket == MarketType.nasdaq
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedMarket = MarketType.nasdaq),
                    ),
                    ChoiceChip(
                      label: Text(l10n.marketEtc),
                      selected: _selectedMarket == null,
                      selectedColor: AppColors.accentSubtle,
                      checkmarkColor: AppColors.accent,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: _selectedMarket == null
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                      onSelected: (_) => setState(() => _selectedMarket = null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── 03. 거래 방식 ──
                _NumberedSectionHeader(
                  index: '03',
                  label: _sectionTradeMode,
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

                // ── 04. 가격 및 수량 ──
                _NumberedSectionHeader(
                  index: '04',
                  label: _sectionPriceQty,
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
                          prefix: '${currencySymbolFor(_selectedMarket)} ',
                          icon: Icons.payments_outlined,
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
                            prefix: '${currencySymbolFor(_selectedMarket)} ',
                            icon: Icons.sell_outlined,
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
                    prefix: '${currencySymbolFor(_selectedMarket)} ',
                    icon: Icons.payments_outlined,
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
                      prefix: '${currencySymbolFor(_selectedMarket)} ',
                      icon: Icons.sell_outlined,
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
                  textColor: textColor,
                  subColor: subColor,
                  market: _selectedMarket,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── 05. 일자 ──
                _NumberedSectionHeader(
                  index: '05',
                  label: _sectionDates,
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
                  textColor: textColor,
                  subColor: subColor,
                  cardColor: cardColor,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── 06. 분할 매매 체결 내역 ──
                _NumberedSectionHeader(
                  index: '06',
                  label: _sectionSplitTrades,
                  subColor: subColor,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSplitTradesSection(textColor, subColor, cardColor, inputFill),
                const SizedBox(height: AppSpacing.xl),

                // ── 07. 전략 및 복기 ──
                _NumberedSectionHeader(
                  index: '07',
                  label: _sectionNotes,
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
                    textColor: textColor,
                    subColor: subColor,
                    cardColor: cardColor,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NotesArea(
                    controller: _strategyCtrl,
                    icon: Icons.school_outlined,
                    hint: l10n.lesson,
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

  /// Horizontal scrollable row of account-tag chips plus an "add account"
  /// action chip. Selecting a chip tags the trade being created; the
  /// "미지정" chip stores `accountTag: null`.
  Widget _buildAccountSelector() {
    final l10n = AppLocalizations.of(context)!;
    final accounts = context.watch<TradeProvider>().accounts;

    final chips = <Widget>[
      for (final account in accounts)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (account.colorValue != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(account.colorValue!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(account.name),
              ],
            ),
            selected: _selectedAccountTag == account.name,
            selectedColor: account.colorValue != null
                ? Color(account.colorValue!).withValues(alpha: 0.25)
                : AppColors.accentSubtle,
            checkmarkColor: AppColors.text,
            side: BorderSide(
              color: _selectedAccountTag == account.name
                  ? (account.colorValue != null
                        ? Color(account.colorValue!)
                        : AppColors.accent)
                  : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: AppColors.text,
              fontWeight: _selectedAccountTag == account.name
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
            showCheckmark: false,
            onSelected: (_) =>
                setState(() => _selectedAccountTag = account.name),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(l10n.unassignedAccount),
          selected: _selectedAccountTag == null,
          selectedColor: AppColors.accentSubtle,
          checkmarkColor: AppColors.text,
          side: BorderSide(
            color: _selectedAccountTag == null
                ? AppColors.accent
                : AppColors.border,
          ),
          labelStyle: TextStyle(
            color: AppColors.textMuted,
            fontWeight: _selectedAccountTag == null
                ? FontWeight.w800
                : FontWeight.w600,
          ),
          showCheckmark: false,
          onSelected: (_) => setState(() => _selectedAccountTag = null),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ActionChip(
          avatar: Icon(Icons.add, size: 18, color: AppColors.accent),
          label: Text(
            l10n.addAccount,
            style: TextStyle(color: AppColors.accent),
          ),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
          onPressed: () => _openAccountManagement(),
        ),
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: chips),
      ),
    );
  }

  /// 계좌 관리 화면으로 이동. 돌아오면 계좌 목록 변경(삭제 등)을 반영해
  /// 선택값을 검증한다. Provider를 watch하므로 목록 갱신은 자동 반영된다.
  Future<void> _openAccountManagement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountManagementScreen()));
    if (!mounted) return;
    final accounts = context.read<TradeProvider>().accounts;
    final tag = _selectedAccountTag;
    if (tag != null && !accounts.any((a) => a.name == tag)) {
      setState(() => _selectedAccountTag = null);
    }
  }

  Widget _buildSplitTradesSection(
    Color textColor,
    Color subColor,
    Color cardColor,
    Color inputFill,
  ) {
    final entryPrice = double.tryParse(_entryPriceCtrl.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final symbol = currencySymbolFor(_selectedMarket);
    final formatter = NumberFormat('#,###');

    final allExecutions = <TradeExecution>[];
    if (entryPrice > 0 && quantity > 0) {
      allExecutions.add(TradeExecution(
        id: 'initial',
        action: TradeExecutionAction.buy,
        price: entryPrice,
        quantity: quantity,
        date: _entryDate,
        memo: '1차 매수',
      ));
    }
    allExecutions.addAll(_additionalExecutions);

    final hasExecutions = _additionalExecutions.isNotEmpty;

    TradeCalculatedState? calc;
    if (allExecutions.isNotEmpty) {
      calc = TradeEntry.calculateExecutions(
        executions: allExecutions,
        direction: TradeDirection.buy,
        fallbackEntryDate: _entryDate,
        fallbackEntryPrice: entryPrice,
        fallbackQuantity: quantity,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                '분할 매수 / 분할 매도 내역',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (hasExecutions)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '총 ${allExecutions.length}회 체결',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (!hasExecutions) ...[
            Text(
              '여러 번 나누어 추가 매수하거나 분할 매도한 경우 체결 내역을 추가해 보세요. 평균 단가와 실현 손익이 자동으로 계산됩니다.',
              style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddExecutionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('분할 매매 체결 기록 추가'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else ...[
            if (calc != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('최종 평단가', style: TextStyle(color: subColor, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '$symbol${formatter.format(calc.averageEntryPrice.round())}',
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('잔여 / 총수량', style: TextStyle(color: subColor, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '${formatter.format(calc.remainingQuantity)} / ${formatter.format(calc.totalBuyQuantity)}주',
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    if (calc.totalSellQuantity > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('실현 손익', style: TextStyle(color: subColor, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${calc.realizedProfitLoss >= 0 ? '+' : ''}$symbol${formatter.format(calc.realizedProfitLoss.round())}',
                              style: TextStyle(
                                color: calc.realizedProfitLoss >= 0 ? AppColors.green : AppColors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _additionalExecutions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exec = _additionalExecutions[index];
                final isBuy = exec.action == TradeExecutionAction.buy;
                final badgeColor = isBuy ? AppColors.green : AppColors.red;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isBuy ? '추가매수' : '분할매도',
                          style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy.MM.dd').format(exec.date),
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '$symbol${formatter.format(exec.price.round())} · ${formatter.format(exec.quantity)}주',
                        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: subColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          setState(() {
                            _additionalExecutions.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddExecutionDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('체결 내역 추가'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddExecutionDialog() {
    TradeExecutionAction selectedAction = TradeExecutionAction.buy;
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final symbol = currencySymbolFor(_selectedMarket);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('체결 내역 추가', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('추가 매수')),
                          selected: selectedAction == TradeExecutionAction.buy,
                          selectedColor: AppColors.green.withValues(alpha: 0.2),
                          onSelected: (_) => setDialogState(() => selectedAction = TradeExecutionAction.buy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('분할 매도')),
                          selected: selectedAction == TradeExecutionAction.sell,
                          selectedColor: AppColors.red.withValues(alpha: 0.2),
                          onSelected: (_) => setDialogState(() => selectedAction = TradeExecutionAction.sell),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: selectedAction == TradeExecutionAction.buy ? '매수가' : '매도가',
                      prefixText: '$symbol ',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '수량',
                      suffixText: '주',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: _entryDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy.MM.dd').format(date)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoCtrl,
                    decoration: InputDecoration(
                      labelText: '메모 (선택)',
                      hintText: selectedAction == TradeExecutionAction.buy ? null : '예: 1차 분할 익절',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceCtrl.text.trim());
                  final qty = int.tryParse(qtyCtrl.text.trim());
                  if (price == null || price <= 0 || qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('올바른 가격과 수량을 입력해주세요.')),
                    );
                    return;
                  }
                  setState(() {
                    _additionalExecutions.add(
                      TradeExecution(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        action: selectedAction,
                        price: price,
                        quantity: qty,
                        date: date,
                        memo: memoCtrl.text.trim().isNotEmpty ? memoCtrl.text.trim() : null,
                      ),
                    );
                  });
                  Navigator.of(ctx).pop();
                },
                child: const Text('추가'),
              ),
            ],
          );
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
    if (!_formKey.currentState!.validate()) return;

    final stockName = _stockNameCtrl.text.trim();
    if (stockName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.error)));
      return;
    }
    final symbol = (_selectedStockCode != null && _selectedStockCode!.isNotEmpty)
        ? _selectedStockCode!
        : stockName;

    final entryPrice = double.tryParse(_entryPriceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;

    if (entryPrice <= 0 || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.error)));
      return;
    }

    final market = _resolveMarket(symbol);

    try {
      if (_additionalExecutions.isNotEmpty) {
        final firstExec = TradeExecution(
          id: 'initial_${DateTime.now().microsecondsSinceEpoch}',
          action: TradeExecutionAction.buy,
          price: entryPrice,
          quantity: quantity,
          date: _entryDate,
          memo: '1차 매수',
        );
        final allExecutions = [firstExec, ..._additionalExecutions];
        final calc = TradeEntry.calculateExecutions(
          executions: allExecutions,
          direction: TradeDirection.buy,
          fallbackEntryDate: _entryDate,
          fallbackEntryPrice: entryPrice,
          fallbackQuantity: quantity,
        );

        if (calc.isClosed) {
          await context.read<TradeProvider>().addTrade(
            stockSymbol: symbol,
            stockName: stockName,
            market: market,
            type: TradeType.real,
            direction: TradeDirection.buy,
            entryPrice: calc.averageEntryPrice,
            exitPrice: calc.averageExitPrice ?? entryPrice,
            quantity: calc.totalBuyQuantity,
            entryDate: calc.entryDate,
            exitDate: calc.exitDate ?? _exitDate,
            reason: _reasonCtrl.text,
            strategy: _strategyCtrl.text,
            lesson: _strategyCtrl.text,
            accountTag: _selectedAccountTag,
            executions: allExecutions,
          );
        } else {
          await context.read<TradeProvider>().addPosition(
            stockSymbol: symbol,
            stockName: stockName,
            market: market,
            type: TradeType.real,
            direction: TradeDirection.buy,
            entryPrice: calc.averageEntryPrice,
            quantity: calc.totalBuyQuantity,
            entryDate: calc.entryDate,
            reason: _reasonCtrl.text,
            strategy: _strategyCtrl.text,
            lesson: _strategyCtrl.text,
            accountTag: _selectedAccountTag,
            executions: allExecutions,
          );
        }
      } else if (_isPositionOnly) {
        await context.read<TradeProvider>().addPosition(
          stockSymbol: symbol,
          stockName: stockName,
          market: market,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: entryPrice,
          quantity: quantity,
          entryDate: _entryDate,
          reason: _reasonCtrl.text,
          strategy: _strategyCtrl.text,
          lesson: _strategyCtrl.text,
          accountTag: _selectedAccountTag,
        );
      } else {
        final exitPrice = double.tryParse(_exitPriceCtrl.text) ?? 0;
        if (exitPrice <= 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.error)));
          return;
        }
        await context.read<TradeProvider>().addTrade(
          stockSymbol: symbol,
          stockName: stockName,
          market: market,
          type: TradeType.real,
          direction: TradeDirection.buy,
          entryPrice: entryPrice,
          exitPrice: exitPrice,
          quantity: quantity,
          entryDate: _entryDate,
          exitDate: _exitDate,
          reason: _reasonCtrl.text,
          strategy: _strategyCtrl.text,
          lesson: _strategyCtrl.text,
          accountTag: _selectedAccountTag,
        );
      }

      if (!mounted) return;
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
        SnackBar(
          content: Text('저장에 실패했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SECTION WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            index,
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
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
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    width: 1,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
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
                  color: active
                      ? AppColors.accent
                      : subColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? AppColors.accent
                        : subColor.withValues(alpha: 0.8),
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
  final Color textColor;
  final Color subColor;
  final Color fillColor;
  final FormFieldValidator<String>? validator;
  const _PremiumInputField({
    required this.controller,
    required this.label,
    required this.icon,
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
                  color: AppColors.accentSubtle,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
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
            color: focused ? AppColors.accent : widget.subColor,
            fontSize: 13,
            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: focused
                  ? AppColors.accentSubtle
                  : widget.fillColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              color: focused ? AppColors.accent : widget.subColor,
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
            borderSide: BorderSide(color: AppColors.border, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: AppColors.border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide:  BorderSide(color: AppColors.accent, width: 1.5),
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
  final Color textColor;
  final Color subColor;
  final Color fillColor;
  final FormFieldValidator<String>? validator;
  const _QuantityStepper({
    required this.controller,
    required this.label,
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
                  color: AppColors.accentSubtle,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
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
            color: focused ? AppColors.accent : widget.subColor,
            fontSize: 13,
            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: focused
                  ? AppColors.accentSubtle
                  : widget.fillColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tag_rounded,
              color: focused ? AppColors.accent : widget.subColor,
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
            borderSide: BorderSide(color: AppColors.border, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: AppColors.border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide:  BorderSide(color: AppColors.accent, width: 1.5),
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
  final Color textColor;
  final Color subColor;
  final MarketType? market;
  const _OrderSummaryCard({
    required this.entryPriceCtrl,
    required this.exitPriceCtrl,
    required this.quantityCtrl,
    required this.showPnl,
    required this.textColor,
    required this.subColor,
    required this.market,
  });

  double _read(TextEditingController c) => double.tryParse(c.text) ?? 0;
  int _readInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    // Single builder that subscribes to all three TextEditingControllers at
    // once via Listenable.merge, instead of three nested ValueListenableBuilder
    // blocks (which previously caused three text-style recomputations per
    // keystroke). The `AnimatedContainer` wrapper around the entire card
    // remains so the border/glow still animates when P&L switches sign.
    return ListenableBuilder(
      listenable: Listenable.merge([
        entryPriceCtrl,
        quantityCtrl,
        exitPriceCtrl,
      ]),
      builder: (context, _) {
        final ep = _read(entryPriceCtrl);
        final qty = _readInt(quantityCtrl);
        final xp = _read(exitPriceCtrl);
        final total = ep * qty;
        final hasValue = ep > 0 && qty > 0;
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
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: showPnl && hasValue && xp > 0
                  ? pnlColor.withValues(alpha: 0.25)
                  : AppColors.border,
              width: showPnl && hasValue && xp > 0 ? 1.5 : 1,
            ),
            boxShadow: showPnl && hasValue && xp > 0
                ? [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '총 매수금액',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (hasValue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$qty주',
                        style:  TextStyle(
                          color: AppColors.accent,
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
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (showPnl && hasValue && xp > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(height: 1, color: AppColors.border),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _DatePickerRow({
    required this.entryDate,
    required this.exitDate,
    required this.showExit,
    required this.entryLabel,
    required this.exitLabel,
    required this.onPickEntry,
    required this.onPickExit,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
  });

  Future<void> _pick(
    BuildContext context,
    DateTime current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:  ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.text,
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
      textColor: textColor,
      subColor: subColor,
      cardColor: cardColor,
    );
    if (!showExit) return card;
    return Row(
      children: [
        Expanded(child: card),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DateCard(
            label: exitLabel,
            date: exitDate,
            onTap: () => _pick(context, exitDate, onPickExit),
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
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _DateCard({
    required this.label,
    required this.date,
    required this.onTap,
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
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.royalBlue.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:  Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.accent,
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
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: subColor.withValues(alpha: 0.7),
                size: 18,
              ),
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
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  const _NotesArea({
    required this.controller,
    required this.icon,
    required this.hint,
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
    final borderColor = focused
        ? AppColors.accent.withValues(alpha: 0.6)
        : AppColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: focused ? 1.5 : 1),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.accentSubtle,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 14, color: AppColors.accent),
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
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 14.5,
                height: 1.65,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                hintText: '자유롭게 메모를 적어보세요...',
                hintStyle: TextStyle(
                  color: widget.subColor.withValues(alpha: 0.6),
                  fontSize: 13.5,
                  height: 1.65,
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
              gradient:  LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.accentStrong],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentStrong.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style:  TextStyle(
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
