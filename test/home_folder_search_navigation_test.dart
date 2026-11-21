import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pc in [false, true]) {
    testWidgets(
      'opening a folder result shows its contents in ${pc ? 'PC' : 'SP'}',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'first_launch': false,
          'language': 'en',
          'force_pc_mode': pc ? 1 : 0,
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        });
        final dir = Directory.systemTemp.createTempSync('home-folder-search-');
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = pc
            ? const Size(1440, 900)
            : const Size(390, 844);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          messenger.setMockMethodCallHandler(channel, null);
          dir.deleteSync(recursive: true);
        });

        appRouter.go('/home');
        final providers = await tester.runAsync(buildAppProviders);
        await tester.pumpWidget(
          MultiProvider(providers: providers!, child: const NiarimApp()),
        );
        await tester.pumpAndSettle();
        final home = tester.element(find.byType(HomeScreen));
        final service = home.read<ProjectService>();
        final l10n = AppLocalizations.of(home)!;
        const parentName = 'Harbor Archive';
        const childName = 'Storyboard';
        const projectName = 'Storyboard take';
        const rootName = 'Other draft';
        await tester.runAsync(() async {
          final parent = await service.createFolder(parentName);
          await service.createFolder(childName, parentFolderId: parent.id);
          final project = await service.createProject(
            name: projectName,
            fps: 1,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 32,
            exportHeight: 18,
          );
          await service.moveToFolder(project.id, parent.id);
          await service.createFolder(rootName);
        });
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(l10n.commonSearch));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), parentName);
        await tester.pumpAndSettle();
        expect(find.text(childName), findsNothing);
        expect(find.text(projectName), findsNothing);
        final folder = find.ancestor(
          of: find.text(parentName),
          matching: find.byType(Card),
        );
        expect(folder.hitTestable(), findsOneWidget);
        await tester.tap(
          find
              .descendant(of: folder, matching: find.text(parentName))
              .hitTestable(),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNothing);
        expect(find.text(childName), findsOneWidget);
        expect(find.text(projectName), findsOneWidget);
        expect(find.text(rootName), findsNothing);
        expect(
          find.byTooltip(l10n.projectListFolderRootOption),
          findsOneWidget,
        );
        expect(find.text(parentName), findsOneWidget);

        await tester.tap(find.byTooltip(l10n.commonSearch));
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.focusNode.hasPrimaryFocus, isTrue);
        expect(editable.controller.text, isEmpty);
        await tester.tap(find.byTooltip(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(find.text(childName), findsOneWidget);
        expect(find.text(projectName), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
