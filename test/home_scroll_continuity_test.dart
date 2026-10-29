import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final pc in [false, true]) {
    testWidgets(
      'large project list retains scroll across tabs and drawer in ${pc ? 'PC' : 'SP'}',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'first_launch': false,
          'language': 'ja',
          'force_pc_mode': pc ? 1 : 0,
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        });
        final directory = Directory.systemTemp.createTempSync(
          'home-continuity-',
        );
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => directory.path);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        });
        tester.view.physicalSize = pc
            ? const Size(1440, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        appRouter.go('/home');
        final providers = await tester.runAsync(buildAppProviders);
        await tester.pumpWidget(
          MultiProvider(providers: providers!, child: const NiarimApp()),
        );
        await tester.pumpAndSettle();
        final service = tester
            .element(find.byType(ProjectListWidget))
            .read<ProjectService>();
        await tester.runAsync(() async {
          for (var index = 0; index < 120; index++) {
            await service.createProject(
              name:
                  'A003 ${index.toString().padLeft(3, '0')} 海と空のアニメーション / Animation étude',
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 32,
              exportHeight: 32,
            );
          }
          final exportRoot = Platform.environment['NIARIM_AUDIT_SEED'];
          if (!pc && exportRoot != null) {
            final target = Directory(exportRoot);
            expect(
              target.existsSync(),
              isFalse,
              reason: 'fixture export must use a fresh isolated directory',
            );
            target.createSync(recursive: true);
            for (final entity in directory.listSync(recursive: true)) {
              final relative = entity.path.substring(directory.path.length + 1);
              final destination = '${target.path}/$relative';
              if (entity is Directory) {
                Directory(destination).createSync(recursive: true);
              }
              if (entity is File) entity.copySync(destination);
            }
          }
        });
        await tester.pumpAndSettle();
        expect(service.projects.length, 120);
        final list = find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(list, const Offset(0, -1200));
        await tester.pumpAndSettle();
        double position() =>
            tester.state<ScrollableState>(list).position.pixels;
        final before = position();
        expect(before, greaterThan(300));
        for (final index in [2, 0]) {
          final tab = find.byKey(ValueKey('home_tab_$index'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();
        }
        expect(
          position(),
          closeTo(before, .1),
          reason: 'return to the same project list position',
        );
        final scaffold = tester.state<ScaffoldState>(
          find.byType(Scaffold).first,
        );
        scaffold.openEndDrawer();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: find.byType(Drawer), matching: find.text('設定')),
        );
        await tester.pumpAndSettle();
        appRouter.pop();
        await tester.pumpAndSettle();
        expect(
          position(),
          closeTo(before, .1),
          reason: 'drawer destination returns to the same list position',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
