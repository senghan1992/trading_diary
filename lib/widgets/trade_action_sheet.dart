import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trade_entry.dart';
import '../providers/trade_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

import 'responsive_layout.dart';

enum TradeActionTab { sell, buy }

class TradeActionSheet extends StatefulWidget {
  final TradeEntry trade;
  final TradeProvider provider;
  final TradeActionTab initialTab;

  const TradeActionSheet({
    super.key,
    required this.trade,
    required this.provider,
    this.initialTab = TradeActionTab.sell,
  });

  static Future<void> show(
    BuildContext context, {
    required TradeEntry trade,
    TradeActionTab initialTab = TradeActionTab.sell,
  }) {
    final provider = context.read<TradeProvider>();
    return ResponsiveSheet.show<void>(
      context: context,
      builder: (_) => TradeActionSheet(
        trade: trade,
        provider: provider,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<TradeActionSheet> createState() => _TradeActionSheetState();
}

class _TradeActionSheetState extends State<TradeActionSheet> {
  late TradeActionTab _activeTab;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _memoCtrl;
  late DateTime _actionDate;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _priceCtrl = TextEditingController();
    _quantityCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
    _actionDate = DateTime.now();

    if (_activeTab == TradeActionTab.sell) {
      _quantityCtrl.text = widget.trade.remainingQuantity.toString();
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged(TradeActionTab tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _priceCtrl.clear();
      _memoCtrl.clear();
      if (tab == TradeActionTab.sell) {
        _quantityCtrl.text = widget.trade.remainingQuantity.toString();
      } else {
        _quantityCtrl.clear();
      }
    });
  }

  void _setSellQuantityPercent(double pct) {
    final qty = (widget.trade.remainingQuantity * pct).round();
    final clamped = qty.clamp(1, widget.trade.remainingQuantity);
    setState(() {
      _quantityCtrl.text = clamped.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final upColor = themeProvider.upColor;
    final downColor = themeProvider.downColor;
    final market = widget.trade.market ?? inferMarketFromSymbol(widget.trade.stockSymbol);
    final symbol = currencySymbolFor(market);
    final remainingQty = widget.trade.remainingQuantity;
    final avgEntry = widget.trade.entryPrice;
    final formatter = NumberFormat('#,###');

    final parsedPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final parsedQty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Stock name & current position snapshot
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trade.stockName,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '현재 보유: ${formatter.format(remainingQty)}주  ·  평단가: $symbol${formatter.format(avgEntry.round())}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tab switch: [매도 기록 (분할/전량)] vs [추가 매수]
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: '매도 기록 (분할/전량)',
                      icon: Icons.sell_outlined,
                      isActive: _activeTab == TradeActionTab.sell,
                      activeColor: downColor,
                      onTap: () => _onTabChanged(TradeActionTab.sell),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _TabButton(
                      label: '추가 매수',
                      icon: Icons.add_circle_outline,
                      isActive: _activeTab == TradeActionTab.buy,
                      activeColor: upColor,
                      onTap: () => _onTabChanged(TradeActionTab.buy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick quantity chips (Sell mode only)
            if (_activeTab == TradeActionTab.sell) ...[
              Row(
                children: [
                  Text(
                    '매도 수량 선택',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _PercentChip(
                    label: '25%',
                    onTap: () => _setSellQuantityPercent(0.25),
                  ),
                  const SizedBox(width: 6),
                  _PercentChip(
                    label: '50%',
                    onTap: () => _setSellQuantityPercent(0.50),
                  ),
                  const SizedBox(width: 6),
                  _PercentChip(
                    label: '전량(100%)',
                    isSelected: parsedQty == remainingQty,
                    onTap: () => _setSellQuantityPercent(1.0),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Input Fields: Quantity & Price
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _activeTab == TradeActionTab.sell ? '매도 수량' : '추가 매수 수량',
                      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      suffixText: '주',
                      suffixStyle: TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _activeTab == TradeActionTab.sell ? '체결 매도가' : '체결 매수가',
                      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      prefixText: '$symbol ',
                      prefixStyle: TextStyle(color: AppColors.text),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date Picker & Memo Field
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _actionDate,
                        firstDate: widget.trade.entryDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (_, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: AppColors.accent),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _actionDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy.MM.dd').format(_actionDate),
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _memoCtrl,
                    style: TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '메모 (예: 1차익절)',
                      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Preview Card
            if (parsedPrice > 0 && parsedQty > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _activeTab == TradeActionTab.sell
                    ? _buildSellPreview(
                        symbol: symbol,
                        remainingQty: remainingQty,
                        avgEntry: avgEntry,
                        sellPrice: parsedPrice,
                        sellQty: parsedQty,
                        formatter: formatter,
                        upColor: upColor,
                        downColor: downColor,
                      )
                    : _buildBuyPreview(
                        symbol: symbol,
                        remainingQty: remainingQty,
                        avgEntry: avgEntry,
                        buyPrice: parsedPrice,
                        buyQty: parsedQty,
                        formatter: formatter,
                      ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleSubmit(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _activeTab == TradeActionTab.sell ? downColor : upColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _activeTab == TradeActionTab.sell
                      ? (parsedQty >= remainingQty ? '전량 매도 완료하기' : '분할 매도 기록 저장')
                      : '추가 매수 기록 저장',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellPreview({
    required String symbol,
    required int remainingQty,
    required double avgEntry,
    required double sellPrice,
    required int sellQty,
    required NumberFormat formatter,
    required Color upColor,
    required Color downColor,
  }) {
    final validQty = sellQty.clamp(1, remainingQty);
    final pnl = (sellPrice - avgEntry) * validQty;
    final returnPct = avgEntry > 0 ? ((sellPrice - avgEntry) / avgEntry) * 100 : 0.0;
    final pnlColor = pnl >= 0 ? upColor : downColor;
    final isFullExit = validQty >= remainingQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '예상 실현 손익',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${pnl >= 0 ? '+' : ''}$symbol${formatter.format(pnl.round())} (${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}%)',
              style: TextStyle(
                color: pnlColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '매도 후 상태',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              isFullExit
                  ? '포지션 전량 청산 (완료)'
                  : '잔여 ${formatter.format(remainingQty - validQty)}주 보유 (평단가 유지)',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBuyPreview({
    required String symbol,
    required int remainingQty,
    required double avgEntry,
    required double buyPrice,
    required int buyQty,
    required NumberFormat formatter,
  }) {
    final newTotalQty = remainingQty + buyQty;
    final newAvgPrice = newTotalQty > 0
        ? ((remainingQty * avgEntry) + (buyQty * buyPrice)) / newTotalQty
        : buyPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '매수 후 총 보유 수량',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${formatter.format(newTotalQty)}주 (+${formatter.format(buyQty)}주)',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '매수 후 예상 평단가',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$symbol${formatter.format(avgEntry.round())} ➔ $symbol${formatter.format(newAvgPrice.round())}',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final price = double.tryParse(_priceCtrl.text.trim());
    final qty = int.tryParse(_quantityCtrl.text.trim());
    final memo = _memoCtrl.text.trim();

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_activeTab == TradeActionTab.sell ? '올바른 매도가를 입력해주세요.' : '올바른 매수가를 입력해주세요.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 수량을 입력해주세요.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_activeTab == TradeActionTab.sell && qty > widget.trade.remainingQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('매도 수량은 현재 보유 수량(${widget.trade.remainingQuantity}주)을 초과할 수 없습니다.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (_activeTab == TradeActionTab.sell) {
        await widget.provider.closePosition(
          tradeId: widget.trade.id,
          exitPrice: price,
          exitDate: _actionDate,
          quantity: qty,
        );
      } else {
        await widget.provider.addTradeExecution(
          tradeId: widget.trade.id,
          action: TradeExecutionAction.buy,
          price: price,
          quantity: qty,
          date: _actionDate,
          memo: memo.isNotEmpty ? memo : '추가 매수',
        );
      }

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _activeTab == TradeActionTab.sell
                ? (qty >= widget.trade.remainingQuantity ? '전량 매도가 완료되었습니다.' : '분할 매도가 기록되었습니다.')
                : '추가 매수가 성공적으로 기록되었습니다.',
          ),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('저장에 실패했습니다: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? activeColor : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : AppColors.textMuted,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PercentChip({
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
