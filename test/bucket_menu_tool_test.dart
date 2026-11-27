// バケツの長押しのシートで塗り方（ベタ塗り・トーン）を選ぶと、そのバケツに持ち
// 替える。トーンで塗る間はツールバーの印もトーンにする。
//
// 実際に使ってみたとき（2026-11-27）、シートで選んでも塗り方が変わるだけで
// ツールは前のままで、印もベタ塗りのままだったので、気づかずにトーンで塗った。
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
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/screens/canvas/widgets/tone_fill_grid.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('niarim_bucket_menu_');
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

  testWidgets('choosing a fill in the bucket sheet takes the bucket and '
      'shows the tone icon while filling with a tone', (tester) async {
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
        name: 'bucket',
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
    DrawingTool tool() =>
        tester.widget<CanvasArea>(find.byType(CanvasArea)).currentTool;
    expect(tool(), DrawingTool.pen);

    Future<void> openSheet() async {
      final bucket = find.byIcon(Icons.format_color_fill).evaluate().isEmpty
          ? find.byIcon(Icons.texture)
          : find.byIcon(Icons.format_color_fill);
      await tester.ensureVisible(bucket.first);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.longPress(bucket.first);
      await tester.pumpAndSettle();
    }

    await openSheet();
    final tile = find.descendant(
      of: find.byType(SliverToneFillGrid),
      matching: find.byType(InkWell),
    );
    await tester.tap(tile.first);
    await tester.pumpAndSettle();
    expect(tool(), DrawingTool.bucket);
    expect(
      tester.element(find.byType(CanvasArea)).read<ToneService>().bucketUseTone,
      isTrue,
    );
    expect(find.byIcon(Icons.texture), findsWidgets);
    expect(find.byIcon(Icons.format_color_fill), findsNothing);

    // Back to the pen, then ベタ塗り from the sheet.
    await tester.ensureVisible(find.byIcon(Icons.brush).first);
    await tester.tap(find.byIcon(Icons.brush).first);
    await tester.pumpAndSettle();
    await openSheet();
    await tester.tap(find.text(l10n.toolbarBucketFlatFill));
    await tester.pumpAndSettle();
    expect(tool(), DrawingTool.bucket);
    expect(find.byIcon(Icons.format_color_fill), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
