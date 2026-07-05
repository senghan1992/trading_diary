import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/trade_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/responsive_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final tradeProvider = context.watch<TradeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl + 32),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AdBanner(),
            ),
            _SectionHeader(title: l10n.display, subtitle: l10n.displaySubtitle),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              isDark: isDark,
              children: [
                _MenuTile(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  iconColor: AppColors.purpleLight,
                  title: l10n.screenMode,
                  subtitle: isDark ? l10n.darkMode : l10n.lightMode,
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: AppColors.purpleLight,
                    onChanged: (v) => themeProvider.setDarkMode(v),
                  ),
                ),
                _SettingsDivider(isDark: isDark),
                _MenuTile(
                  icon: Icons.palette_outlined,
                  iconColor: AppColors.orange,
                  title: l10n.priceColors,
                  subtitle: themeProvider.useKoreanColors ? l10n.priceColorsKorean : l10n.priceColorsWestern,
                  trailing: Switch(
                    value: themeProvider.useKoreanColors,
                    activeThumbColor: AppColors.red,
                    activeTrackColor: AppColors.red.withValues(alpha: 0.4),
                    onChanged: (v) => themeProvider.setKoreanColors(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionHeader(title: l10n.notifications, subtitle: l10n.notificationsSubtitle),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              isDark: isDark,
              children: [
                _MenuTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.orange,
                  title: l10n.notificationsEnabled,
                  subtitle: l10n.notificationsEnabledSubtitle,
                  trailing: Switch(
                    value: notificationProvider.isEnabled,
                    activeThumbColor: AppColors.orange,
                    activeTrackColor: AppColors.orange.withValues(alpha: 0.4),
                    onChanged: (v) async {
                      if (v && !notificationProvider.isOsGranted) {
                        final granted = await notificationProvider.requestPermission(
                          reminders: tradeProvider.reminders,
                        );
                        if (!granted) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.notificationsPermissionDenied),
                              action: SnackBarAction(
                                label: l10n.notificationsOpenSettings,
                                onPressed: notificationProvider.openSystemSettings,
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      await notificationProvider.setEnabled(
                        v,
                        reminders: tradeProvider.reminders,
                      );
                      if (!context.mounted) return;
                      final pending = tradeProvider.reminders
                          .where((r) => !r.isRead && r.remindAt.isAfter(DateTime.now()))
                          .length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.notificationsRescheduleDone(pending)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                if (notificationProvider.isEnabled && !notificationProvider.isOsGranted) ...[
                  _SettingsDivider(isDark: isDark),
                  _MenuTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.red,
                    title: l10n.notificationsPermissionDenied,
                    subtitle: l10n.notificationsOpenSettings,
                    onTap: notificationProvider.openSystemSettings,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionHeader(title: l10n.languageSection, subtitle: l10n.languageSectionSubtitle),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              isDark: isDark,
              children: [
                _MenuTile(
                  icon: Icons.translate_rounded,
                  iconColor: AppColors.purpleLight,
                  title: l10n.korean,
                  subtitle: l10n.korean,
                  trailing: languageProvider.isKorean
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.purpleLight, size: 22)
                      : const Icon(Icons.circle_outlined, color: null, size: 22),
                  onTap: () => languageProvider.setLocale(const Locale('ko')),
                ),
                _SettingsDivider(isDark: isDark),
                _MenuTile(
                  icon: Icons.language_rounded,
                  iconColor: AppColors.blue,
                  title: l10n.english,
                  subtitle: l10n.english,
                  trailing: languageProvider.isEnglish
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.purpleLight, size: 22)
                      : const Icon(Icons.circle_outlined, color: null, size: 22),
                  onTap: () => languageProvider.setLocale(const Locale('en')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.purpleLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? AppColors.silverBlue : AppColors.lightTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder),
      ),
      child: Column(children: children),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
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
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: subColor)),
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
  final bool isDark;
  const _SettingsDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder,
    );
  }
}
