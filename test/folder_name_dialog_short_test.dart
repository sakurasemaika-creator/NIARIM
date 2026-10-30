import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'folder input and Create remain reachable with large text and keyboard in every locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final created = <String>[];
      for (final locale in AppLocalizations.supportedLocales) {
        for (final size in [const Size(320, 220), const Size(390, 844)]) {
          tester.view.physicalSize = size;
          final keyboard = size.height == 220 ? 64.0 : 300.0;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.themeData,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showCreateFolderNameDialog(context, (name) async {
                          created.add(name);
                        }),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          final rect = tester.getRect(field);
          expect(rect.top, greaterThanOrEqualTo(16));
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - keyboard - 16),
            reason: '$locale/$size name field is clipped',
          );
          await tester.tap(field);
          await tester.enterText(field, '  海と空 Épisode 01  ');
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(tester.element(field))!;
          final create = find.widgetWithText(FilledButton, l10n.commonCreate);
          await tester.ensureVisible(create);
          await tester.pumpAndSettle();
          await tester.tap(create);
          await tester.pumpAndSettle();
          expect(created.last, '海と空 Épisode 01');
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
      expect(created.length, 14);
    },
  );

  testWidgets(
    'folder creation prevents duplicate submission and retains the name after failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      final pending = Completer<void>();
      final names = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.themeData,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCreateFolderNameDialog(context, (name) {
                  names.add(name);
                  return names.length == 1
                      ? pending.future
                      : Future<void>.value();
                }),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final l10n = AppLocalizations.of(tester.element(field))!;
      final create = find.widgetWithText(FilledButton, l10n.commonCreate);
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.enterText(field, '  Series 01  ');
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pump();
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.tap(create);
      await tester.pump();
      expect(names, ['Series 01']);
      pending.completeError(StateError('AUDIT folder save failure'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(l10n.folderCreateFailed), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '  Series 01  ');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(names, ['Series 01', 'Series 01']);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a pending folder dialog does not pop the underlying route on completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.themeData,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showCreateFolderNameDialog(context, (_) => pending.future),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final l10n = AppLocalizations.of(tester.element(field))!;
      await tester.enterText(field, 'Pending');
      await tester.pump();
      await tester.tap(find.text(l10n.commonCreate));
      await tester.pump();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
