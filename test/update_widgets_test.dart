// Widget tests for UpdateDialog and ForceUpdateScreen.
//
// UpdateService.openStore is intentionally not mocked: it talks to platform
// channels that aren't available in the widget test harness. Instead these
// tests pin the user-visible behavior — what strings appear on screen,
// which buttons are present, and how tapping a button changes state.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/screens/force_update_screen.dart';
import 'package:trading_diary/services/update_service.dart';
import 'package:trading_diary/widgets/update_dialog.dart';

/// Common test harness: MaterialApp with the localization delegates the
/// production app uses, plus a configurable initial locale. The dialog and
/// screen both rely on `AppLocalizations.of(context)`, so this is the
/// minimum environment they need to render.
Widget _harness({required Widget child, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ko')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

/// Triggers [UpdateDialog.show] via a button so we can exercise the dialog
/// lifecycle (barrierDismissible, PopScope, button taps) rather than just
/// the widget itself.
class _DialogTrigger extends StatelessWidget {
  const _DialogTrigger({required this.required, this.message});
  final bool required;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => UpdateDialog.show(
          context,
          required: required,
          message: message,
        ),
        child: const Text('Open dialog'),
      ),
    );
  }
}

void main() {
  group('UpdateDialog', () {
    testWidgets('optional dialog renders "Update available" title and Later',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const _DialogTrigger(required: false),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('required dialog renders "Update required" and hides Later',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const _DialogTrigger(required: true),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      // The "Later" button MUST NOT exist on a required dialog — that's
      // the whole point of the PopScope + barrierDismissible=false pair.
      expect(find.text('Later'), findsNothing);
    });

    testWidgets('uses the provided message verbatim when non-empty',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const _DialogTrigger(
          required: false,
          message: '새 기능이 추가되었어요. 업데이트해보세요!',
        ),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('새 기능이 추가되었어요. 업데이트해보세요!'),
        findsOneWidget,
      );
    });

    testWidgets('falls back to localized default when message is null',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const _DialogTrigger(required: false),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      // English default from app_en.arb
      expect(
        find.text('A new version is available. Please update for the best experience.'),
        findsOneWidget,
      );
    });

    testWidgets('Korean locale renders Korean strings', (tester) async {
      await tester.pumpWidget(_harness(
        locale: const Locale('ko'),
        child: const _DialogTrigger(required: false),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('업데이트 가능'), findsOneWidget);
      expect(find.text('나중에'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
    });

    testWidgets('tapping Later pops the optional dialog', (tester) async {
      await tester.pumpWidget(_harness(
        child: const _DialogTrigger(required: false),
      ));
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    });
  });

  group('ForceUpdateScreen', () {
    testWidgets('renders the blocking surface with update + retry controls',
        (tester) async {
      // Pass a config so the screen doesn't try to fetch on mount.
      final config = UpdateConfig.fromJson({
        'latest_version': '2.0.0',
        'minimum_version': '2.0.0',
        'force_update': true,
        'update_message_en': 'Critical security fix.',
      });

      await tester.pumpWidget(_harness(child: ForceUpdateScreen(config: config)));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Critical security fix.'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('honors the locale for the fallback body text',
        (tester) async {
      // Config without a message — should use the localized default.
      final config = UpdateConfig.fromJson({
        'latest_version': '2.0.0',
        'minimum_version': '2.0.0',
        'force_update': true,
      });

      await tester.pumpWidget(_harness(
        locale: const Locale('ko'),
        child: ForceUpdateScreen(config: config),
      ));
      await tester.pumpAndSettle();

      expect(find.text('업데이트 필요'), findsOneWidget);
      expect(
        find.text('더 나은 경험을 위해 최신 버전으로 업데이트해 주세요.'),
        findsOneWidget,
      );
    });
  });
}