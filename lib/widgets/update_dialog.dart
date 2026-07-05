import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';

/// Modal that surfaces an available app update.
///
/// When [required] is true the dialog is non-dismissible: the user must
/// update to continue using the app. Both barrier tap and the Android
/// back button are intercepted via [PopScope]. When false the user sees
/// the dialog but can tap "Later" to dismiss it for the rest of the
/// session.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.required,
    this.message,
  });

  final bool required;
  final String? message;

  /// Convenience wrapper. Builds the dialog with the right PopScope
  /// semantics and pushes it via [showDialog].
  static Future<void> show(
    BuildContext context, {
    required bool required,
    String? message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !required,
      builder: (dialogContext) => PopScope(
        canPop: !required,
        child: UpdateDialog(required: required, message: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    final title = required
        ? (isKo ? '업데이트 필요' : 'Update Required')
        : (isKo ? '업데이트 가능' : 'Update Available');

    final body = (message != null && message!.isNotEmpty)
        ? message!
        : (isKo
            ? '더 나은 경험을 위해 최신 버전으로 업데이트해 주세요.'
            : 'A new version is available. Please update for the best experience.');

    final primaryLabel = l10n.update;
    final secondaryLabel = l10n.later;

    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: required
          ? [
              FilledButton(
                onPressed: () {
                  // Fire-and-forget. openStore returns false if no URL
                  // resolves, which we can't recover from in-dialog.
                  // ignore: discarded_futures
                  UpdateService.instance.openStore();
                },
                child: Text(primaryLabel),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(secondaryLabel),
              ),
              FilledButton(
                onPressed: () {
                  // ignore: discarded_futures
                  UpdateService.instance.openStore();
                  // Don't auto-dismiss: opening the store kicks the user
                  // out of the app. They re-enter when they're done.
                },
                child: Text(primaryLabel),
              ),
            ],
    );
  }
}