import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show CanvasScreen;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/widgets/autofill_preset_selection_sheet.dart';
import 'package:niarim/widgets/scrollable_sheet_body.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

/// キャンバスのほかのパネル・シート・ダイアログでも、スクロールする中の行の
/// 押したとき・重ねたときの色が、スクロールの外へはみ出して描かれないこと。
///
/// ListTile・InkWellは色を一番近いMaterialへ描く。そのMaterialがスクロールより
/// 大きいと（パネルの面・ダイアログ・シート）、スクロールで半分隠れた行を
/// 押したときの色が、スクロールの外（見出し・ボタンの段・画面下の余白）へ
/// 描かれる。ボタン（IconButton・TextButton）は自分のMaterialを持つので
/// スクロールの中で切り抜かれる。
///
/// 行を半分隠れる位置へスクロールし、見えている半分を押したまま撮って、
/// 押す前とスクロールの外の画素を比べる（DISC087と同じ確かめ方）。
void main() {
  useTemporaryProjectStorage();

  const shot = ValueKey('disc117-shot');
  late List<SingleChildWidget> providers;

  Future<void> boot(
    WidgetTester tester,
    Size view, {
    double bottomInset = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'language': 'ja',
    });
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    // 画面の下のナビゲーションバー（端から端まで描く端末では、シートの面が
    // その下まで続き、中身はSafeAreaで持ち上がる）。
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await loadAppFonts(tester);
    providers = (await tester.runAsync(buildAppProviders))!;
  }

  Widget app(Widget home) => MultiProvider(
    providers: providers,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: context.watch<ThemeService>().themeData,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // シート・ダイアログ（Overlay）も一緒に撮る。
        builder: (context, child) => RepaintBoundary(key: shot, child: child),
        home: home,
      ),
    ),
  );

  Future<Project> newProject(WidgetTester tester) async {
    await tester.pumpWidget(app(const Scaffold(body: SizedBox.shrink())));
    final service = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    return (await tester.runAsync(
      () => service.createProject(
        name: 'disc117',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
  }

  Future<({Uint8List pixels, int width, int height})> capture(
    WidgetTester tester,
  ) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    final result = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final out = (
        pixels: data!.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
      image.dispose();
      return out;
    });
    return result!;
  }

  /// [inside]の外・中で[a]と[b]の違う画素を数える。
  ({int outside, int inside, Rect? bounds}) compare(
    ({Uint8List pixels, int width, int height}) a,
    ({Uint8List pixels, int width, int height}) b,
    Rect inside,
  ) {
    var outside = 0, within = 0;
    Rect? bounds;
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        final i = (y * a.width + x) * 4;
        if (a.pixels[i] == b.pixels[i] &&
            a.pixels[i + 1] == b.pixels[i + 1] &&
            a.pixels[i + 2] == b.pixels[i + 2] &&
            a.pixels[i + 3] == b.pixels[i + 3]) {
          continue;
        }
        final p = Offset(x + 0.5, y + 0.5);
        if (inside.contains(p)) {
          within++;
        } else {
          outside++;
          final px = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
          bounds = bounds == null ? px : bounds.expandToInclude(px);
        }
      }
    }
    return (outside: outside, inside: within, bounds: bounds);
  }

  /// スクロールの下の縁と上の縁のそれぞれで、[rows]のうち半分隠れる位置へ
  /// スクロールできる最初の行を半分隠し、見えている半分を指で押したまま
  /// 撮る。押したときの色がスクロールの外へ出た縁ごとに説明を返す（出な
  /// ければ空）。押した色がスクロールの中にも出なければ失敗にする（押した所を
  /// 外した確かめは意味がない）。どちらの縁でも隠せる行が無ければ失敗。
  Future<List<String>> pressHalfHidden(
    WidgetTester tester, {
    required Finder rows,
    required String label,
  }) async {
    final shotBox = tester.renderObject<RenderBox>(find.byKey(shot));
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: shotBox) & box.size;
    final failures = <String>[];
    var pressedEdges = 0;
    for (final edge in ['bottom', 'top']) {
      for (final rowElement in rows.evaluate().toList()) {
        final scrollableElement = find
            .ancestor(
              of: find.byElementPredicate((e) => e == rowElement),
              matching: find.byType(Scrollable),
            )
            .evaluate()
            .first;
        final position =
            ((scrollableElement as StatefulElement).state as ScrollableState)
                .position;
        final listBox = scrollableElement.findRenderObject()! as RenderBox;
        final rowBox = rowElement.findRenderObject()! as RenderBox;
        final list = rectOf(listBox);
        final row = rectOf(rowBox);
        final rowTop = row.top - list.top + position.pixels;
        final target = edge == 'bottom'
            ? rowTop - (list.height - row.height / 2)
            : rowTop + row.height / 2;
        if (target < position.minScrollExtent ||
            target > position.maxScrollExtent) {
          continue;
        }
        position.jumpTo(target);
        await tester.pump();
        final visible = rectOf(rowBox).intersect(list);
        final idle = await capture(tester);
        final finger = await tester.startGesture(
          shotBox.localToGlobal(visible.center),
          kind: PointerDeviceKind.touch,
        );
        // スクロールの中では、押した色は少し待ってから出る（スクロールか
        // タップかを見分けるため）。
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));
        final pressed = await capture(tester);
        await finger.cancel();
        await tester.pump(const Duration(milliseconds: 500));
        final diff = compare(idle, pressed, list.inflate(1));
        expect(
          diff.inside,
          greaterThan(0),
          reason: '$label: pressing the half-hidden row showed nothing',
        );
        pressedEdges++;
        if (diff.outside > 0) {
          failures.add(
            '$label: pressing a row half hidden at the $edge edge of the '
            'scroll view $list changed ${diff.outside} px outside it '
            '(bounds ${diff.bounds})',
          );
        }
        break;
      }
    }
    if (pressedEdges == 0) {
      fail('$label: no row can be scrolled half out of view');
    }
    return failures;
  }

  // ─── フィルター（編集中の設定の欄） ──────────────────────────────
  testWidgets('filter panel: pressing a half-hidden noise style row keeps the '
      'ink inside the settings', (tester) async {
    await boot(tester, const Size(360, 780));
    final project = await newProject(tester);
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final sceneId = projects.scenesOf(project.id).first.id;
    final layerId = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((l) => l.type == model.LayerType.normal)
        .id;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 340,
              child: FilterPanel(
                projectId: project.id,
                sceneId: sceneId,
                layerId: layerId,
                frameIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final card = find.byKey(
      const ValueKey('filter-card-${FilterService.genericNoiseFilterId}'),
    );
    await tester.scrollUntilVisible(
      card,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('filter-tile-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(tester.element(card), alignment: .5);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final failures = await pressHalfHidden(
      tester,
      rows: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'noise-style-option-',
            ),
      ),
      label: 'filter noise style',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── フィルター（一覧） ─────────────────────────────────────
  testWidgets('filter panel: pressing a half-hidden filter card keeps the '
      'ink inside the list', (tester) async {
    await boot(tester, const Size(360, 780));
    final project = await newProject(tester);
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final sceneId = projects.scenesOf(project.id).first.id;
    final layerId = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((l) => l.type == model.LayerType.normal)
        .id;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 460,
              child: FilterPanel(
                projectId: project.id,
                sceneId: sceneId,
                layerId: layerId,
                frameIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final failures = await pressHalfHidden(
      tester,
      rows: find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('filter-card-'),
      ),
      label: 'filter list',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── カラーピッカー（パネル全体がスクロール） ──────────────────────
  testWidgets('colour picker panel: pressing a half-hidden button keeps the '
      'ink inside the panel scroll', (tester) async {
    await boot(tester, const Size(360, 780));
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 288,
              height: 320,
              child: ColorPickerPanel(
                currentColor: const Color(0xFF3366CC),
                onColorChanged: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(ColorPickerPanel),
        matching: find.byWidgetPredicate(
          (w) => w is IconButton || w is TextButton,
        ),
      ),
      label: 'colour picker',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── ツールバー：バケツの長押しのシート ────────────────────────────
  testWidgets('bucket menu sheet: pressing a half-hidden row keeps the ink '
      'off the bottom inset', (tester) async {
    await boot(tester, const Size(360, 440), bottomInset: 48);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ToolbarWidget(
              currentTool: DrawingTool.bucket,
              currentColor: const Color(0xFF000000),
              onToolSelected: (_) {},
              onColorTap: () {},
              onBrushTap: () {},
              onLayerTap: () {},
              onPenLongPress: () {},
              onFingerLongPress: () {},
              onTextTap: () {},
              onShapeTap: () {},
              onQuickToolTap: () {},
              onQuickToolLongPress: () {},
              onSaveTap: () {},
              onLassoFillSelected: () {},
              onRulerTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bucket = find.byIcon(Icons.format_color_fill).first;
    await tester.ensureVisible(bucket);
    await tester.longPress(bucket);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      ),
      label: 'bucket menu',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── レイヤー：行の三点メニュー（詳細設定のシート） ──────────────────
  testWidgets('layer options sheet: pressing a half-hidden row keeps the ink '
      'off the bottom inset', (tester) async {
    await boot(tester, const Size(360, 440), bottomInset: 48);
    final project = await newProject(tester);
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final sceneId = projects.scenesOf(project.id).first.id;
    final layer = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((l) => l.type == model.LayerType.normal);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 380,
              child: LayerPanel(
                onClose: () {},
                projectId: project.id,
                sceneId: sceneId,
                frameIndex: 0,
                currentLayerId: layer.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate(
          (w) => w is ListTile || w is SwitchListTile,
        ),
      ),
      label: 'layer options',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── レイヤー：共通レイヤーの範囲のダイアログ ─────────────────────
  testWidgets('layer range dialog: pressing a half-hidden choice keeps the '
      'ink off the title and the buttons', (tester) async {
    // 追加のシートは低い画面では入りきらない（別の不具合）ので、高い画面で
    // ダイアログまで進み、開いてから低くする。
    await boot(tester, const Size(360, 640));
    final project = await newProject(tester);
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final sceneId = projects.scenesOf(project.id).first.id;
    final layer = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((l) => l.type == model.LayerType.normal);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 380,
              child: LayerPanel(
                onClose: () {},
                projectId: project.id,
                sceneId: sceneId,
                frameIndex: 0,
                currentLayerId: layer.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(LayerPanel)))!;
    await tester.tap(find.byIcon(Icons.library_add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.layerPanelMenuCommonLayer));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    tester.view.physicalSize = const Size(360, 440);
    await tester.pumpAndSettle();
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((w) => w is RadioListTile),
      ),
      label: 'layer range',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── レイヤー：ヘルプのダイアログ ─────────────────────────────
  testWidgets('layer help dialog: the scrolling text has no row that paints '
      'ink', (tester) async {
    await boot(tester, const Size(360, 440));
    final project = await newProject(tester);
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final sceneId = projects.scenesOf(project.id).first.id;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 380,
              child: LayerPanel(
                onClose: () {},
                projectId: project.id,
                sceneId: sceneId,
                frameIndex: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final scroll = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    // 押せる行（InkWell・ListTile）が無ければ、押したときの色は描かれない。
    expect(
      find.descendant(
        of: scroll,
        matching: find.byWidgetPredicate(
          (w) => w is InkResponse || w is ListTile,
        ),
      ),
      findsNothing,
    );
  });

  // ─── 自動塗りのプリセット（パーツ）を選ぶシート ─────────────────────
  testWidgets('autofill preset selection sheet: pressing a half-hidden row '
      'keeps the ink off the title and the OK button', (tester) async {
    await boot(tester, const Size(360, 780));
    await tester.pumpWidget(app(const Scaffold(body: SizedBox.expand())));
    final presets = [
      for (var i = 0; i < 12; i++)
        AutofillPreset(id: 'p$i', name: 'プリセット$i', parts: const []),
    ];
    final context = tester.element(find.byType(Scaffold));
    showAutofillPresetSelectionSheet(
      context,
      allPresets: presets,
      initiallyEnabledIds: null,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(CheckboxListTile),
      ),
      label: 'autofill preset selection',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── 共通のシートの中身（ScrollableSheetBody） ─────────────────────
  // 件数の多いシートはこれで包む（クイックツールの追加・ジェスチャーの
  // 割り当て・フォルダへ移動・レイヤーの追加等）。スクロールはSafeAreaの
  // 内側なので、シートの面はナビゲーションバーの余白の下まで続く。
  testWidgets('ScrollableSheetBody: pressing a half-hidden row keeps the ink '
      'off the bottom inset', (tester) async {
    await boot(tester, const Size(360, 440), bottomInset: 48);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ScrollableSheetBody(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 12; i++)
                        ListTile(
                          leading: const Icon(Icons.brush),
                          title: Text('項目$i'),
                          onTap: () {},
                        ),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      ),
      label: 'ScrollableSheetBody',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // ─── キャンバスの「設定/編集」のシート ──────────────────────────
  testWidgets('canvas settings/edit sheet: pressing a half-hidden row keeps '
      'the ink off the bottom inset', (tester) async {
    await boot(tester, const Size(360, 440), bottomInset: 48);
    appRouter.go('/home');
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final projects = tester
        .element(find.byType(Navigator).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'disc117',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    appRouter.push('/canvas/${project.id}');
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CanvasScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final failures = await pressHalfHidden(
      tester,
      rows: find.descendant(of: sheet, matching: find.byType(ListTile)),
      label: 'canvas settings/edit',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    appRouter.go('/home');
    await tester.pumpAndSettle();
  });
}
