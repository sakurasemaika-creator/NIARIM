import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/project_folder_edit_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/folder_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'folder name/color error remains readable at every audit width and locale; one acknowledged retry closes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      addTearDown(themes.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const widths = <double>[
        320,
        360,
        375,
        390,
        430,
        480,
        520,
        559,
        560,
        600,
        640,
        641,
        700,
        759,
        760,
        834,
        900,
        1024,
        1180,
        1280,
        1366,
        1440,
        1600,
        1920,
      ];
      var inspected = 0;
      for (final locale in AppLocalizations.supportedLocales) {
        tester.view.physicalSize = const Size(390, 844);
        var calls = 0;
        Completer<void>? pending;
        String? submittedName;
        int? submittedColor;
        await tester.pumpWidget(
          MaterialApp(
            theme: themes.themeData,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('OPEN'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ProjectFolderEditDialog(
                      folder: ProjectFolder(id: 'audit', name: 'ORIGINAL'),
                      onSave: (name, color) async {
                        calls++;
                        submittedName = name;
                        submittedColor = color;
                        if (pending == null) {
                          throw const FolderSaveException(
                            partiallySaved: false,
                          );
                        }
                        await pending.future;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProjectFolderEditDialog)),
        )!;
        await tester.enterText(find.byType(TextField), 'RETAIN ME');
        final color = find.byTooltip(
          '${l10n.projectListFolderColorLabel}: #FF5C7A',
        );
        await tester.ensureVisible(color);
        await tester.tap(color);
        final save = find.widgetWithText(FilledButton, l10n.commonSave);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(calls, 1);
        final error = find.text(l10n.folderChangesSaveFailed);
        for (final size in [
          ...widths.map((w) => Size(w, w >= 640 ? 900 : 844)),
          const Size(320, 220),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(error, findsOneWidget);
          expect(tester.widget<Text>(error).maxLines, isNull);
          expect(
            tester.widget<Text>(error).overflow,
            isNot(TextOverflow.ellipsis),
          );
          for (final control in [
            error,
            find.byType(TextField),
            color,
            save,
            find.text(l10n.commonCancel),
          ]) {
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(control).overlaps(Offset.zero & size),
              isTrue,
              reason: '$locale/$size',
            );
            expect(tester.getRect(control).left, greaterThanOrEqualTo(0));
            expect(
              tester.getRect(control).right,
              lessThanOrEqualTo(size.width),
            );
          }
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'RETAIN ME',
          );
          expect(tester.takeException(), isNull, reason: '$locale/$size');
          inspected++;
        }
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        pending = Completer<void>();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pump();
        expect(calls, 2);
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ProjectFolderEditDialog), findsNothing);
        expect(submittedName, 'RETAIN ME');
        expect(submittedColor, 0xFFFF5C7A);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(inspected, 175);
    },
  );
}
