// 選択ツールの「自由変形」「メッシュ変形」は、選択範囲が無ければレイヤー全体を
// 変形する（設定/編集メニューの「自由変形・メッシュ変形」と同じ）。
//
// 実際に使ってみたとき（2026-11-27）、選択範囲が無いまま押すと、つまみもメッシュも
// 出ず何もできなかった（選択範囲の中だけを変形する指定のまま開いていた）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('niarim_selection_whole_');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => docs.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  for (final mesh in [false, true]) {
    testWidgets('${mesh ? 'mesh' : 'free'} transform with no selection '
        'transforms the whole layer', (tester) async {
      tester.view.physicalSize = const Size(960, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      ProjectService? projects;
      StateSetter? rebuild;
      String? projectId;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (themeContext) => MaterialApp(
              theme: themeContext.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StatefulBuilder(
                builder: (context, setState) {
                  projects ??= context.read<ProjectService>();
                  rebuild = setState;
                  if (projectId == null) return const SizedBox.expand();
                  return CanvasScreen(projectId: projectId);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final project = (await tester.runAsync(
        () => projects!.createProject(
          name: 'whole layer',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 320,
        ),
      ))!;
      projectId = project.id;
      rebuild!(() {});
      await tester.pump(const Duration(milliseconds: 1400));
      final l10n = lookupAppLocalizations(const Locale('ja'));

      final selectTool = find.byIcon(Icons.highlight_alt);
      await tester.ensureVisible(selectTool.first);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(selectTool.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.text(
          mesh
              ? l10n.canvasSelectionMeshTransform
              : l10n.canvasSelectionFreeTransform,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      final area = tester.widget<CanvasArea>(find.byType(CanvasArea));
      expect(area.currentTool, DrawingTool.meshTransform);
      expect(area.meshSelectionOnly, isFalse);
      final state = tester.state(find.byType(CanvasArea)) as dynamic;
      expect(
        state.meshControlPoints,
        isNotNull,
        reason: 'the handles (control points) are there to drag',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
