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
import 'package:niarim/services/project_service.dart' show ProjectFolder;
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontsLoaded = false;
  Future<({AppLocalizations l10n, WorkFolderService folders})> open(
    WidgetTester tester, {
    String language = 'en',
    bool pc = false,
    double? width,
    double height = 844,
    bool libraryHasFile = true,
    bool seedFolder = true,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      if (seedFolder)
        'work_folders': jsonEncode([
          ProjectFolder(
            id: 'audit-folder',
            name: 'AUDIT',
            createdAt: DateTime.utc(2026, 10, 27),
          ).toJson(),
        ]),
    });
    final dir = Directory.systemTemp.createTempSync('work-folder-empty-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    final exports = Directory('${dir.path}/exports')..createSync();
    if (libraryHasFile) {
      File('${exports.path}/AUDIT_root.gif').writeAsBytesSync(
        base64Decode(
          'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        ),
      );
    }
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = Size(width ?? (pc ? 1440 : 320), height);
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
    final folders = context.read<WorkFolderService>();
    final tab = find.byKey(const ValueKey('home_tab_1'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    return (l10n: l10n, folders: folders);
  }

  testWidgets('an existing empty Works folder never claims no folders exist', (
    tester,
  ) async {
    final env = await open(tester);
    await tester.tap(find.text('AUDIT'));
    await tester.pumpAndSettle();
    expect(
      find.text(env.l10n.folderManagementEmpty),
      findsNothing,
      reason: 'The folder exists; only its exported works are empty',
    );
    expect(find.text(env.l10n.homeWorkFolderEmpty), findsOneWidget);
  });

  testWidgets(
    'a newly created folder remains reachable with zero exported files',
    (tester) async {
      final env = await open(tester, libraryHasFile: false, seedFolder: false);
      await env.folders.createFolder('AUDIT');
      await tester.pumpAndSettle();
      expect(
        find.text('AUDIT'),
        findsOneWidget,
        reason:
            'Successful folder creation must show the folder even before the first export',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty folders stay usable in every locale, mode and compact height',
    (tester) async {
      var profiles = 0;
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
      for (final language in ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es']) {
        for (final pc in [false, true]) {
          for (final (width, height) in [
            for (final width in widths) (width, pc ? 900.0 : 844.0),
            (320.0, 220.0),
          ]) {
            final env = await open(
              tester,
              language: language,
              pc: pc,
              width: width,
              height: height,
              libraryHasFile: false,
              seedFolder: false,
            );
            expect(find.text(env.l10n.homeWorksEmpty), findsOneWidget);
            await env.folders.createFolder('AUDIT');
            await tester.pumpAndSettle();
            final folder = find.text('AUDIT');
            await tester.ensureVisible(folder);
            await tester.tap(folder);
            await tester.pumpAndSettle();
            final message = find.text(env.l10n.homeWorkFolderEmpty);
            await tester.ensureVisible(message);
            await tester.pumpAndSettle();
            expect(find.text(env.l10n.folderManagementEmpty), findsNothing);
            expect(
              tester.renderObject<RenderParagraph>(message).didExceedMaxLines,
              isFalse,
            );
            expect(
              tester.getCenter(find.byIcon(Icons.folder_open_outlined)).dx,
              closeTo(width / 2, 0.1),
              reason: 'Empty folder content must stay centered at $width px',
            );
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            expect(find.text('AUDIT'), findsOneWidget);
            expect(env.folders.folders.single.name, 'AUDIT');
            expect(
              tester.takeException(),
              isNull,
              reason: '$language/$pc/$width/$height',
            );
            profiles++;
          }
        }
      }
      expect(profiles, 350);
    },
  );

  testWidgets(
    'moving a real export into a folder then deleting it preserves the empty folder',
    (tester) async {
      final env = await open(tester);
      await tester.tap(find.text('AUDIT'));
      await tester.pumpAndSettle();
      expect(find.text(env.l10n.homeWorkFolderEmpty), findsOneWidget);
      await env.folders.moveFileToFolder('AUDIT_root.gif', 'audit-folder');
      await tester.pumpAndSettle();
      expect(find.text('AUDIT_root.gif'), findsOneWidget);
      expect(find.text(env.l10n.homeWorkFolderEmpty), findsNothing);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, env.l10n.commonDelete);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.runAsync(
        () => ExportEngine.listExportedFiles(forceRefresh: true),
      );
      await tester.pumpAndSettle();
      final exports = await tester.runAsync(ExportEngine.exportsDir);
      expect(File('${exports!.path}/AUDIT_root.gif').existsSync(), isFalse);
      expect(find.text(env.l10n.homeWorkFolderEmpty), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('AUDIT'), findsOneWidget);
      expect(find.text(env.l10n.homeWorksEmpty), findsOneWidget);
      expect(env.folders.folders, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exports inside folders are not described as an empty library', (
    tester,
  ) async {
    final env = await open(tester);
    await env.folders.moveFileToFolder('AUDIT_root.gif', 'audit-folder');
    await tester.pumpAndSettle();
    expect(find.byType(ExportedWorkCard), findsNothing);
    expect(find.text(env.l10n.homeWorksEmpty), findsNothing);
    await tester.tap(find.text('AUDIT'));
    await tester.pumpAndSettle();
    expect(find.text('AUDIT_root.gif'), findsOneWidget);
    expect(find.text(env.l10n.homeWorkFolderEmpty), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('multiple empty folders remain reachable in a compact library', (
    tester,
  ) async {
    final env = await open(
      tester,
      height: 220,
      libraryHasFile: false,
      seedFolder: false,
    );
    for (var i = 1; i <= 3; i++) {
      await env.folders.createFolder('AUDIT $i');
    }
    await tester.pumpAndSettle();
    for (var i = 1; i <= 3; i++) {
      final folder = find.text('AUDIT $i');
      await tester.ensureVisible(folder);
      await tester.pumpAndSettle();
      await tester.tap(folder);
      await tester.pumpAndSettle();
      expect(find.text(env.l10n.homeWorkFolderEmpty), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    expect(env.folders.folders, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty-library folder rename and delete cancellation retain the correct state',
    (tester) async {
      final env = await open(tester, libraryHasFile: false);
      await tester.longPress(find.text('AUDIT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonRename));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'RENAMED');
      await tester.tap(find.text(env.l10n.commonChange));
      await tester.pumpAndSettle();
      expect(find.text('RENAMED'), findsOneWidget);
      await tester.longPress(find.text('RENAMED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(env.folders.folders.single.name, 'RENAMED');
      expect(find.text('RENAMED'), findsOneWidget);
      await tester.longPress(find.text('RENAMED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(env.l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, env.l10n.commonDelete),
      );
      await tester.pumpAndSettle();
      expect(env.folders.folders, isEmpty);
      expect(find.text('RENAMED'), findsNothing);
      expect(find.text(env.l10n.homeWorksEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
