import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/trade_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import '../services/excel_export_service.dart';
import '../services/stock_data_service.dart';
import 'account_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final tradeProvider = context.watch<TradeProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(l10n.settings)),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl + 32,
          ),
          children: [
            // ── 화면 디스플레이 설정 ──
            _SectionHeader(
              title: l10n.display,
              subtitle: l10n.displaySubtitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                // 1) 테마 모드 선택 (컴팩트 3분할 세그먼트)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.brightness_medium_rounded,
                              color: AppColors.orange,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            l10n.themeMode,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CompactSegmentedControl<ThemeMode>(
                        selectedValue: themeProvider.themeMode,
                        onValueChanged: (mode) =>
                            themeProvider.setThemeMode(mode),
                        items: [
                          _SegmentItem(
                            value: ThemeMode.system,
                            icon: Icons.brightness_auto_rounded,
                            label: l10n.themeModeSystem,
                          ),
                          _SegmentItem(
                            value: ThemeMode.light,
                            icon: Icons.light_mode_rounded,
                            label: l10n.themeModeLight,
                          ),
                          _SegmentItem(
                            value: ThemeMode.dark,
                            icon: Icons.dark_mode_rounded,
                            label: l10n.themeModeDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const _SettingsDivider(),
                // 2) 가격 등락 색상 선택 (직관적인 컬러 인디케이터 세그먼트)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.palette_outlined,
                              color: AppColors.orange,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.priceColors,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  themeProvider.useKoreanColors
                                      ? l10n.priceColorsKorean
                                      : l10n.priceColorsWestern,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CompactSegmentedControl<bool>(
                        selectedValue: themeProvider.useKoreanColors,
                        onValueChanged: (v) =>
                            themeProvider.setKoreanColors(v),
                        items: [
                          _SegmentItem(
                            value: true,
                            customIcon: const _ColorIndicators(
                              upColor: AppColors.red,
                              downColor: AppColors.blue,
                            ),
                            label: _extractColorLabel(
                              l10n.priceColorsKorean,
                              defaultLabel: '한국식',
                            ),
                          ),
                          _SegmentItem(
                            value: false,
                            customIcon: const _ColorIndicators(
                              upColor: AppColors.green,
                              downColor: AppColors.red,
                            ),
                            label: _extractColorLabel(
                              l10n.priceColorsWestern,
                              defaultLabel: '서양식',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 계좌 및 데이터 관리 ──
            _SectionHeader(
              title: l10n.dataManagement,
              subtitle: l10n.accountPerformance,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _MenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.accent,
                  title: l10n.accountManagement,
                  subtitle: tradeProvider.accounts.isEmpty
                      ? (languageProvider.isKorean
                          ? '등록된 계좌 없음 (탭하여 추가)'
                          : 'No accounts (Tap to add)')
                      : (languageProvider.isKorean
                          ? '${tradeProvider.accounts.length}개 계좌 등록됨'
                          : '${tradeProvider.accounts.length} accounts registered'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tradeProvider.accounts.isNotEmpty) ...[
                        SizedBox(
                          height: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final account
                                  in tradeProvider.accounts.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: account.colorValue != null
                                          ? Color(account.colorValue!)
                                          : AppColors.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountManagementScreen(),
                    ),
                  ),
                ),
                const _SettingsDivider(),
                _MenuTile(
                  icon: Icons.table_view_rounded,
                  iconColor: AppColors.green,
                  title: l10n.exportToExcel,
                  subtitle: l10n.exportCsvDescription,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  onTap: () => ExcelExportService.showExportDialog(
                    context,
                    tradeProvider.trades,
                  ),
                ),
                const _SettingsDivider(),
                const _StockSyncTile(),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 언어 설정 (컴팩트 1행 세그먼트) ──
            _SectionHeader(
              title: l10n.languageSection,
              subtitle: l10n.languageSectionSubtitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          color: AppColors.blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.language,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              languageProvider.isKorean
                                  ? l10n.korean
                                  : l10n.english,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: _CompactSegmentedControl<String>(
                          selectedValue:
                              languageProvider.isKorean ? 'ko' : 'en',
                          onValueChanged: (code) =>
                              languageProvider.setLocale(Locale(code)),
                          items: const [
                            _SegmentItem(
                              value: 'ko',
                              label: '한국어',
                            ),
                            _SegmentItem(
                              value: 'en',
                              label: 'English',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _extractColorLabel(
    String fullText, {
    required String defaultLabel,
  }) {
    if (fullText.contains('(')) {
      final part = fullText.split('(').first.trim();
      if (part.isNotEmpty) return part;
    }
    return defaultLabel;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:  TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style:  TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: AppColors.border,
    );
  }
}

/// 상승 / 하락 화살표 컬러 인디케이터
class _ColorIndicators extends StatelessWidget {
  final Color upColor;
  final Color downColor;

  const _ColorIndicators({
    required this.upColor,
    required this.downColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_drop_up_rounded, color: upColor, size: 16),
        Icon(Icons.arrow_drop_down_rounded, color: downColor, size: 16),
      ],
    );
  }
}

class _SegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? customIcon;

  const _SegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.customIcon,
  });
}

/// 컴팩트 세그먼트 컨트롤 위젯
class _CompactSegmentedControl<T> extends StatelessWidget {
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final List<_SegmentItem<T>> items;

  const _CompactSegmentedControl({
    required this.selectedValue,
    required this.onValueChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.value == selectedValue;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onValueChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: isSelected
                      ? Border.all(color: AppColors.border, width: 0.5)
                      : null,
                  boxShadow: isSelected ? AppColors.cardShadow : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.customIcon != null) ...[
                      item.customIcon!,
                      const SizedBox(width: 4),
                    ] else if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 15,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StockSyncTile extends StatelessWidget {
  const _StockSyncTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isKorean = l10n.localeName == 'ko';
    final service = StockDataService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final count = service.stocks.length;
        final lastSync = service.lastSyncTime;
        final syncTimeText = lastSync != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(lastSync)
            : (isKorean ? '기본 데이터 사용 중' : 'Using bundled data');

        final title = isKorean ? '종목 검색 데이터' : 'Stock Search Data';
        final subtitle = isKorean
            ? '$count개 종목 탑재 (최근: $syncTimeText)'
            : '$count stocks loaded (Last: $syncTimeText)';

        return _MenuTile(
          icon: Icons.search_rounded,
          iconColor: AppColors.royalBlue,
          title: title,
          subtitle: subtitle,
          trailing: service.isSyncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.royalBlue),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.sync_rounded,
                    color: AppColors.royalBlue,
                    size: 22,
                  ),
                  tooltip: isKorean ? '종목 데이터 지금 업데이트' : 'Sync stocks now',
                  onPressed: () async {
                    final success = await service.syncLatestStocks(force: true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (isKorean
                                  ? '종목 데이터가 최신으로 업데이트되었습니다.'
                                  : 'Stock data successfully updated.')
                              : (isKorean
                                  ? '최신 데이터를 확인했습니다. (현재 버전 유지)'
                                  : 'Stock data is already up-to-date.'),
                        ),
                      ),
                    );
                  },
                ),
          onTap: service.isSyncing
              ? null
              : () async {
                  final success = await service.syncLatestStocks(force: true);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (isKorean
                                ? '종목 데이터가 최신으로 업데이트되었습니다.'
                                : 'Stock data successfully updated.')
                            : (isKorean
                                ? '최신 데이터를 확인했습니다. (현재 버전 유지)'
                                : 'Stock data is already up-to-date.'),
                      ),
                    ),
                  );
                },
        );
      },
    );
  }
}

