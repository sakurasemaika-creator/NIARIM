import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProjectService> open({
    bool savedFolder = false,
    String folderName = 'S25',
    bool withSharedProject = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (savedFolder)
        'shared_folders': jsonEncode([
          ProjectFolder(
            id: 'saved',
            name: folderName,
            createdAt: DateTime.utc(2026),
          ).toJson(),
        ]),
    });
    final directory = Directory.systemTemp.createTempSync('shared-empty-ui-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final service = ProjectService();
    await service.init();
    if (withSharedProject) {
      final project = await service.importSharedProject(
        NiaproData(
          project: Project(
            id: 'incoming',
            name: 'Incoming',
            fps: 1,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 64,
            exportHeight: 64,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            totalWorkSeconds: 0,
          ),
          scenes: const [],
          tileData: const {},
        ),
      );
      await service.saveProject(project.id);
    }
    addTearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    return service;
  }

  Future<AppLocalizations> show(
    WidgetTester tester,
    ProjectService service,
    Locale locale,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectService>.value(value: service),
          ChangeNotifierProvider(create: (_) => PremiumService()),
        ],
        child: MaterialApp(
          key: ValueKey(locale),
          theme: ThemeService().themeData,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SharedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(SharedScreen)))!;
  }

  testWidgets('saved empty shared folder remains reachable in every locale', (
    tester,
  ) async {
    final service = await tester.runAsync(() => open(savedFolder: true));
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in [const Size(320, 844), const Size(1440, 900)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = size.width == 320
            ? 2
            : 1;
        final l10n = await show(tester, service!, locale);
        expect(service.shared, isEmpty);
        expect(find.text('S25'), findsOneWidget, reason: '$locale $size');
        final favorite = find.byType(FilterChip);
        final wasSelected = tester.widget<FilterChip>(favorite).selected;
        await tester.tap(favorite);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(favorite).selected, !wasSelected);
        expect(find.text('S25'), findsOneWidget);
        await tester.tap(find.text('S25'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.folderManagementEmpty), findsNothing);
        expect(find.text(l10n.homeSharedFolderEmpty), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('S25'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$locale $size');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first shared folder can be created, renamed and deleted', (
    tester,
  ) async {
    final service = await tester.runAsync(open);
    final l10n = await show(tester, service!, const Locale('en'));
    expect(find.text(l10n.homeSharedEmpty), findsOneWidget);
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'S25');
    await tester.pump();
    await tester.tap(find.text(l10n.commonCreate));
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(service.sharedFolders.single.name, 'S25');
    expect(find.text('S25'), findsOneWidget);
    await tester.longPress(find.text('S25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'S25 renamed');
    await tester.pump();
    await tester.tap(find.text(l10n.commonChange));
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('S25 renamed'), findsOneWidget);
    await tester.longPress(find.text('S25 renamed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(service.sharedFolders, isEmpty);
    expect(find.text(l10n.homeSharedEmpty), findsOneWidget);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(jsonDecode(prefs!.getString('shared_folders')!), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared folder full names wrap within narrow and short screens', (
    tester,
  ) async {
    const name = 'S25 shared folder / 海と空のアニメーション / Animation étude';
    final service = await tester.runAsync(
      () => open(savedFolder: true, folderName: name, withSharedProject: true),
    );
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in [
      const Size(320, 844),
      const Size(320, 220),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = size.width == 320
          ? 2
          : 1;
      await show(tester, service!, const Locale('fr'));
      expect(tester.takeException(), isNull, reason: '$size');
      final text = find.text(name);
      final target = find
          .ancestor(of: text, matching: find.byType(InkWell))
          .first;
      final rect = tester.getRect(target);
      expect(rect.width, lessThanOrEqualTo(size.width));
      expect(rect.height, greaterThanOrEqualTo(48));
      final label = tester.widget<Text>(text);
      expect(label.maxLines, isNull);
      expect(label.overflow, isNot(TextOverflow.ellipsis));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
