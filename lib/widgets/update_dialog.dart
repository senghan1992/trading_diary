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

    final title =
        required ? l10n.updateRequiredTitle : l10n.updateAvailableTitle;
    final body = (message != null && message!.isNotEmpty)
        ? message!
        : l10n.updateDefaultBody;

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
                child: Text(l10n.update),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.later),
              ),
              FilledButton(
                onPressed: () {
                  // Don't auto-dismiss: opening the store kicks the user
                  // out of the app. They re-enter when they're done.
                  // ignore: discarded_futures
                  UpdateService.instance.openStore();
                },
                child: Text(l10n.update),
              ),
            ],
    );
  }
}