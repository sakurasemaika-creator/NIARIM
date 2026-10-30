import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('retry clears the previous failure while awaiting real work', (
    tester,
  ) async {
    final retry = Completer<void>();
    final results = <bool>[];
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await runProjectTrashAction(context, () async {
                    calls++;
                    if (calls == 1) throw StateError('storage rejected');
                    await retry.future;
                  }),
                );
              },
              child: const Text('RESTORE'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('RESTORE'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('RESTORE'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(results, [false]);
    retry.complete();
    await tester.pumpAndSettle();
    expect(results, [false, true]);
    expect(find.byType(SnackBar), findsNothing);
  });

  const target =
      'LONG TARGET / 日本語 Français / a named project that must remain fully identifiable before permanent deletion';
  Future<void> host(
    WidgetTester tester, {
    required Future<void> Function() apply,
    Locale locale = const Locale('en'),
    double scale = 1,
    Size size = const Size(390, 844),
    ValueChanged<bool?>? result,
    List<String> Function()? pendingNames,
    String Function()? pendingMessage,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    theme.previewCurrent(
      AppThemePreset.defaultLight.copyWith(
        accentColor: const Color(0xFF8A2040),
        buttonTextColor: const Color(0xFFFFE8B0),
      ),
    );
    addTearDown(theme.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey((locale, scale, size)),
        theme: theme.themeData,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return TextButton(
                key: const Key('open-trash-dialog'),
                child: const Text('OPEN'),
                onPressed: () async {
                  final answer = await showDialog<bool>(
                    context: context,
                    builder: (_) => ProjectTrashDialog(
                      title: l10n.homePermanentDeleteConfirmTitle,
                      message: l10n.homePermanentDeleteConfirmBody,
                      confirmLabel: l10n.commonDelete,
                      itemNames: const [target],
                      pendingItemNames: pendingNames,
                      pendingMessage: pendingMessage,
                      onApply: apply,
                    ),
                  );
                  result?.call(answer);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-trash-dialog')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'all locales keep the complete target and 48px reachable cancel/confirm',
    (tester) async {
      var calls = 0;
      for (final locale in AppLocalizations.supportedLocales) {
        for (final profile in [
          (const Size(320, 844), 1.0),
          (const Size(320, 220), 2.0),
          (const Size(600, 360), 1.3),
          (const Size(1440, 900), 2.0),
        ]) {
          bool? answer;
          await host(
            tester,
            locale: locale,
            size: profile.$1,
            scale: profile.$2,
            apply: () async {
              calls++;
            },
            result: (value) => answer = value,
          );
          final text = tester.renderObject<RenderParagraph>(
            find.byKey(const Key('trash-dialog-target-0')),
          );
          expect(text.text.toPlainText(), target);
          expect(text.didExceedMaxLines, isFalse);
          expect(text.size.width, greaterThan(0));
          for (final key in ['trash-dialog-confirm', 'trash-dialog-cancel']) {
            final button = find.byKey(Key(key));
            expect(
              button.hitTestable(),
              findsOneWidget,
              reason: '$locale/$profile/$key',
            );
            expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          }
          final confirm = tester.widget<FilledButton>(
            find.byKey(const Key('trash-dialog-confirm')),
          );
          expect(
            confirm.style!.backgroundColor!.resolve({}),
            const Color(0xFF8A2040),
          );
          expect(
            confirm.style!.foregroundColor!.resolve({}),
            const Color(0xFFFFE8B0),
          );
          await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
          await tester.pumpAndSettle();
          expect(answer, isFalse);
          expect(calls, 0);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'awaits work, blocks dismissal, retains failure and retries the same target',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      bool? answer;
      await host(
        tester,
        apply: () async {
          calls++;
          if (calls == 1) await gate.future;
        },
        result: (value) => answer = value,
      );
      final confirm = find.byKey(const Key('trash-dialog-confirm'));
      final cancel = find.byKey(const Key('trash-dialog-cancel'));
      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(tester.widget<TextButton>(cancel).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(ProjectTrashDialog), findsOneWidget);
      expect(calls, 1);
      expect(answer, isNull);
      gate.completeError(StateError('controlled failure'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trash-dialog-error')), findsOneWidget);
      expect(find.text(target), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(answer, isTrue);
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('route disposal during failed work has no stale update', (
    tester,
  ) async {
    final gate = Completer<void>();
    await host(tester, apply: () => gate.future);
    await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    gate.completeError(StateError('controlled disposed operation'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial success identifies only the remaining targets on retry',
    (tester) async {
      final remaining = ['FIRST', 'SECOND'];
      var calls = 0;
      await host(
        tester,
        pendingNames: () => List.of(remaining),
        pendingMessage: () => 'COUNT ${remaining.length}',
        apply: () async {
          calls++;
          if (calls == 1) {
            remaining.removeAt(0);
            throw StateError('second target rejected');
          }
          remaining.clear();
        },
      );
      expect(find.text('COUNT 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsNothing);
      expect(find.text('SECOND'), findsOneWidget);
      expect(find.text('COUNT 1'), findsOneWidget);
      expect(find.byKey(const Key('trash-dialog-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(remaining, isEmpty);
      expect(find.byType(ProjectTrashDialog), findsNothing);
    },
  );

  testWidgets(
    'short expanded dialog reveals failure without manual scrolling',
    (tester) async {
      await host(
        tester,
        locale: const Locale('fr'),
        size: const Size(320, 220),
        scale: 2,
        apply: () async => throw StateError('storage rejected'),
      );
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      await tester.pumpAndSettle();
      final error = find.byKey(const Key('trash-dialog-error'));
      final viewport = tester.getRect(
        find
            .ancestor(of: error, matching: find.byType(SingleChildScrollView))
            .first,
      );
      final message = tester.getRect(error);
      expect(message.top, greaterThanOrEqualTo(viewport.top - 1));
      expect(message.top, lessThan(viewport.bottom - 20));
      for (final key in ['trash-dialog-confirm', 'trash-dialog-cancel']) {
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
