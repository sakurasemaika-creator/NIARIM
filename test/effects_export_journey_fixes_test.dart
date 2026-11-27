// 演出フィルターと書き出しの作品づくりで見つかったこと（2026-11-27、工程3b）。
//
// * フェードの色で黒・白を選べなかった（テーマの文字色が2つ並んでいた）。
// * ドット絵の演出フィルターで「パレットから選ぶ」が効かず、配色方式が
//   「色数を指定する」に戻った（方式と色を、古い値から続けて2回作り直した）。
// * 作品詳細の再生に演出フィルターとカメラが出ず、書き出しと違った。
// * 名前の無い演出フィルターを複製すると、同じ名前が2つ並んだ。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/pixel_color_mode.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  Future<({ProjectService ps, String projectId, String sceneId})> openApp(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('effects-fixes-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final created = await tester.runAsync(
      () => ps.createProject(
        name: 'effects',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    );
    final projectId = created!.id;
    return (
      ps: ps,
      projectId: projectId,
      sceneId: ps.scenesOf(projectId).first.id,
    );
  }

  EffectFilterInstance effectOf(
    ProjectService ps,
    String projectId,
    String sceneId,
    String id,
  ) => ps.effectFiltersOf(projectId, sceneId).singleWhere((e) => e.id == id);

  /// Opens the timeline's effect filter sheet and the tile of [label].
  Future<AppLocalizations> openEffect(
    WidgetTester tester,
    String projectId,
    String Function(AppLocalizations l10n) label,
  ) async {
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    await tester.tap(find.byIcon(Icons.movie_filter).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label(l10n)).last);
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('a fade goes to black or white', (tester) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    ps.addEffectFilter(
      projectId,
      sceneId,
      const EffectFilterInstance(
        id: 'fade',
        type: EffectFilterType.fade,
        startFrame: 0,
        endFrame: 5,
        fadeColor: Color(0xFFFF0000),
      ),
    );
    await openEffect(tester, projectId, (l) => l.timelineEffectTypeFade);
    Future<void> choose(String key) async {
      final swatch = find.byKey(const ValueKey('fadeColorSwatch'));
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await choose('fadeColorWhite');
    expect(
      effectOf(ps, projectId, sceneId, 'fade').fadeColor,
      const Color(0xFFFFFFFF),
    );
    await choose('fadeColorBlack');
    expect(
      effectOf(ps, projectId, sceneId, 'fade').fadeColor,
      const Color(0xFF000000),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a palette for pixel art keeps the palette mode', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    ps.addEffectFilter(
      projectId,
      sceneId,
      const EffectFilterInstance(
        id: 'pixel',
        type: EffectFilterType.pixelate,
        startFrame: 0,
        endFrame: 5,
      ),
    );
    final palettes = tester
        .element(find.byType(MaterialApp).first)
        .read<PixelArtPaletteService>();
    await tester.runAsync(
      () => palettes.addPalette('sky', const [0xFF87CEEB, 0xFFFFFFFF]),
    );
    final l10n = await openEffect(
      tester,
      projectId,
      (l) => l.filterNamePixelate,
    );
    final mode = find.byType(DropdownButtonFormField<PixelColorMode>);
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pixelColorModePalette).last);
    await tester.pumpAndSettle();
    // The palette, then apply.
    await tester.tap(find.text('sky').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pixelArtPalettePickerApplyButton));
    await tester.pumpAndSettle();
    final effect = effectOf(ps, projectId, sceneId, 'pixel');
    expect(effect.pixelColorMode, PixelColorMode.explicit);
    expect(effect.pixelExplicitColors, [0xFF87CEEB, 0xFFFFFFFF]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a copy of an unnamed effect is told apart', (tester) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    ps.addEffectFilter(
      projectId,
      sceneId,
      const EffectFilterInstance(
        id: 'vignette',
        type: EffectFilterType.vignette,
        startFrame: 0,
        endFrame: 5,
      ),
    );
    final l10n = await openEffect(
      tester,
      projectId,
      (l) => l.filterNameVignette,
    );
    final duplicate = find.byTooltip(l10n.commonDuplicate);
    if (duplicate.evaluate().isNotEmpty) {
      await tester.tap(duplicate.first);
    } else {
      await tester.tap(find.text(l10n.commonDuplicate).first);
    }
    await tester.pumpAndSettle();
    final names = [
      for (final e in ps.effectFiltersOf(projectId, sceneId)) e.name,
    ];
    expect(names, hasLength(2));
    expect(names.whereType<String>(), hasLength(1));
    expect(names.whereType<String>().single, isNot(l10n.filterNameVignette));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the project detail plays the effects like the export', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    // A fade that is fully red on the first frame.
    ps.addEffectFilter(
      projectId,
      sceneId,
      const EffectFilterInstance(
        id: 'red',
        type: EffectFilterType.fade,
        startFrame: 0,
        endFrame: 0,
        fadeColor: Color(0xFFFF0000),
      ),
    );
    appRouter.go('/project/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    final raw = find.descendant(
      of: find.byKey(const Key('projectDetailPreviewArtwork')),
      matching: find.byType(RawImage),
    );
    expect(raw, findsOneWidget);
    final image = tester.widget<RawImage>(raw).image!;
    expect([image.width, image.height], [160, 90]);
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final i = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
    expect(
      [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)],
      [255, 0, 0],
    );
    expect(tester.takeException(), isNull);
  });
}
