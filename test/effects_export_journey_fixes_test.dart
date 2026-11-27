// 演出フィルターと書き出しの作品づくりで見つかったこと（2026-11-27、工程3b）。
//
// * フェードの色で黒・白を選べなかった（テーマの文字色が2つ並んでいた）。
// * ドット絵の演出フィルターで「パレットから選ぶ」が効かず、配色方式が
//   「色数を指定する」に戻った（方式と色を、古い値から続けて2回作り直した）。
// * 作品詳細の再生に演出フィルターとカメラが出ず、書き出しと違った。
// * 名前の無い演出フィルターを複製すると、同じ名前が2つ並んだ。
// * 書き出しが失敗した文が、形式・プリセットを変えても残った。
// * 書き出し完了の画面は、タイムラインから開いても「キャンバスへ戻る」で、
//   閉じる・続けて書き出すが無かった（所有者の判断、判断カードJ13）。
// * 演出フィルターのトーンカーブ・レベル補正は無料で足せた。描画フィルターと
//   同じく特典にそろえる（所有者の判断、判断カードJ11）。
// * 演出フィルターのシートが下から6割を覆ってプレビューを暗くし、値を変えた
//   結果は閉じてそのコマへ動かさないと見えなかった（判断カードJ14、U64）。
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
import 'package:niarim/screens/export/export_screen.dart';
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
    String Function(AppLocalizations l10n) label, {
    bool expand = true,
  }) async {
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    await tester.tap(find.byIcon(Icons.movie_filter).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label(l10n)).last);
    await tester.pumpAndSettle();
    if (expand) {
      // The sheet opens low (the preview stays in sight); pull it up to
      // reach the settings, as a person would.
      await tester.drag(
        find.byType(DraggableScrollableSheet),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
    }
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

  testWidgets('a failed export\'s message goes once the settings change', (
    tester,
  ) async {
    final (ps: _, :projectId, sceneId: _) = await openApp(tester);
    appRouter.go('/export/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;
    // MP4 needs the device's encoder, which a test does not have: it fails.
    final start = find.text(l10n.exportStartButton);
    await tester.ensureVisible(start);
    await tester.tap(start);
    final failed = find.textContaining(l10n.exportFailedError('').trim());
    for (var i = 0; i < 40 && failed.evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 250));
    }
    expect(failed, findsOneWidget);
    final gif = find.text(l10n.exportFormatGif);
    await tester.ensureVisible(gif);
    await tester.tap(gif);
    await tester.pump();
    expect(failed, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export complete: close, export again, back to the timeline', (
    tester,
  ) async {
    final (ps: _, :projectId, sceneId: _) = await openApp(tester);
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    final completed = find.text(l10n.exportCompleteTitle);

    Future<void> exportGif() async {
      final gif = find.text(l10n.exportFormatGif);
      await tester.ensureVisible(gif);
      await tester.tap(gif);
      await tester.pump();
      final start = find.text(l10n.exportStartButton);
      await tester.ensureVisible(start);
      await tester.tap(start);
      for (var i = 0; i < 80 && completed.evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 250));
      }
      expect(completed, findsOneWidget);
      expect(
        find.byKey(const ValueKey('exportCompleteTimeline')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const Key('timelineExportButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(ExportScreen), findsOneWidget);

    // × closes and the export screen stays.
    await exportGif();
    await tester.tap(find.byKey(const ValueKey('exportCompleteClose')));
    await tester.pumpAndSettle();
    expect(completed, findsNothing);
    expect(find.byType(ExportScreen), findsOneWidget);

    // Export again: back at the settings, at the top.
    await exportGif();
    await tester.tap(find.byKey(const ValueKey('exportCompleteAgain')));
    await tester.pumpAndSettle();
    expect(completed, findsNothing);
    expect(find.byType(ExportScreen), findsOneWidget);
    final presets = find.text(l10n.exportPresetSection);
    expect(presets.hitTestable(), findsOneWidget);

    // Back to the timeline it was opened from.
    await exportGif();
    await tester.tap(find.byKey(const ValueKey('exportCompleteTimeline')));
    await tester.pumpAndSettle();
    expect(find.byType(ExportScreen), findsNothing);
    expect(find.byType(TimelineScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without premium the tone curve and levels effects are locked', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    await tester.tap(find.byIcon(Icons.movie_filter).first);
    await tester.pumpAndSettle();
    for (final name in [l10n.filterNameToneCurve, l10n.filterNameLevels]) {
      await tester.tap(find.text(l10n.commonAdd).last);
      await tester.pumpAndSettle();
      final option = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(name),
      );
      await tester.scrollUntilVisible(
        option,
        120,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final row = find.ancestor(of: option, matching: find.byType(ListTile));
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
        reason: name,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(ps.effectFiltersOf(projectId, sceneId), isEmpty, reason: name);
      expect(
        find.text(l10n.filterNameSharpen),
        findsNothing,
        reason: 'the add list closed',
      );
      // The premium banner tells what it needs; close it.
      expect(
        find.textContaining(
          name == l10n.filterNameToneCurve
              ? l10n.premiumFeatureToneCurve
              : l10n.premiumFeatureLevelCorrection,
        ),
        findsWidgets,
        reason: name,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the effect sheet leaves the preview in sight, on its frames', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId) = await openApp(tester);
    ps.addEffectFilter(
      projectId,
      sceneId,
      const EffectFilterInstance(
        id: 'late',
        type: EffectFilterType.vignette,
        startFrame: 6,
        endFrame: 9,
      ),
    );
    final l10n = await openEffect(
      tester,
      projectId,
      (l) => l.filterNameVignette,
      expand: false,
    );
    // Not dimmed.
    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(barriers.last.color, anyOf(isNull, const Color(0x00000000)));
    // The preview went to the effect's first frame (F7 of 12).
    expect(
      tester
          .widget<Text>(find.byKey(const Key('timelinePreviewFrameCount')))
          .data,
      '7/12',
    );
    expect(find.text(l10n.filterNameVignette), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
