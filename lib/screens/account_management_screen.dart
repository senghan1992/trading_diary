import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show MainTabRouter;
import '../models/account_tag.dart';
import '../models/trade_analytics.dart';
import '../providers/trade_provider.dart';
import '../services/trade_analytics_calculator.dart'
    show kUnassignedAccount, TradeAnalyticsCalculator;
import '../theme/app_theme.dart';

/// Quick-pick broker preset shown as a chip in the add/edit dialog.
///
/// Names are Korean brand proper nouns that never localize, so they live
/// here as private consts instead of the arb.
class _BrokerPreset {
  final String name;
  final int colorValue;
  const _BrokerPreset(this.name, this.colorValue);
}

const List<_BrokerPreset> _brokerPresets = [
  _BrokerPreset('키움증권', 0xFF004CFF),
  _BrokerPreset('미래에셋증권', 0xFF00A9E0),
  _BrokerPreset('토스증권', 0xFF0064FF),
  _BrokerPreset('한국투자증권', 0xFF0F172A),
  _BrokerPreset('삼성증권', 0xFF0018A8),
  _BrokerPreset('NH투자증권', 0xFF0067AC),
  _BrokerPreset('KB증권', 0xFFFFB81C),
  _BrokerPreset('신한투자증권', 0xFF0046FF),
  _BrokerPreset('카카오페이증권', 0xFFFFCD00),
];

const int _etcPresetColor = 0xFFF59E0B;

/// Quick-pick account-type preset combined with a broker to auto-compose
/// intuitive tag names like `[토스증권] ISA 계좌`. Labels localize through
/// the arb; the composed name keeps whatever label the active locale
/// produced, which is the display name users see everywhere.
const List<String> _accountTypeKeys = [
  'cash',
  'isa',
  'pension',
  'irp',
  'cma',
];

