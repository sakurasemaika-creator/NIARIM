// 線画レイヤーを消して残った自動塗りレイヤーも、パーツの色を変えたら更新マークが
// 付き、キャンバスのレイヤーの︙から「最新の色で塗りつぶす」を選べる。
//
// 実際に使ってみたとき（2026-11-27）、線画を消した自動塗りレイヤーの︙は普通の
// レイヤーの設定のシートで、この項目が無かった（タイムラインの︙にだけあった）。
// パーツの色を変えても、更新マークは線画の下の塗りにしか付かなかった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  useTemporaryProjectStorage();

  testWidgets('an autofill layer left without its line art can be refilled '
      'from the canvas', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'language': 'ja',
    });
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    Widget app(Widget home) => MultiProvider(
      providers: providers,
      child: Builder(
        builder: (context) => MaterialApp(
          theme: context.watch<ThemeService>().themeData,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpWidget(app(const Scaffold(body: SizedBox.shrink())));
    final context = tester.element(find.byType(Scaffold));
    final ps = context.read<ProjectService>();
    final part = context
        .read<AutofillPresetService>()
        .presets
        .expand((preset) => preset.parts)
        .first;
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'orphan',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    model.Layer add(model.LayerType type, String name) => ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: type,
      name: name,
    );
    final fill = add(model.LayerType.autoFill, 'fill');
    final line = add(model.LayerType.autoFillLineart, 'line');
    ps.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: line.copyWith(partId: part.id),
    );
    ps.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: fill.copyWith(partId: part.id),
    );
    // A painted patch in an old colour.
    final tiles = ps.tileManagerOf(project.id);
    final key = ps.tileKeyFor(project.id, sceneId, 0, fill.id);
    tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [10, 200, 10, 255]);
    tiles.markDirty(key, 0, 0);
    ps.removeLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layerId: line.id,
    );
    model.Layer current() => ps
        .layersOf(project.id, sceneId, 0)
        .singleWhere((layer) => layer.id == fill.id);

    // The part's colour changes: the left fill is marked too.
    ps.markAutofillUpdateForPartId(part.id);
    expect(current().needsAutofillUpdate, isTrue);

    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 420,
              child: LayerPanel(
                onClose: () {},
                projectId: project.id,
                sceneId: sceneId,
                frameIndex: 0,
                currentLayerId: fill.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('canvasLayerMenu_${fill.id}')));
    await tester.pumpAndSettle();
    final refill = find.byKey(const ValueKey('layerOptionsOrphanFill'));
    expect(refill, findsOneWidget);
    await tester.tap(refill);
    for (var i = 0; i < 6; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(current().needsAutofillUpdate, isFalse);
    final pixel = tiles.getTile(key, 0, 0)!.sublist(0, 4);
    expect(pixel, [
      (part.color >> 16) & 0xFF,
      (part.color >> 8) & 0xFF,
      part.color & 0xFF,
      255,
    ], reason: 'filled with the part\'s latest colour');
  });
}
