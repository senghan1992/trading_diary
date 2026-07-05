import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';

/// Full-screen blocking surface shown when the server says the installed
/// app version is below the minimum required version.
///
/// Unlike [UpdateDialog], this takes over the entire Scaffold - the user
/// cannot reach any other UI until they tap "Update" and install the new
/// version. The Android back button is also intercepted via [PopScope].
///
/// Pass [config] when the call site has already fetched it; otherwise the
/// screen will refetch on init. The screen owns a retry affordance for
/// the case where the config fetch failed at startup.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({super.key, this.config});

  final UpdateConfig? config;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  UpdateConfig? _config;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    if (_config == null) {
      // ignore: discarded_futures
      _refetch();
    }
  }

  Future<void> _refetch() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    final config = await UpdateService.instance.getConfig(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _config = config;
      _fetching = false;
      _error = config == null
          ? '업데이트 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'
          : null;
    });
  }

  Future<void> _openStore() async {
    final config = _config;
    final ok = await UpdateService.instance.openStore(config: config);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스토어를 열 수 없습니다. 잠시 후 다시 시도해주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = _config;
    final message = config?.messageFor(Localizations.localeOf(context).languageCode);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.system_update_alt,
                    size: 96,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.updateRequiredTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (message != null && message.isNotEmpty)
                        ? message
                        : l10n.updateDefaultBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _fetching ? null : _openStore,
                    icon: _fetching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shop),
                    label: Text(l10n.update),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _fetching ? null : _refetch,
                    child: Text(l10n.retry),
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