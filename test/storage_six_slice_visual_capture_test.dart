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

    // About 200 KiB per category makes all six sectors visible, including
    // the active project archive and the trashed project archive.
    void fileWithSize(String path, int size) {
      final file = File(path)..createSync(recursive: true);
      file.writeAsBytesSync(List<int>.filled(size, 0), flush: true);
    }
    const bytes = 200 * 1024;
    final base = '${docs.path}/niarim';
    fileWithSize(
      '$base/projects/${activeId}/Materials/test-material.png',
      bytes,
    );
    fileWithSize('$base/projects/${activeId}/project-fixture.bin', bytes);
    fileWithSize('$base/projects/${deletedId}/trash-fixture.bin', bytes);
    fileWithSize('$base/exports/fixture.png', bytes);
    fileWithSize('$base/Brushes/fixture-brush.bin', bytes);
    fileWithSize('${cache.path}/cache-fixture.bin', bytes);

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

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StorageScreen)),
    )!;
    for (final label in [
      l10n.storageCategoryMaterials,
      l10n.storageCategoryProjectData,
      l10n.storageCategoryExports,
      l10n.storageCategoryCustomAssets,
      l10n.storageCategoryCache,
      l10n.storageCategoryTrash,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
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
