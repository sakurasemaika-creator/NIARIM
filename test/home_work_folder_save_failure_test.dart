import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/folder_delete_dialog.dart';
import 'package:niarim/screens/home/widgets/work_folder_move_sheet.dart';
import 'package:niarim/services/project_service.dart' show ProjectFolder;
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/controlled_preferences_store.dart';
import 'helpers/exported_work_name.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontsLoaded = false;
  const filename = 'AUDIT_keep.gif';
  Future<
    ({
      AppLocalizations l10n,
      WorkFolderService folders,
      ControlledPreferencesStore store,
      File file,
    })
  >
  open(WidgetTester tester, {String language = 'en', bool pc = false}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    SharedPreferences.resetStatic();
    final previousStore = SharedPreferencesStorePlatform.instance;
    final initial = <String, Object>{
      'first_launch': false,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'work_folders': jsonEncode([
        ProjectFolder(
          id: 'audit-folder',
          name: 'AUDIT',
          createdAt: DateTime.utc(2026, 10, 28),
        ).toJson(),
      ]),
      'work_file_folder_map': '{}',
    };
    final store = ControlledPreferencesStore({
      for (final e in initial.entries) 'flutter.${e.key}': e.value,
    });
    SharedPreferencesStorePlatform.instance = store;
    final dir = Directory.systemTemp.createTempSync('work-folder-save-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previousStore;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/exports/$filename');
    file.parent.createSync();
    file.writeAsBytesSync(
      base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'),
    );
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = Size(pc ? 1440 : 320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(l10n.localeName, language);
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await tester.pumpAndSettle();
    return (
      l10n: l10n,
      folders: context.read<WorkFolderService>(),
      store: store,
      file: file,
    );
  }

  testWidgets(
    'failed move, rename and partial delete remain reachable across all widths, locales and modes',
    (tester) async {
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
      var conditions = 0;
      Future<void> inspect(
        Finder error,
        List<Finder> controls,
        String profile,
      ) async {
        expect(error, findsOneWidget, reason: profile);
        final text = tester.widget<Text>(error);
        expect(text.maxLines, isNull, reason: profile);
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: profile);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        final size = tester.view.physicalSize;
        final viewport = Offset.zero & size;
        expect(
          tester.getRect(error).overlaps(viewport),
          isTrue,
          reason: profile,
        );
        for (final control in controls) {
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          final rect = tester.getRect(control);
          expect(rect.width, greaterThanOrEqualTo(48), reason: profile);
          expect(rect.height, greaterThanOrEqualTo(48), reason: profile);
          expect(rect.left, greaterThanOrEqualTo(0), reason: profile);
          expect(rect.right, lessThanOrEqualTo(size.width), reason: profile);
          expect(rect.overlaps(viewport), isTrue, reason: profile);
        }
        expect(tester.takeException(), isNull, reason: profile);
        conditions++;
      }

      for (final language in ['ja', 'en', 'fr', 'es', 'zh', 'zh_Hant', 'ko']) {
        for (final pc in [false, true]) {
          final env = await open(tester, language: language, pc: pc);
          final original = env.file.readAsBytesSync();
          final sizes = [
            for (final width in widths) Size(width, pc ? 900 : 844),
            const Size(320, 220),
          ];
          env.store.failWrites = true;
          final move = find.byTooltip(
            '${env.l10n.folderMoveToTitle}: $filename',
          );
          await tester.ensureVisible(move);
          await tester.tap(move);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'AUDIT'));
          await tester.pumpAndSettle();
          for (final size in sizes) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            await inspect(find.text(env.l10n.folderChangesSaveFailed), [
              find.widgetWithText(ListTile, env.l10n.folderNone),
              find.widgetWithText(ListTile, 'AUDIT'),
            ], 'move/$language/$pc/$size');
            expect(env.folders.folderIdOf(filename), isNull);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          tester.view.physicalSize = Size(pc ? 1440 : 320, 844);
          await tester.pumpAndSettle();
          await tester.longPress(find.text('AUDIT'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(env.l10n.commonRename));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '海と空_étude_애니메이션');
          final change = find.widgetWithText(
            FilledButton,
            env.l10n.commonChange,
          );
          await tester.ensureVisible(change);
          await tester.tap(change);
          await tester.pumpAndSettle();
          for (final size in sizes) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            await inspect(find.text(env.l10n.folderChangesSaveFailed), [
              find.widgetWithText(TextButton, env.l10n.commonCancel),
              change,
            ], 'rename/$language/$pc/$size');
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              '海と空_étude_애니메이션',
            );
            expect(env.folders.folders.single.name, 'AUDIT');
          }
          await tester.ensureVisible(find.text(env.l10n.commonCancel));
          await tester.tap(find.text(env.l10n.commonCancel));
          await tester.pumpAndSettle();
          tester.view.physicalSize = Size(pc ? 1440 : 320, 844);
          await tester.pumpAndSettle();
          env.store.failWrites = false;
          await env.folders.moveFileToFolder(filename, 'audit-folder');
          await tester.pumpAndSettle();
          env.store.reject = (key, value) =>
              (key == 'flutter.work_folders' && value == '[]') ||
              (key == 'flutter.work_file_folder_map' &&
                  value is String &&
                  (jsonDecode(value) as Map).isNotEmpty);
          await tester.longPress(find.text('AUDIT'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(env.l10n.commonDelete));
          await tester.pumpAndSettle();
          final confirm = find.widgetWithText(
            FilledButton,
            env.l10n.commonDelete,
          );
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          for (final size in sizes) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            await inspect(find.text(env.l10n.folderChangesPartiallySaved), [
              find.widgetWithText(TextButton, env.l10n.commonCancel),
              confirm,
            ], 'partial-delete/$language/$pc/$size');
            expect(env.folders.folders.single.name, 'AUDIT');
            expect(env.folders.folderIdOf(filename), isNull);
          }
          expect(env.file.readAsBytesSync(), original);
        }
      }
      expect(conditions, 1050);
    },
  );

  testWidgets(
    'real Works move and rename retain their controls and retry in seven locales and both modes',
    (tester) async {
      var profiles = 0;
      for (final language in ['ja', 'en', 'fr', 'es', 'zh', 'zh_Hant', 'ko']) {
        for (final pc in [false, true]) {
          final env = await open(tester, language: language, pc: pc);
          final original = env.file.readAsBytesSync();
          env.store.failWrites = true;
          final move = find.byTooltip(
            '${env.l10n.folderMoveToTitle}: $filename',
          );
          await tester.ensureVisible(move);
          await tester.tap(move);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'AUDIT'));
          await tester.pumpAndSettle();
          final error = find.text(env.l10n.folderChangesSaveFailed);
          expect(error, findsOneWidget);
          expect(find.byType(WorkFolderMoveSheet), findsOneWidget);
          expect(env.folders.folderIdOf(filename), isNull);
          expect(env.file.readAsBytesSync(), original);
          for (final tile in tester.widgetList<ListTile>(
            find.descendant(
              of: find.byType(WorkFolderMoveSheet),
              matching: find.byType(ListTile),
            ),
          )) {
            expect(
              tester.getSize(find.byWidget(tile)).height,
              greaterThanOrEqualTo(48),
            );
          }
          env.store.failWrites = false;
          final destination = find.widgetWithText(ListTile, 'AUDIT');
          await tester.ensureVisible(destination);
          await tester.tap(destination);
          await tester.pumpAndSettle();
          expect(find.byType(WorkFolderMoveSheet), findsNothing);
          expect(env.folders.folderIdOf(filename), 'audit-folder');
          await tester.longPress(find.text('AUDIT'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(env.l10n.commonRename));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'RENAMED');
          env.store.failWrites = true;
          final change = find.widgetWithText(
            FilledButton,
            env.l10n.commonChange,
          );
          await tester.ensureVisible(change);
          await tester.tap(change);
          await tester.pumpAndSettle();
          expect(find.text(env.l10n.folderChangesSaveFailed), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'RENAMED',
          );
          expect(env.folders.folders.single.name, 'AUDIT');
          env.store.failWrites = false;
          await tester.ensureVisible(change);
          await tester.tap(change);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          expect(env.folders.folders.single.name, 'RENAMED');
          expect(find.text('RENAMED'), findsOneWidget);
          expect(env.file.readAsBytesSync(), original);
          expect(tester.takeException(), isNull, reason: '$language/$pc');
          profiles++;
        }
      }
      expect(profiles, 14);
    },
  );

  testWidgets(
    'partial delete explains its persisted result and supports cancel and retry at 220px',
    (tester) async {
      final env = await open(tester, language: 'fr');
      final original = env.file.readAsBytesSync();
      await env.folders.moveFileToFolder(filename, 'audit-folder');
      await tester.pumpAndSettle();
      env.store.reject = (key, value) =>
          (key == 'flutter.work_folders' && value == '[]') ||
          (key == 'flutter.work_file_folder_map' &&
              value is String &&
              (jsonDecode(value) as Map).isNotEmpty);
      await tester.longPress(find.text('AUDIT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonDelete));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 220);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, env.l10n.commonDelete);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final error = find.text(env.l10n.folderChangesPartiallySaved);
      expect(error, findsOneWidget);
      expect(
        tester.getRect(error).overlaps(const Rect.fromLTWH(0, 0, 320, 220)),
        isTrue,
        reason: 'Failure feedback must be brought into the short viewport',
      );
      expect(env.folders.folders.single.name, 'AUDIT');
      expect(env.folders.folderIdOf(filename), isNull);
      expect(env.file.readAsBytesSync(), original);
      final cancel = find.widgetWithText(TextButton, env.l10n.commonCancel);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(FolderDeleteDialog), findsNothing);
      tester.view.physicalSize = const Size(320, 844);
      await tester.pumpAndSettle();
      expect(findExportedWorkName(filename), findsOneWidget);
      env.store.reject = null;
      await tester.longPress(find.text('AUDIT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, env.l10n.commonDelete),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FolderDeleteDialog), findsNothing);
      expect(env.folders.folders, isEmpty);
      expect(findExportedWorkName(filename), findsOneWidget);
      expect(env.file.readAsBytesSync(), original);
      expect(tester.takeException(), isNull);
    },
  );
}
