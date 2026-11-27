// レイヤーの画素が置き換わったら（下と結合した結合先など）、そのレイヤーの
// サムネイルも描き直す。
//
// 実際に使ってみたとき（2026-11-27）、上のレイヤーを「下と結合」すると、
// 結合先のサムネイルが空のまま残った（パネルを開き直すと出た）。サムネイルは
// 取り消しの数が増えたとき、選んでいるレイヤーの分だけを描き直していた。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();

  testWidgets('merging redraws the thumbnail of the layer it merges into', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final ps = tester.element(find.byType(Scaffold)).read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'merge-thumb',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    final bottom = ps.layersOf(project.id, sceneId, 0).first;
    final top = ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'top',
    );
    // The top layer is all red; the bottom one is empty.
    final red = Uint8List(64 * 64 * 4);
    for (var i = 0; i < red.length; i += 4) {
      red.setAll(i, [220, 30, 30, 255]);
    }
    ps
        .tileManagerOf(project.id)
        .replaceLayerPixels(ps.tileKeyFor(project.id, sceneId, 0, top.id), red);

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 700,
                child: LayerPanel(
                  onClose: () {},
                  projectId: project.id,
                  sceneId: sceneId,
                  frameIndex: 0,
                  currentLayerId: top.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
    }

    Future<List<int>> thumbCentre(String layerId) async {
      final raw = tester.widget<RawImage>(
        find.descendant(
          of: find.byKey(ValueKey('layer-preview-tap-$layerId')),
          matching: find.byType(RawImage),
        ),
      );
      final image = raw.image!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final i = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
      return [for (var c = 0; c < 3; c++) data.getUint8(i + c)];
    }

    await settle();
    expect(await thumbCentre(bottom.id), [255, 255, 255], reason: 'empty');

    await tester.runAsync(
      () => ps.mergeLayers(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layerIds: [top.id, bottom.id],
      ),
    );
    await settle();
    expect(ps.layersOf(project.id, sceneId, 0).single.id, bottom.id);
    final merged = await thumbCentre(bottom.id);
    expect(merged[0], greaterThan(180), reason: 'the red is merged in');
    expect(merged[1], lessThan(80));
  });
}