/// Account registry + per-account realised P&L dashboard.
///
/// The registry ([TradeProvider.accounts]) is the source of the row list;
/// aggregated stats from
/// [TradeAnalyticsCalculator.computeAccountPerformance] are joined by tag
/// name so accounts with zero trades still appear (with all-zero stats).
/// Trades without any tag are summarised in a trailing "미지정" card.
/// Add / edit / delete run through dialogs (with one-tap broker presets);
/// tapping a row drills back to the Journal tab pre-filtered to that
/// account via [MainTabRouter].
class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();

    // Aggregate on ALL trades — this dashboard is global, not subject to
    // the journal's real/virtual chip or period filter.
    final statsByName = {
      for (final row in TradeAnalyticsCalculator.computeAccountPerformance(
        provider.trades,
        const TradeAnalyticsFilter(),
        accountColors: {
          for (final a in provider.accounts)
            if (a.colorValue != null) a.name: a.colorValue!,
        },
      ))
        row.accountName: row,
    };
    // Zero-stat fallback so every registered account gets a row.
    AccountPerformanceSummary statsFor(AccountTag account) {
      return statsByName[account.name] ??
          AccountPerformanceSummary(
            accountName: account.name,
            colorValue: account.colorValue,
            tradeCount: 0,
            openPositionCount: 0,
            winCount: 0,
            lossCount: 0,
            breakevenCount: 0,
            winRate: 0,
            totalProfitLoss: 0,
            averageReturnPercent: 0,
            totalInvested: 0,
            profitFactor: 0,
            bestTrade: null,
            worstTrade: null,
          );
    }

    // Untagged history gets its own summary card so it is never invisible.
    final unassignedStats = statsByName[kUnassignedAccount];
    final hasUnassigned =
        unassignedStats != null &&
        (unassignedStats.tradeCount > 0 ||
            unassignedStats.openPositionCount > 0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          l10n.accountManagement,
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(context),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(l10n.addAccount),
      ),
      body: provider.accounts.isEmpty && !hasUnassigned
          ? Center(
              child: Text(
                l10n.noAccountsRegistered,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                // Keep rows clear of the FAB.
                bottom: AppSpacing.xxxl + 56,
              ),
              itemCount: provider.accounts.length + (hasUnassigned ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index == provider.accounts.length) {
                  return _buildAccountCard(
                    context,
                    row: unassignedStats!,
                    displayName: l10n.unassignedAccount,
                    l10n: l10n,
                    isUnassigned: true,
                  );
                }
                final account = provider.accounts[index];
                return _buildAccountCard(
                  context,
                  row: statsFor(account),
                  displayName: account.name,
                  l10n: l10n,
                );
              },
            ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context, {
    required AccountPerformanceSummary row,
    required String displayName,
    required AppLocalizations l10n,
    bool isUnassigned = false,
  }) {
    final pnl = row.totalProfitLoss;
    final pnlColor = pnl > 0
        ? AppColors.green
        : (pnl < 0 ? AppColors.red : AppColors.text);
    final formatter = NumberFormat('#,###');
    final accent = row.colorValue != null
        ? Color(row.colorValue!)
        : AppColors.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _drillIntoJournal(context, row.accountName),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!isUnassigned) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.textMuted,
                        tooltip: l10n.editAccount,
                        onPressed: () {
                          final provider = context.read<TradeProvider>();
                          final account = provider.accounts
                              .where((a) => a.name == row.accountName)
                              .firstOrNull;
                          if (account != null) {
                            _showAccountDialog(context, existing: account);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        color: AppColors.red,
                        tooltip: l10n.deleteAccount,
                        onPressed: () =>
                            _confirmDelete(context, row.accountName),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                  style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _stat(
                        l10n.totalTrades,
                        l10n.tradesCount(row.tradeCount),
                        AppColors.text,
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        l10n.winRate,
                        '${row.winRate.toStringAsFixed(1)}%',
                        AppColors.text,
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        l10n.openPosition,
                        l10n.openPositionsCount(row.openPositionCount),
                        AppColors.accent,
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        l10n.investedCapital,
                        formatter.format(row.totalInvested),
                        AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  /// Add / edit dialog. When [existing] is null this creates a new
  /// account; otherwise it updates name / color / memo in place.
  ///
  /// Two chip rows compose the tag name in one tap: a broker preset
  /// (fills the name field and stamps the brand color) plus an account
  /// type (위탁 / ISA / 연금 …). Picking both auto-completes an intuitive
  /// composed name like `[토스증권] ISA 계좌`; the text field stays fully
  /// editable for custom names.
  Future<void> _showAccountDialog(
    BuildContext context, {
    AccountTag? existing,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TradeProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var colorValue = existing?.colorValue;

    // Localized account-type labels, in the same order as
    // [_accountTypeKeys].
    final typeLabels = {
      'cash': l10n.accountTypeCash,
      'isa': l10n.accountTypeIsa,
      'pension': l10n.accountTypePension,
      'irp': l10n.accountTypeIrp,
      'cma': l10n.accountTypeCma,
    };
    String typeLabelForKey(String key) => typeLabels[key]!;

    String? selectedBroker;
    String? selectedTypeKey;
    if (existing != null) {
      final broker = existing.brokerName;
      if (_brokerPresets.any((p) => p.name == broker)) {
        selectedBroker = broker;
      }
      final type = existing.accountTypeLabel;
      for (final key in _accountTypeKeys) {
        if (typeLabelForKey(key) == type) {
          selectedTypeKey = key;
          break;
        }
      }
    }

    final presets = [
      ..._brokerPresets,
      _BrokerPreset(l10n.marketEtc, _etcPresetColor),
    ];

    const palette = [
      0xFF6C5CE7,
      0xFF00B894,
      0xFF0984E3,
      0xFFE17055,
      0xFFE84393,
      0xFFFDCA40,
      0xFF00CEC9,
      0xFFD63031,
    ];

    /// Re-composes the editable name field from the current chip picks.
    /// Chips stay a convenience: the user can always override the text.
    void recomposeName() {
      if (selectedBroker == null) return;
      nameCtrl.text = AccountTag.composeName(
        selectedBroker!,
        selectedTypeKey == null ? null : typeLabelForKey(selectedTypeKey!),
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.addAccount : l10n.editAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.brokerAccount,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in presets)
                      ActionChip(
                        avatar: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(p.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: selectedBroker == p.name
                                ? AppColors.accent
                                : AppColors.text,
                            fontWeight: selectedBroker == p.name
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        backgroundColor: selectedBroker == p.name
                            ? AppColors.accentSubtle
                            : null,
                        side: BorderSide(
                          color: selectedBroker == p.name
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setDialogState(() {
                          selectedBroker = selectedBroker == p.name
                              ? null
                              : p.name;
                          colorValue = p.colorValue;
                          recomposeName();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.accountType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final key in _accountTypeKeys)
                      ActionChip(
                        label: Text(
                          typeLabelForKey(key),
                          style: TextStyle(
                            fontSize: 12,
                            color: selectedTypeKey == key
                                ? AppColors.accent
                                : AppColors.text,
                            fontWeight: selectedTypeKey == key
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        backgroundColor: selectedTypeKey == key
                            ? AppColors.accentSubtle
                            : null,
                        side: BorderSide(
                          color: selectedTypeKey == key
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setDialogState(() {
                          selectedTypeKey = selectedTypeKey == key
                              ? null
                              : key;
                          recomposeName();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null && selectedBroker == null,
                  decoration: InputDecoration(
                    labelText: l10n.accountName,
                    hintText: l10n.accountNameHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: memoCtrl,
                  decoration: InputDecoration(labelText: l10n.accountMemoHint),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in palette)
                      GestureDetector(
                        onTap: () => setDialogState(
                          () => colorValue = colorValue == c ? null : c,
                        ),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: colorValue == c
                                ? Border.all(width: 3, color: AppColors.text)
                                : Border.all(width: 1, color: AppColors.border),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                MaterialLocalizations.of(dialogCtx).cancelButtonLabel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.success),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    if (saved != true || name.isEmpty || !context.mounted) return;
    final memo = memoCtrl.text.trim();
    if (existing == null) {
      await provider.addAccount(
        name: name,
        colorValue: colorValue,
        memo: memo.isEmpty ? null : memo,
      );
    } else {
      await provider.updateAccount(
        existing.copyWith(
          name: name,
          colorValue: colorValue,
          memo: memo.isEmpty ? null : memo,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, String accountName) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TradeProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(MaterialLocalizations.of(dialogCtx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final account = provider.accounts
        .where((a) => a.name == accountName)
        .firstOrNull;
    if (account != null) {
      await provider.deleteAccount(account.id);
      // Keep the journal filter consistent: a deleted account can't stay
      // selected or the integrated view looks empty.
      if (provider.selectedAccountTagFilter == accountName && context.mounted) {
        context.read<TradeProvider>().setSelectedAccountTagFilter(null);
      }
    }
  }

  /// Drill-in: jump back to the Journal tab pre-filtered to this account
  /// so the user sees exactly that account's trade history. Uses [MainTabRouter]
  /// to switch to the Journal tab.
  void _drillIntoJournal(BuildContext context, String accountName) {
    context.read<TradeProvider>().setSelectedAccountTagFilter(accountName);
    Navigator.of(context).pop();
    MainTabRouter.jumpToJournal();
  }
}
