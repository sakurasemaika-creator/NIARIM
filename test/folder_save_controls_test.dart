import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/folder_delete_dialog.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/home/widgets/work_folder_move_sheet.dart';
import 'package:niarim/services/project_service.dart' show ProjectFolder;
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  var fontsLoaded = false;
  late GlobalKey<NavigatorState> navigator;
  Future<AppLocalizations> open(
    WidgetTester tester,
    WidgetBuilder modal, {
    bool sheet = false,
    void Function(BuildContext context)? onOpen,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    navigator = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: theme.themeData,
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('LANDING'),
                FilledButton(
                  onPressed: () {
                    if (onOpen != null) {
                      onOpen(context);
                    } else if (sheet) {
                      showModalBottomSheet(context: context, builder: modal);
                    } else {
                      showDialog(context: context, builder: modal);
                    }
                  },
                  child: const Text('OPEN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('OPEN')))!;
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('rename busy target stays still and preserves rejected input', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    final l10n = await open(
      tester,
      (_) => const SizedBox.shrink(),
      onOpen: (context) {
        showRenameFolderNameDialog(context, 'AUDIT', (name) {
          expect(name, '海と空_étude');
          calls++;
          return gate.future;
        });
      },
    );
    await tester.enterText(find.byType(TextField), '海と空_étude');
    final button = find.widgetWithText(FilledButton, l10n.commonChange);
    await tester.ensureVisible(button);
    final before = tester.getRect(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(button), before);
    await tester.tap(button, warnIfMissed: false);
    expect(calls, 1);
    gate.completeError(const WorkFolderSaveException(partiallySaved: false));
    await tester.pumpAndSettle();
    expect(find.text(l10n.folderChangesSaveFailed), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '海と空_étude',
    );
    await tester.ensureVisible(find.text(l10n.commonCancel));
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.text('LANDING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'move busy target stays still and closing before ${fail ? 'failure' : 'success'} is safe',
      (tester) async {
        final gate = Completer<void>();
        var calls = 0;
        final folder = ProjectFolder(
          id: 'audit',
          name: '海と空_Animation_étude_애니메이션',
          createdAt: DateTime.utc(2026, 10, 28),
        );
        const filename = 'AUDIT_海と空_動畫.gif';
        await open(
          tester,
          (_) => WorkFolderMoveSheet(
            filename: filename,
            folders: [folder],
            onMove: (_) {
              calls++;
              return gate.future;
            },
          ),
          sheet: true,
        );
        final target = find.widgetWithText(ListTile, folder.name);
        await tester.ensureVisible(target);
        final before = tester.getRect(target);
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSemantics(find.byType(WorkFolderMoveSheet)).label,
            contains(filename),
          );
        } finally {
          semantics.dispose();
        }
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(target), before);
        expect(tester.widget<ListTile>(target).onTap, isNull);
        expect(calls, 1);
        await tester.tap(target, warnIfMissed: false);
        await tester.pump();
        expect(calls, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(WorkFolderMoveSheet), findsNothing);
        if (fail) {
          gate.completeError(
            const WorkFolderSaveException(partiallySaved: false),
          );
        } else {
          gate.complete();
        }
        await tester.pumpAndSettle();
        expect(find.text('LANDING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'delete stays in place, prevents duplicate submissions and retries its error',
    (tester) async {
      var gate = Completer<void>();
      var calls = 0;
      final l10n = await open(
        tester,
        (_) => FolderDeleteDialog(
          folderName: 'AUDIT',
          onDelete: () {
            calls++;
            return gate.future;
          },
        ),
      );
      final confirm = find.widgetWithText(FilledButton, l10n.commonDelete);
      final before = tester.getRect(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(confirm), before);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, l10n.commonCancel),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(confirm, warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FolderDeleteDialog), findsOneWidget);
      expect(calls, 1);
      gate.completeError(const WorkFolderSaveException(partiallySaved: true));
      await tester.pumpAndSettle();
      expect(find.text(l10n.folderChangesPartiallySaved), findsOneWidget);
      gate = Completer<void>();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(calls, 2);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FolderDeleteDialog), findsNothing);
      expect(find.text('LANDING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an accepted save closes only its own modal beneath another route',
    (tester) async {
      final gate = Completer<void>();
      final l10n = await open(
        tester,
        (_) => FolderDeleteDialog(
          folderName: 'AUDIT',
          onDelete: () => gate.future,
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('NEXT')),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('NEXT'), findsOneWidget);
      expect(
        find.byType(FolderDeleteDialog, skipOffstage: false),
        findsNothing,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('LANDING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
