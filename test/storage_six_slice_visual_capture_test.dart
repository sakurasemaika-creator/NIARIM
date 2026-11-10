import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real Japanese StorageScreen shows all six pie slices', (
    tester,
  ) async {
    // Entirely isolated synthetic filesystem; do not touch user projects.
    final root = Directory.systemTemp.createTempSync('storage-six-slices-');
    final docs = Directory('${root.path}/docs')..createSync();
    final cache = Directory('${root.path}/cache')..createSync();

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path;
    });

    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await loadAppFonts(tester);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    expect(providers, isNotNull);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(
          providers: providers!,
          child: const NiarimApp(),
        ),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 450));

    final ps = tester.element(find.byType(MaterialApp)).read<ProjectService>();
    final active = await tester.runAsync(() => ps.createProject(
      name: '容量グラフ・通常プロジェクト',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 320,
      exportHeight: 180,
    ));
    final deleted = await tester.runAsync(() => ps.createProject(
      name: '容量グラフ・ゴミ箱プロジェクト',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 320,
      exportHeight: 180,
    ));
    expect(active, isNotNull);
    expect(deleted, isNotNull);
    final activeId = active!.id;
    final deletedId = deleted!.id;
    await tester.runAsync(() => ps.deleteProject(deletedId));

    // Distinct sizes make the six per-row bar lengths visibly comparable.
    // Both project archives also contribute a small amount of real metadata.
    void fileWithSize(String path, int size) {
      final file = File(path)..createSync(recursive: true);
      file.writeAsBytesSync(List<int>.filled(size, 0), flush: true);
    }
    const kib = 1024;
    final base = '${docs.path}/niarim';
    fileWithSize(
      '$base/projects/${activeId}/Materials/test-material.png',
      200 * kib,
    );
    fileWithSize('$base/projects/${activeId}/project-fixture.bin', 150 * kib);
    fileWithSize('$base/projects/${deletedId}/trash-fixture.bin', 25 * kib);
    fileWithSize('$base/exports/fixture.png', 110 * kib);
    fileWithSize('$base/Brushes/fixture-brush.bin', 75 * kib);
    fileWithSize('${cache.path}/cache-fixture.bin', 50 * kib);

    final values = await tester.runAsync(
      () => StorageInfoService().computeBreakdown({deleted.id}),
    );
    expect(values, isNotNull);
    for (final category in StorageCategory.values) {
      expect(values!.bytesOf(category), greaterThan(0), reason: '$category');
    }

    appRouter.go('/storage');
    await pumpRealAsync(tester, const Duration(seconds: 2));
    expect(find.byType(StorageScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final storageContext = tester.element(find.byType(StorageScreen));
    final l10n = AppLocalizations.of(storageContext)!;
    final scheme = Theme.of(storageContext).colorScheme;
    // Non-selected canvas toolbar icons are painted with onSurface.
    final expectedOutline = scheme.onSurface;
    // The 120px chart remains a pie and is outlined with the icon fill.
    final pie = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter?.runtimeType.toString() == '_PieChartPainter',
    );
    expect(pie, findsOneWidget);
    final piePaint = tester.widget<CustomPaint>(pie);
    expect((piePaint.painter! as dynamic).outlineColor, expectedOutline);

    final entries = [
      (StorageCategory.materials, l10n.storageCategoryMaterials),
      (StorageCategory.projectData, l10n.storageCategoryProjectData),
      (StorageCategory.exports, l10n.storageCategoryExports),
      (StorageCategory.customAssets, l10n.storageCategoryCustomAssets),
      (StorageCategory.cache, l10n.storageCategoryCache),
      (StorageCategory.trash, l10n.storageCategoryTrash),
    ];
    final largest = entries
        .map((entry) => values!.bytesOf(entry.$1))
        .reduce((a, b) => a > b ? a : b);
    for (final (category, label) in entries) {
      expect(find.text(label), findsOneWidget, reason: label);
      final bar = find.byKey(Key('storageBreakdownBar_$label'));
      expect(bar, findsOneWidget, reason: 'Missing bar for $label');
      final labelWidget = tester.widget<Text>(
        find.byKey(Key('storageBreakdownBarLabel_$label')),
      );
      final valueWidget = tester.widget<Text>(
        find.byKey(Key('storageBreakdownBarValue_$label')),
      );
      expect(labelWidget.data, label);
      expect(valueWidget.data, formatStorageBytes(values!.bytesOf(category)));
      expect(labelWidget.style?.color, scheme.onSecondary);
      expect(valueWidget.style?.color, scheme.onSecondary);
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: bar,
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(
        fill.widthFactor,
        closeTo(values!.bytesOf(category) / largest, 0.0001),
        reason: 'Wrong relative size for $label',
      );
      // The outline is drawn over the colored fill, never replaced by it.
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: bar, matching: find.byType(DecoratedBox)),
      ).toList();
      expect(boxes.length, 3);
      expect((boxes.first.decoration as BoxDecoration).color, expectedOutline);
      final border = (boxes.last.decoration as BoxDecoration).border as Border;
      expect(
        border.top.color,
        expectedOutline,
        reason: 'Bar border must follow the current theme for $label',
      );
    }
    // The category dots remain, but they must not have an outline.
    final legendDots = tester.widgetList<Container>(
      find.byType(Container),
    ).where((widget) => widget.constraints == null &&
        widget.child == null &&
        widget.alignment == null &&
        widget.margin == null &&
        widget.padding == null &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
        (widget.decoration! as BoxDecoration).border == null).toList();
    expect(legendDots.length, greaterThanOrEqualTo(6));
    expect(tester.takeException(), isNull);

    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    expect(png, isNotNull);
    final dir = Directory('build/storage-six-slices')..createSync(recursive: true);
    await tester.runAsync(
      () => File('${dir.path}/storage_ja_six_categories.png')
          .writeAsBytes(png!),
    );
    debugPrint('STORAGE SIX SLICES CAPTURE: ${dir.path}/storage_ja_six_categories.png');
  });
}
