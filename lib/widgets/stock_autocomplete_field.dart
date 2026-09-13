import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/stock_data_service.dart';
import '../theme/app_theme.dart';

/// An auto-completing stock name input field.
///
/// Features:
/// - Real-time matching by stock name, ticker code, and Korean initial consonants (chosung).
/// - Styled to match the app's design system (dark/light brightness aware).
/// - When an item is selected from suggestions, invokes [onSelected] with the [StockItem].
/// - Allows free-form text input for unlisted or custom symbols.
class StockAutocompleteField extends StatefulWidget {
  const StockAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.onSelected,
    this.currentMarket,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<StockItem>? onSelected;
  final MarketType? currentMarket;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<StockAutocompleteField> createState() => _StockAutocompleteFieldState();
}

class _StockAutocompleteFieldState extends State<StockAutocompleteField> {
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _ownsFocusNode = true;
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Widget _buildMarketBadge(MarketType market) {
    Color badgeBg;
    Color badgeText;
    String label;

    switch (market) {
      case MarketType.kospi:
        badgeBg = AppColors.accentSubtle;
        badgeText = AppColors.accent;
        label = 'KOSPI';
        break;
      case MarketType.kosdaq:
        badgeBg = const Color(0x229C27B0);
        badgeText = const Color(0xFFBA68C8);
        label = 'KOSDAQ';
        break;
      case MarketType.nasdaq:
        badgeBg = const Color(0x22D6B678);
        badgeText = AppColors.gold;
        label = 'NASDAQ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final inputFill = AppColors.surface;
    final cardColor = AppColors.card;

    return RawAutocomplete<StockItem>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) {
          return const Iterable<StockItem>.empty();
        }
        return StockDataService.instance.search(
          query,
          filterMarket: null, // Allow cross-market search with ranking
          limit: 15,
        );
      },
      displayStringForOption: (StockItem option) => option.name,
      onSelected: (StockItem selection) {
        widget.controller.text = selection.name;
        widget.onSelected?.call(selection);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          textInputAction: widget.textInputAction,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(color: subColor, fontSize: 13),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 12, right: 8),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_center_outlined,
                color: AppColors.accent,
                size: 16,
              ),
            ),
            filled: true,
            fillColor: inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: AppColors.border,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: AppColors.border,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: AppColors.accent,
                width: 1.5,
              ),
            ),
          ),
          validator: widget.validator,
          onFieldSubmitted: (value) {
            onFieldSubmitted();
            widget.onFieldSubmitted?.call(value);
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<StockItem> onSelected,
        Iterable<StockItem> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: cardColor,
            child: Container(
              width: MediaQuery.of(context).size.width - (AppSpacing.lg * 2),
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (BuildContext context, int index) {
                  final StockItem option = options.elementAt(index);
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.code,
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _buildMarketBadge(option.market),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
