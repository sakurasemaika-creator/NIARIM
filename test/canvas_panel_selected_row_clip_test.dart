import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/models/onion_skin_settings.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

/// キャンバスのパネルの一覧で、選んだ行の背景（ListTileの選択色）が
/// 一覧の外へはみ出して描かれないこと。
///
/// ListTileは背景を最も近いMaterialへ描く。パネルのMaterial（スマホの
/// カード・PC/DeXのドックの面）は一覧のスクロールより外にあるので、
/// スクロールで一覧の上へ出た選択中の行の背景が、一覧の切り抜きを受けずに
/// 上のタブ（ブラシ／トーン／スタンプ）・ボタンの上へ描かれていた
/// （PC/DeXで、ペンのブラシを選んだまま一覧をホイール4目盛り下げると
/// 「ブラシ」のタブが差し色で塗りつぶされた）。
///
/// 一覧のスクロール位置だけを変えて撮り比べ、一覧の外の画素が1つも
/// 変わらないことを確かめる。
void main() {
  useTemporaryProjectStorage();

  const shot = ValueKey('disc087-shot');

  late List<SingleChildWidget> providers;

  Future<void> boot(WidgetTester tester, Size view) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 仏語・文字2倍の行の折り返し・はみ出しを製品と同じ字幅で見る。
    await loadAppFonts(tester);
    providers = (await tester.runAsync(buildAppProviders))!;
  }

  /// 仏語・文字2倍の狭い幅では、一覧の上の「お気に入りのみ」と検索の行が
  /// はみ出す（この不具合とは別の、修正前からある不具合）。その行の
  /// はみ出しだけは[known]へ記録して続け、ほかの例外はそのまま落とす。
  Future<void> allowingFavouritesRowOverflow(
    List<String> known,
    Future<void> Function() body,
  ) async {
    final previous = FlutterError.onError;
    final favouritesRow = RegExp(
      r'creator: Row ← Column ← Padding ← SizedBox ← PanelSurface ← '
      r'(BrushPanel|TonePanel|StampPanel)',
    );
    FlutterError.onError = (details) {
      final text = details
          .toString(minLevel: DiagnosticLevel.debug)
          .replaceAll(RegExp(r'\s+'), ' ');
      final match = favouritesRow.firstMatch(text);
      if (text.contains('A RenderFlex overflowed') && match != null) {
        known.add(
          '${match.group(1)}: '
          '${RegExp(r'overflowed by [0-9.]+ pixels').firstMatch(text)![0]}',
        );
        return;
      }
      previous?.call(details);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
  }

  Widget app({
    required Locale locale,
    required double textScale,
    required Widget child,
  }) {
    return MultiProvider(
      providers: providers,
      child: Builder(
        builder: (context) => MaterialApp(
          theme: context.watch<ThemeService>().themeData,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(key: shot, child: child),
            ),
          ),
        ),
      ),
    );
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

  /// 一覧（[list]）の外で[a]と[b]の違う画素を数える（[selection]を渡すと、
  /// そのうち選択色の画素も数える）。一覧の縁の1pxは小数の位置の丸めで
  /// 揺れうるので比べない。
  String? differenceOutside(
    ({Uint8List pixels, int width, int height}) a,
    ({Uint8List pixels, int width, int height}) b,
    Rect list,
    Color? selection,
  ) {
    expect(b.width, a.width);
    expect(b.height, a.height);
    final inside = list.inflate(1);
    var changed = 0;
    var selectionColoured = 0;
    int? minX, minY, maxX, maxY;
    String? sample;
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        if (inside.contains(Offset(x + 0.5, y + 0.5))) continue;
        final i = (y * a.width + x) * 4;
        if (a.pixels[i] == b.pixels[i] &&
            a.pixels[i + 1] == b.pixels[i + 1] &&
            a.pixels[i + 2] == b.pixels[i + 2] &&
            a.pixels[i + 3] == b.pixels[i + 3]) {
          continue;
        }
        changed++;
        final r = b.pixels[i], g = b.pixels[i + 1], bl = b.pixels[i + 2];
        if (selection != null &&
            (r - (selection.r * 255).round()).abs() <= 2 &&
            (g - (selection.g * 255).round()).abs() <= 2 &&
            (bl - (selection.b * 255).round()).abs() <= 2) {
          selectionColoured++;
        }
        sample ??=
            '($x,$y) ${a.pixels.sublist(i, i + 4)} -> '
            '${b.pixels.sublist(i, i + 4)}';
        minX = minX == null || x < minX ? x : minX;
        minY = minY == null || y < minY ? y : minY;
        maxX = maxX == null || x > maxX ? x : maxX;
        maxY = maxY == null || y > maxY ? y : maxY;
      }
    }
    if (changed == 0) return null;
    final coloured = selection == null
        ? ''
        : '($selectionColoured of them in the selection colour) ';
    return '$changed px outside the list changed $coloured'
        'bounds ($minX,$minY)-($maxX,$maxY), first $sample';
  }

  /// 選んだ行（[selectedRow]）を一覧の真ん中・上へ半分・上へ全部・下へ
  /// 半分・下へ全部の位置へスクロールし、一覧の外が真ん中のときと同じか
  /// 比べる。違った位置ごとに1行の説明を返す。
  Future<List<String>> sweep(
    WidgetTester tester, {
    required Finder selectedRow,
    required String label,
  }) async {
    // スクロールで行が一覧の外へ出ると、その行を探す[Finder]は何も
    // 見つけなくなるので、要るものは先に取っておく。
    final rowElement = selectedRow.evaluate().single;
    final scrollableElement = find
        .ancestor(of: selectedRow, matching: find.byType(Scrollable))
        .evaluate()
        .first;
    final position =
        ((scrollableElement as StatefulElement).state as ScrollableState)
            .position;
    final shotBox = tester.renderObject<RenderBox>(find.byKey(shot));
    final listBox = scrollableElement.findRenderObject()! as RenderBox;
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: shotBox) & box.size;
    final list = rectOf(listBox);
    final rowRect = rectOf(rowElement.findRenderObject()! as RenderBox);
    final rowTop = rowRect.top - list.top + position.pixels;
    final rowHeight = rowRect.height;
    final viewport = list.height;
    final theme = Theme.of(rowElement);
    final selection =
        theme.listTileTheme.selectedTileColor ?? theme.colorScheme.primary;

    Future<bool> jump(double offset) async {
      if (offset < position.minScrollExtent ||
          offset > position.maxScrollExtent) {
        return false;
      }
      position.jumpTo(offset);
      await tester.pump();
      return true;
    }

    // 選んだ行が一覧の真ん中に見えている状態を基準にする。
    expect(
      await jump(
        (rowTop - (viewport - rowHeight) / 2).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      ),
      isTrue,
    );
    final base = await capture(tester);
    final failures = <String>[];
    var tried = 0;
    for (final (name, offset) in [
      ('half above', rowTop + rowHeight / 2),
      ('just above', rowTop + rowHeight + 2),
      ('half below', rowTop - viewport + rowHeight / 2),
      ('just below', rowTop - viewport - 2),
    ]) {
      if (!await jump(offset)) continue;
      tried++;
      expect(rectOf(listBox), list, reason: '$label: the list itself moved');
      final diff = differenceOutside(
        base,
        await capture(tester),
        list,
        selection,
      );
      if (diff != null) failures.add('$label, selected row $name: $diff');
    }
    expect(
      tried,
      greaterThanOrEqualTo(2),
      reason: '$label: the list is too short to scroll the row out of view',
    );
    return failures;
  }

  Finder selectedTile(Finder within) => find.descendant(
    of: within,
    matching: find.byWidgetPredicate((w) => w is ListTile && w.selected),
  );

  /// 選んだ行（[selectedRow]）を一覧の真ん中に置き、上の縁が画素の
  /// ちょうど半分（y = n + 0.5）に来るよう一覧をずらして、上下の縁の画素に
  /// 選択色がどれだけ載っているか（被覆率）を測る。縁の画素の被覆率は、
  /// 行がその画素にかかる割合（上の縁なら0.5）と同じでなければならない。
  ///
  /// 行の大きさで背景を切り抜くと、背景の形のぼかしに切り抜きのぼかしが
  /// 重なり、縁の画素が約0.25まで薄くなる（行ごとに透明なMaterialを
  /// 挟んでいた頃の見た目）。違った縁ごとに1行の説明を返す。
  Future<List<String>> restingEdges(
    WidgetTester tester, {
    required Finder selectedRow,
    required String label,
  }) async {
    final rowElement = selectedRow.evaluate().single;
    final scrollableElement = find
        .ancestor(of: selectedRow, matching: find.byType(Scrollable))
        .evaluate()
        .first;
    final position =
        ((scrollableElement as StatefulElement).state as ScrollableState)
            .position;
    final shotBox = tester.renderObject<RenderBox>(find.byKey(shot));
    final listBox = scrollableElement.findRenderObject()! as RenderBox;
    final rowBox = rowElement.findRenderObject()! as RenderBox;
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: shotBox) & box.size;
    final list = rectOf(listBox);
    var row = rectOf(rowBox);
    position.jumpTo(
      (position.pixels + (row.top - list.top) - (list.height - row.height) / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    await tester.pump();
    row = rectOf(rowBox);
    // 一覧を[shift]だけ進めると、行は[shift]だけ上へ動く。
    final shift = [0.0, 1.0, -1.0]
        .map((n) => row.top - row.top.floorToDouble() - 0.5 + n)
        .firstWhere(
          (s) =>
              position.pixels + s >= position.minScrollExtent &&
              position.pixels + s <= position.maxScrollExtent,
        );
    position.jumpTo(position.pixels + shift);
    await tester.pump();
    row = rectOf(rowBox);
    expect(
      row.top - row.top.floorToDouble(),
      closeTo(0.5, 1e-6),
      reason: '$label: the row did not land half a pixel off the grid',
    );
    expect(
      row.top >= list.top + 2 && row.bottom <= list.bottom - 2,
      isTrue,
      reason: '$label: the row is not fully inside its list ($row, $list)',
    );
    final image = await capture(tester);
    List<int> pixel(int x, int y) {
      final i = (y * image.width + x) * 4;
      return image.pixels.sublist(i, i + 4);
    }

    bool same(List<int> a, List<int> b) =>
        a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3];

    // 角の丸みを避け、縁の近くに文字・アイコンの無い列だけで測る。
    final shape = Theme.of(rowElement).listTileTheme.shape;
    final corner = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
        : 0.0;
    double? coverage(int x, int edge, int inward) {
      final out1 = pixel(x, edge - inward), out2 = pixel(x, edge - 2 * inward);
      final in1 = pixel(x, edge + inward), in2 = pixel(x, edge + 2 * inward);
      if (!same(out1, out2) || !same(in1, in2)) return null;
      var channel = 0;
      for (var c = 1; c < 3; c++) {
        if ((in1[c] - out1[c]).abs() > (in1[channel] - out1[channel]).abs()) {
          channel = c;
        }
      }
      final span = in1[channel] - out1[channel];
      if (span.abs() < 12) return null;
      return (pixel(x, edge)[channel] - out1[channel]) / span;
    }

    final failures = <String>[];
    void check(String edgeName, int edge, int inward, double expected) {
      final measured = <double>[];
      for (
        var x = (row.left + corner + 1).ceil();
        x < (row.right - corner - 1).floor();
        x++
      ) {
        final c = coverage(x, edge, inward);
        if (c != null) measured.add(c);
      }
      if (measured.length < 8) {
        failures.add(
          '$label $edgeName: only ${measured.length} clean columns to measure',
        );
        return;
      }
      measured.sort();
      final median = measured[measured.length ~/ 2];
      if ((median - expected).abs() > 0.1) {
        failures.add(
          '$label $edgeName edge: the selection colour covers '
          '${median.toStringAsFixed(2)} of the edge pixel, expected '
          '${expected.toStringAsFixed(2)} (row $row)',
        );
      }
    }

    check('top', row.top.floor(), 1, 1 - (row.top - row.top.floorToDouble()));
    final bottomPart = row.bottom - row.bottom.floorToDouble();
    if (bottomPart > 0.2 && bottomPart < 0.8) {
      check('bottom', row.bottom.floor(), -1, bottomPart);
    }
    return failures;
  }

  /// [row]を一覧の下の縁で半分隠れる位置へスクロールし、見えている半分に
  /// マウスを重ねて、重ねたときの色が一覧の外へ描かれないか確かめる。
  Future<String?> hoverOutside(
    WidgetTester tester, {
    required Finder row,
    required String label,
  }) async {
    final rowElement = row.evaluate().first;
    final scrollableElement = find
        .ancestor(of: row.first, matching: find.byType(Scrollable))
        .evaluate()
        .first;
    final position =
        ((scrollableElement as StatefulElement).state as ScrollableState)
            .position;
    final shotBox = tester.renderObject<RenderBox>(find.byKey(shot));
    final listBox = scrollableElement.findRenderObject()! as RenderBox;
    final rowBox = rowElement.findRenderObject()! as RenderBox;
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: shotBox) & box.size;
    final list = rectOf(listBox);
    var rowRect = rectOf(rowBox);
    final target =
        position.pixels +
        (rowRect.top - list.top) -
        (list.height - rowRect.height / 2);
    expect(
      target >= position.minScrollExtent && target <= position.maxScrollExtent,
      isTrue,
      reason: '$label: the row cannot be scrolled half out of view',
    );
    position.jumpTo(target);
    await tester.pump();
    rowRect = rectOf(rowBox);
    final idle = await capture(tester);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.hover(
        shotBox.localToGlobal(Offset(rowRect.left + 30, list.bottom - 4)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final hovered = await capture(tester);
    await tester.sendEventToBinding(mouse.removePointer());
    await tester.pump();
    final inside = list.inflate(1);
    var changedInside = 0;
    for (var y = 0; y < idle.height; y++) {
      for (var x = 0; x < idle.width; x++) {
        if (!inside.contains(Offset(x + 0.5, y + 0.5))) continue;
        final i = (y * idle.width + x) * 4;
        if (idle.pixels[i] != hovered.pixels[i] ||
            idle.pixels[i + 1] != hovered.pixels[i + 1] ||
            idle.pixels[i + 2] != hovered.pixels[i + 2]) {
          changedInside++;
        }
      }
    }
    expect(
      changedInside,
      greaterThan(0),
      reason: '$label: hovering the row showed nothing',
    );
    final diff = differenceOutside(idle, hovered, list, null);
    return diff == null ? null : '$label, hovered half-hidden row: $diff';
  }

  /// ペンのサブツールのパネルで[tab]の一覧を出し、一覧の真ん中より下の
  /// 1件を選んで（上にも下にもスクロールで隠せるように）、その行が
  /// 見える所までスクロールする。選んだ行を返す。
  Future<Finder> pumpPenSubToolList(
    WidgetTester tester,
    PenSubTool tab, {
    Size? dock,
    Locale locale = const Locale('ja'),
    double textScale = 1,
  }) async {
    Widget panel = PenSubToolPanel(
      key: ValueKey(tab),
      currentTool: DrawingTool.pen,
      currentSubTool: tab,
      onSubToolSelected: (_) {},
      onClose: () {},
    );
    if (dock != null) {
      panel = DockedPanelScope(
        child: SizedBox(width: dock.width, height: dock.height, child: panel),
      );
    }
    await tester.pumpWidget(
      app(locale: locale, textScale: textScale, child: panel),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PenSubToolPanel));
    final firstRow = find.byType(ListTile).first;
    final list = find
        .ancestor(of: firstRow, matching: find.byType(Scrollable))
        .first;
    final rowHeight = tester.getSize(firstRow).height;
    final pick = (tester.getSize(list).height / rowHeight).ceil() + 2;
    switch (tab) {
      case PenSubTool.brush:
        final s = context.read<BrushService>();
        s.selectBrush(s.brushes[pick].id);
      case PenSubTool.tone:
        final s = context.read<ToneService>();
        s.selectTone(s.tones[pick].id);
      case PenSubTool.stamp:
        final s = context.read<StampService>();
        s.selectStamp(s.stamps[pick].id);
      case PenSubTool.lassoFill:
        break;
    }
    await tester.pump();
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo((rowHeight * pick).clamp(0, position.maxScrollExtent));
    await tester.pump();
    final selected = selectedTile(list);
    expect(selected, findsOneWidget, reason: '$tab: no selected row');
    return selected;
  }

  /// レイヤーが17枚あるプロジェクトのレイヤーパネルを出し、真ん中の
  /// レイヤーを選んで見える所までスクロールする。選んだ行を返す。
  Future<Finder> pumpLayerList(WidgetTester tester, {Size? dock}) async {
    await tester.pumpWidget(
      app(locale: const Locale('ja'), textScale: 1, child: const SizedBox()),
    );
    final service = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => service.createProject(
        name: 'disc087-layers',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final sceneId = service.scenesOf(project.id).first.id;
    for (var i = 0; i < 16; i++) {
      service.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: model.LayerType.normal,
        name: 'L$i',
      );
    }
    final layers = service.layersOf(project.id, sceneId, 0);
    final current = layers[8].id;
    Widget panel = LayerPanel(
      onClose: () {},
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      dockedMode: dock != null,
      currentLayerId: current,
    );
    panel = dock == null
        ? SizedBox(width: 250, height: 420, child: panel)
        : DockedPanelScope(
            child: SizedBox(
              width: dock.width,
              height: dock.height,
              child: panel,
            ),
          );
    await tester.pumpWidget(
      app(locale: const Locale('ja'), textScale: 1, child: panel),
    );
    await tester.pumpAndSettle();
    final list = find
        .ancestor(
          of: find.byType(ListTile).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(selectedTile(list), 60, scrollable: list);
    await tester.pump();
    return selectedTile(list);
  }

  /// 低い画面（640x300）のスマホで定規のパネルを出す（一覧がスクロール
  /// する）。二点透視の定規を使っている行（上下に区切り線の無い行）を返す。
  Future<Finder> pumpRulerList(WidgetTester tester) async {
    await tester.pumpWidget(
      app(
        locale: const Locale('ja'),
        textScale: 1,
        child: RulerPanel(
          activeRuler: const Ruler(
            type: RulerType.twoPointPerspective,
            position: Offset(160, 90),
            settings: RulerSettings(),
          ),
          onRulerChanged: (_) {},
          onClose: () {},
          canvasWidth: 320,
          canvasHeight: 180,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find
        .ancestor(
          of: find.byType(ListTile).first,
          matching: find.byType(Scrollable),
        )
        .first;
    return selectedTile(list);
  }

  for (final (layout, view, dock) in [
    ('phone', const Size(360, 780), null),
    ('pc narrow dock', const Size(1400, 1300), const Size(220, 520)),
    ('pc wide dock', const Size(1400, 1300), const Size(460, 520)),
  ]) {
    for (final (locale, textScale) in [
      (const Locale('ja'), 1.0),
      (const Locale('fr'), 2.0),
    ]) {
      testWidgets('$layout ${locale.languageCode} x$textScale: the selected '
          'brush/tone/stamp row stays inside its list', (tester) async {
        await boot(tester, view);
        final failures = <String>[];
        final knownOverflows = <String>[];
        for (final tab in [
          PenSubTool.brush,
          PenSubTool.tone,
          PenSubTool.stamp,
        ]) {
          await allowingFavouritesRowOverflow(knownOverflows, () async {
            final selected = await pumpPenSubToolList(
              tester,
              tab,
              dock: dock,
              locale: locale,
              textScale: textScale,
            );
            failures.addAll(
              await sweep(tester, selectedRow: selected, label: tab.name),
            );
          });
        }
        if (knownOverflows.isNotEmpty) {
          debugPrint(
            'known overflow of the favourites row (not this defect): '
            '${knownOverflows.join(', ')}',
          );
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  }

  for (final (layout, dock) in [
    ('phone', null),
    ('pc narrow dock', const Size(220, 420)),
    ('pc wide dock', const Size(460, 420)),
  ]) {
    testWidgets('$layout: the selected layer row stays inside its list', (
      tester,
    ) async {
      await boot(tester, const Size(1400, 1300));
      final failures = await sweep(
        tester,
        selectedRow: await pumpLayerList(tester, dock: dock),
        label: 'layer',
      );
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  testWidgets('phone, short screen: the active ruler row stays inside its '
      'list', (tester) async {
    await boot(tester, const Size(640, 300));
    final failures = await sweep(
      tester,
      selectedRow: await pumpRulerList(tester),
      label: 'ruler',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // 一覧の中に見えている選んだ行は、切り抜きを足す前と同じに描かれること。
  // 行ごとに透明なMaterialを挟むと、小数の位置にある行の上下の縁が
  // 行の大きさの切り抜きで薄くなっていた。
  for (final (layout, view, dock) in [
    ('phone', const Size(360, 780), null),
    ('pc wide dock', const Size(1400, 1300), const Size(460, 520)),
  ]) {
    testWidgets('$layout: the resting selected brush/tone/stamp row keeps '
        'its full edges at a fractional position', (tester) async {
      await boot(tester, view);
      final failures = <String>[];
      for (final tab in [PenSubTool.brush, PenSubTool.tone, PenSubTool.stamp]) {
        failures.addAll(
          await restingEdges(
            tester,
            selectedRow: await pumpPenSubToolList(tester, tab, dock: dock),
            label: tab.name,
          ),
        );
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  for (final (layout, dock) in [
    ('phone', null),
    ('pc narrow dock', const Size(220, 420)),
  ]) {
    testWidgets('$layout: the resting selected layer row keeps its full '
        'edges at a fractional position', (tester) async {
      await boot(tester, const Size(1400, 1300));
      final failures = await restingEdges(
        tester,
        selectedRow: await pumpLayerList(tester, dock: dock),
        label: 'layer',
      );
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  testWidgets('phone, short screen: the resting active ruler row keeps its '
      'full edges at a fractional position', (tester) async {
    await boot(tester, const Size(640, 300));
    final failures = await restingEdges(
      tester,
      selectedRow: await pumpRulerList(tester),
      label: 'ruler',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // マウス・ペンを重ねたときの色（InkWellのhover）も、行の背景と同じく
  // 一番近いMaterialへ描かれる。半分隠れた行に重ねても一覧の外へ出ないこと。
  testWidgets('phone: hovering a half-hidden brush row keeps the hover colour '
      'inside the list', (tester) async {
    await boot(tester, const Size(360, 780));
    await pumpPenSubToolList(tester, PenSubTool.brush);
    final list = find
        .ancestor(
          of: find.byType(ListTile).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final rows = find.descendant(of: list, matching: find.byType(ListTile));
    final failure = await hoverOutside(
      tester,
      row: rows.at(rows.evaluate().length ~/ 2),
      label: 'brush',
    );
    expect(failure, isNull, reason: failure);
  });

  testWidgets('phone, short screen: hovering a half-hidden onion skin row '
      'keeps the hover colour inside the scroll view', (tester) async {
    await boot(tester, const Size(640, 360));
    await tester.pumpWidget(
      app(
        locale: const Locale('ja'),
        textScale: 1,
        child: OnionSkinPanel(
          settings: const OnionSkinSettings(enabled: true),
          onChanged: (_) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final failure = await hoverOutside(
      tester,
      row: find.byType(SwitchListTile),
      label: 'onion skin',
    );
    expect(failure, isNull, reason: failure);
  });
}
