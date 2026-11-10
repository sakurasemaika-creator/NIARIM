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

  testWidgets('real Japanese StorageScreen shows six bright bars and device bars without pies', (
    tester,
  ) async {
    // Entirely isolated synthetic filesystem; do not touch user projects.
    final root = Directory.systemTemp.createTempSync('storage-six-slices-');
    final docs = Directory('${root.path}/docs')..createSync();
    final cache = Directory('${root.path}/cache')..createSync();

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    const diskChannel = MethodChannel('disk_space_2');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path;
    });
    // A deterministic, isolated 256 GiB device with 21 GiB free. No physical
    // device state is read or changed. Both charts render on CI Linux.
    messenger.setMockMethodCallHandler(
      diskChannel,
      (call) async => call.method == 'getFreeDiskSpace' ? 21000.0 : 256000.0,
    );
    StorageInfoService().invalidate();

    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(diskChannel, null);
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
    // No pie paintings or circle legends are allowed in either section.
    final pie = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter?.runtimeType.toString() == '_PieChartPainter',
    );
    expect(pie, findsNothing);

    final deviceLabels = [
      l10n.storageCategoryNiarimTotal,
      l10n.storageCategoryOtherApps,
      l10n.storageCategoryFree,
    ];
    final deviceColors = storageDeviceSliceColorsOf(scheme);
    final deviceSections = find.byKey(const ValueKey('storageDeviceSection'));
    expect(deviceSections, findsOneWidget);
    for (var i = 0; i < deviceLabels.length; i++) {
      final label = deviceLabels[i];
      final bar = find.byKey(Key('storageDeviceBar_$label'));
      expect(bar, findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(Key('storageBreakdownBarLabel_$label'))).data,
        label,
      );
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(of: bar, matching: find.byType(FractionallySizedBox)),
      );
      final fillDecoration = (fill.child as DecoratedBox).decoration
          as BoxDecoration;
      expect(fillDecoration.color, deviceColors[i]);
      final barRect = tester.getRect(bar);
      expect(barRect.width, greaterThan(300));
      expect(barRect.left, lessThan(20));
    }

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
    // In the same 390px phone all six bars occupy the section width.
    final breakdownSection =
        find.byKey(const ValueKey('storageBreakdownSection'));
    final firstBar = find.byKey(
      Key('storageBreakdownBar_${l10n.storageCategoryMaterials}'),
    );
    expect(tester.getRect(firstBar).width, greaterThan(300));
    expect(tester.getRect(firstBar).left, lessThan(20));
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
      expect(labelWidget.style?.shadows?.length, 4);
      expect(valueWidget.style?.shadows?.length, 4);
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
    // Neither chart has separate circular legend markers anymore.
    for (final section in [deviceSections, breakdownSection]) {
      final legendDots = tester.widgetList<Container>(
        find.descendant(of: section, matching: find.byType(Container)),
      ).where((widget) =>
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle);
      expect(legendDots, isEmpty);
    }
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
