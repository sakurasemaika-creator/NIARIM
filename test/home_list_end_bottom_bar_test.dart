import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:niarim/widgets/sheet_list_segment.dart';

import 'helpers/home_matrix_harness.dart';

/// 画面の下にジェスチャーの帯（34px）・3ボタンの帯（48px）がある縦のスマホ
/// （390x844）で、ホームの5つの一覧（プロジェクト〔格子・詳細〕・作品一覧・
/// 共有の受け取ったもの・自分が作成したもの・ゴミ箱）を一番下まで送ると、
/// 最後の行の名前・星・︙・表紙が浮かぶボタンにも帯にも重ならない。一覧の
/// 末尾の余白は帯の分だけ増える（帯が無ければ今までと同じ）。
///
/// 以前はプロジェクトの一覧の末尾の余白（104px）が帯の分を足しておらず、
/// 浮かぶボタンは帯の分だけ上がるので、右下の＋が最後の行の右のカードの名前
/// に重なった（DISC215）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-list-end-bottom-bar'));
  setUpAll(run.prepare);

  void applyBottom(WidgetTester tester, double top, double bottom) {
    final padding = FakeViewPadding(top: top, bottom: bottom);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    tester.view.systemGestureInsets = FakeViewPadding(
      bottom: bottom == 34 ? 34 : 0,
    );
    tester.view.displayFeatures = [
      if (top > 0)
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(165, 0, 60, top - 2),
          type: ui.DisplayFeatureType.cutout,
          state: ui.DisplayFeatureState.unknown,
        ),
    ];
  }

  Rect globalRect(RenderBox box) => Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );

  /// いま見えているタブの本文の縦スクロール。
  ScrollableState? content(HomeMatrix m) {
    ScrollableState? best;
    var bestArea = 0.0;
    for (final e
        in find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.byType(Scrollable),
            )
            .evaluate()) {
      final state = (e as StatefulElement).state as ScrollableState;
      if (state.position.axis != Axis.vertical) continue;
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = globalRect(box).intersect(Offset.zero & m.size);
      if (rect.isEmpty) continue;
      if (rect.width * rect.height > bestArea) {
        bestArea = rect.width * rect.height;
        best = state;
      }
    }
    return best;
  }

  /// 一番下まで送る（遅延して作る一覧は、送るたびに最後の位置が延びる）。
  Future<double> toEnd(HomeMatrix m) async {
    final scrollable = content(m);
    if (scrollable == null || scrollable.position.maxScrollExtent <= 0) {
      return 0;
    }
    for (var i = 0; i < 6; i++) {
      final max = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(max);
      await m.tester.pump();
      if (scrollable.position.maxScrollExtent == max) break;
    }
    await m.frames(2);
    // 中身の高さ（上の帯で本文が低くなっても変わらない）。
    return scrollable.position.maxScrollExtent +
        scrollable.position.viewportDimension;
  }

  /// 一番下まで送った一覧で、浮かぶボタン・下の帯に重なるもの。
  List<String> overlaps(
    HomeMatrix m,
    double bottomInset, {
    double minimumFabGap = 0,
  }) {
    final out = <String>[];
    final fabs = [
      for (final e in find.byType(FloatingActionButton).evaluate())
        if (e.renderObject case final RenderBox box when box.hasSize)
          globalRect(box),
    ];
    final bar = Rect.fromLTRB(
      0,
      m.size.height - bottomInset,
      m.size.width,
      m.size.height,
    );
    final pages = find.byType(TabBarView);
    void check(Finder finder, String kind) {
      for (final e in find.descendant(of: pages, matching: finder).evaluate()) {
        final box = e.renderObject;
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        if (box.size.isEmpty) continue;
        final rect = globalRect(box);
        if (!rect.overlaps(Offset.zero & m.size)) continue;
        final text = e.widget is RichText
            ? ' "${(e.widget as RichText).text.toPlainText()}"'
            : '';
        if (fabs.any((f) => f.overlaps(rect.deflate(1)))) {
          out.add('$kind$text under a floating button: $rect');
        }
        if (bottomInset > 0 && rect.deflate(1).overlaps(bar)) {
          out.add('$kind$text under the bottom bar: $rect');
        }
      }
    }

    check(find.byType(RichText), 'text');
    check(find.byType(CollectionActionFrame), 'card button');
    check(find.byType(FramePreviewBackground), 'thumbnail');
    check(find.byType(FolderThumbnail), 'folder thumbnail');
    // 最後の行（どの列でも）の下の端が、浮かぶボタンの並びと下の帯より上に
    // ある（＋の下に最後の行の右のカードが来るかは件数で変わるので、最後の
    // 行の高さで確かめる）。
    var lowest = double.negativeInfinity;
    for (final e
        in find
            .descendant(
              of: pages,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is RichText ||
                    w is Card ||
                    w is SheetListSegment ||
                    w is CollectionActionFrame ||
                    w is FramePreviewBackground,
              ),
            )
            .evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty) continue;
      final rect = globalRect(box);
      if (!rect.overlaps(Offset.zero & m.size)) continue;
      if (rect.bottom > lowest) lowest = rect.bottom;
    }
    final fabTop = fabs.isEmpty
        ? double.infinity
        : fabs.map((f) => f.top).reduce((a, b) => a < b ? a : b);
    if (lowest + minimumFabGap > fabTop + 0.5) {
      out.add(
        'the last row ends at $lowest, less than $minimumFabGap px '
        'from the floating buttons (top $fabTop)',
      );
    }
    if (lowest > m.size.height - bottomInset + 0.5) {
      out.add('the last row ends at $lowest, in the bottom bar');
    }
    return out;
  }

  testWidgets('every Home list ends clear of the floating buttons and the '
      'bottom bar (portrait, gesture and 3-button bars)', (tester) async {
    final m = HomeMatrix(tester, 'ja', run);
    await m.begin();
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetDisplayFeatures);
    addTearDown(tester.view.resetSystemGestureInsets);
    final problems = <String>[];
    final ends = <String, Map<double, double>>{};
    try {
      await m.start();
      await m.seedRich();
      await m.seedMoreCuts(8);
      // 作品一覧・共有の2つの一覧も、縦のスマホで送れるだけの数にする。
      await tester.runAsync(() async {
        final exports = await ExportStorage.createManagedDirectory();
        for (var i = 1; i <= 12; i++) {
          File(
            '${exports.path}/clip_${i.toString().padLeft(2, '0')}.mp4',
          ).writeAsBytesSync(List<int>.filled(256, i));
        }
        ExportStorage.invalidate();
        await ExportEngine.listExportedFiles(forceRefresh: true);
        final cuts = m.projects.projects
            .where((p) => p.name.startsWith('カット'))
            .take(10)
            .toList();
        for (final project in cuts) {
          final saved = await m.projects.createOutgoingShare(project: project);
          final data = await NiaproSerializer.loadShare(saved.path);
          await m.projects.importSharedProject(data);
        }
      });
      await m.frames(4);
      await m.settleIo();
      await m.resize(const Size(390, kHomeMatrixPhoneHeight));
      final cells = <(String, HomeView, ProjectViewMode?)>[
        ('projects grid', HomeView.projects, null),
        ('projects detail', HomeView.projects, ProjectViewMode.detail),
        ('works', HomeView.works, null),
        ('works detail', HomeView.works, ProjectViewMode.detail),
        ('received', HomeView.sharedReceived, null),
        ('received detail', HomeView.sharedReceived, ProjectViewMode.detail),
        ('created', HomeView.sharedOutgoing, null),
        ('trash', HomeView.trash, null),
      ];
      for (final (top, bottom) in const [
        (0.0, 0.0),
        (47.0, 34.0),
        (24.0, 48.0),
      ]) {
        applyBottom(tester, top, bottom);
        await m.frames(3);
        for (final (name, view, mode) in cells) {
          await m.show(view);
          if (mode != null) await m.chooseViewMode(mode);
          final end = await toEnd(m);
          (ends[name] ??= {})[bottom] = end;
          for (final p in overlaps(
            m,
            bottom,
            minimumFabGap: mode?.isDetail == true ? 8 : 0,
          )) {
            problems.add('$name, bottom bar $bottom: $p');
          }
          await m.capture('end_${name.replaceAll(' ', '_')}_bottom$bottom');
          content(m)?.position.jumpTo(0);
          await m.frames(2);
          if (mode != null) await m.chooseViewMode(ProjectViewMode.small);
        }
      }
    } finally {
      debugDisableShadows = true;
    }
    debugPrint('scroll ends: $ends');
    // 一覧の末尾の余白は、帯の分だけ増える（スクロールする一覧）。
    for (final MapEntry(key: name, value: end) in ends.entries) {
      final none = end[0.0]!;
      if (end.values.any((e) => e <= 0)) {
        problems.add('$name: the list does not scroll ($end)');
        continue;
      }
      for (final bottom in const [34.0, 48.0]) {
        if ((end[bottom]! - none - bottom).abs() > 0.5) {
          problems.add(
            '$name: the list end grew by ${end[bottom]! - none} '
            'for a $bottom px bottom bar',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'the last Home project row clears the actions in a short PC window',
    (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        await m.setPc(true);
        await m.resize(const Size(1280, 600));
        await m.cell('short', HomeView.projects, captureEnd: true);
        m.expectNoFailures();
      } finally {
        debugDisableShadows = true;
      }
    },
  );
}
