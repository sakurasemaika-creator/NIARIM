import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';

import 'helpers/home_matrix_harness.dart';

/// ホーム画面の表示マトリクス。
///
/// 本物のアプリ（buildAppProviders＋NiarimApp）でホームを開き、次の各セルで
/// 例外・Flexのはみ出し・タブ（アイコン・名前の切れ・幅760px以上で名前が
/// 出ること）・操作ボタン（画面内に収まり、押せる＝ヒットテストで当たる）・
/// 浮かぶボタン（FAB）が一覧の最後の行のメニュー・名前を隠さないこと・
/// 引き出しの全項目を確かめ、目視用に全セルの画像と一覧（manifest.json）を
/// build/home-matrix へ出す（画像は0.5倍）。
///
/// 1. プロジェクトタブ（長い名前・各文字体系・縦長/横長・黒/透明/ベージュの
///    用紙・お気に入り・お気に入りのフォルダ）：24幅×スマホ(844)/PC(900)
///    ×7言語。最後までスクロールした状態も確かめる。
/// 2. 4つのタブ（共有は受け取ったもの・自分が作成したものの2つ）の中身あり・
///    空：境目の幅（320/559/560/640/641/759/760/1280/1920）×7言語。
/// 3. 保存先を読めないとき（プロジェクトの知らせ・作品一覧の失敗・共有と
///    ゴミ箱）。読めないまま「再試行」を押しても知らせが残り、読めるように
///    なってから押すと一覧に替わる。
/// 4. 読み込み中（作品一覧・ゴミ箱）。
/// 5. 文字の大きさ1.3・2.0倍（320/360/390/760）の全タブと、320の引き出し。
/// 6. 低い画面（320x568・640x360・1280x600）の全タブと引き出し。
/// 7. ダークの組み込みテーマ・メニューが暗い自作テーマ（390・1280）の
///    全タブと引き出し。
/// 8. 検索で見つからない・お気に入りだけで空・選択中の操作バー・引き出し
///    （320/559/560/760/1280）。
/// 9. 表示サイズ（大・中・小・詳細）を選んだとき（360/390/430/1280）。
/// 10. 初回の案内（first_launch未保存）と、見たことを保存できなかったとき
///    （320・640x360・760・1280・320の2倍）。
/// あわせて、境目（559/560・640/641・759/760）の前後を1pxずつ、全体を
/// 80pxずつ往復して、連続して幅を変えても崩れないことを確かめ、検索・選択・
/// フォルダ・スクロール位置を保ったまま境目（と表示サイズが替わる600/1000）を
/// 1pxずつ往復し、PCモードを切り替えても、その状態が残ることを確かめる。
///
/// 各セルで必ずある操作（上部バー・浮かぶボタン・絞り込み・並び替え・共有の
/// 切り替え・ゴミ箱の種類）がちょうど1つずつあって押せること、プロジェクトの
/// 列数が表示サイズ（選んでいなければ幅で決まる大きさ）どおりであることも
/// 確かめる。カードの丸い「⋮」（メニュー）がどのカードでもメニューの
/// 文字色で描かれていることも、全セルで確かめる。
///
/// 以前の既知の不具合（ゴミ箱へ移したフォルダ、保存先を読めないときに
/// 「空です」と出るだけの共有・ゴミ箱、その言語でないラベル、選んでいない
/// タブのアイコンのコントラスト、大きな文字で縮んだ共有の切り替え、上部バーの
/// 画面名の省略）の見え方は、manifest.jsonの`observations`へ記録し、
/// 既知の不具合の表（[_knownDefects]）が見込んだセルでだけ許す。どれも今の
/// ホームで直っていて表は空なので、出たら失敗になる。見込んだセルで
/// 出なくなったとき（直った・作りが変わった）も失敗にする（表を直すこと）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(_run.writeManifest);

  for (final language in _languages) {
    testWidgets('seeded Home ($language): Projects at 24 widths x phone/PC, '
        'the other tabs and the states at the boundary widths', (tester) async {
      final m = _HomeMatrix(tester, language, _run);
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        for (final pc in const [false, true]) {
          await m.setPc(pc);
          for (final w in _widths) {
            await m.resize(Size(w.toDouble(), pc ? _pcHeight : _phoneHeight));
            await m.cell(
              'projects',
              _View.projects,
              captureEnd: _boundaryWidths.contains(w),
            );
            // 境目の幅は、その幅の本来のモード（760px未満はスマホ）で撮る。
            if (pc != (w >= 760)) continue;
            if (_boundaryWidths.contains(w)) {
              for (final view in _View.values.skip(1)) {
                await m.cell('tabs', view, captureEnd: true);
              }
              await m.show(_View.projects);
            }
            if (_stateWidths.contains(w)) await m.stateCells();
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    });

    testWidgets(
      'seeded Home ($language): large text, short screens, themes and '
      'continuous resizing',
      (tester) async {
        final m = _HomeMatrix(tester, language, _run);
        await m.begin();
        try {
          await m.start();
          await m.seedRich();
          await m.setPc(false);
          for (final scale in const [1.3, 2.0]) {
            await m.setTextScale(scale);
            for (final w in const [320, 360, 390, 760]) {
              await m.resize(Size(w.toDouble(), _phoneHeight));
              for (final view in _View.values) {
                await m.cell('scale', view);
              }
              if (w == 320) await m.drawerCell('scale');
            }
          }
          await m.setTextScale(1);
          for (final (size, pc) in _shortScreens) {
            await m.setPc(pc);
            await m.resize(size);
            for (final view in _View.values) {
              await m.cell('short', view);
            }
            await m.drawerCell('short');
          }
          await m.show(_View.projects);
          for (final theme in const ['dark', 'custom']) {
            await m.applyTheme(theme);
            for (final (w, pc) in const [(390, false), (1280, true)]) {
              await m.setPc(pc);
              await m.resize(Size(w.toDouble(), pc ? _pcHeight : _phoneHeight));
              for (final view in _View.values) {
                await m.cell('theme', view);
              }
              await m.show(_View.projects);
              await m.drawerCell('theme');
            }
          }
          await m.applyTheme('default');
          await m.resizeSweep();
          // 表示サイズ（大・中・小・詳細）を選んだとき。選ぶと保存され、
          // 以後は幅で決まる大きさに戻らないので最後に撮る。どの幅でも
          // 大・中・小で列数が違う（大が最も少ない）。
          for (final (w, pc) in const [
            (360, false),
            (390, false),
            (430, false),
            (1280, true),
          ]) {
            await m.setPc(pc);
            await m.resize(Size(w.toDouble(), pc ? _pcHeight : _phoneHeight));
            final columns = <ProjectViewMode, int?>{
              for (final mode in ProjectViewMode.values)
                mode: await m.viewModeCell(mode),
            };
            m.expectColumnOrder(columns);
          }
        } finally {
          debugDisableShadows = true;
        }
        m.expectNoFailures();
      },
    );

    testWidgets('seeded Home ($language): search, selection, folder and '
        'scroll position kept while resizing and switching PC mode', (
      tester,
    ) async {
      final m = _HomeMatrix(tester, language, _run);
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        // どの幅でも一覧が何行も送れるだけの数（スクロール位置が1行より
        // 大きく動いたかを見分けるため）。
        await m.seedMoreCuts(40);
        await m.keptStateSweep();
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    });

    testWidgets('empty Home ($language): the first-launch notice, every tab '
        'at the boundary widths, short screens and large text', (tester) async {
      final m = _HomeMatrix(tester, language, _run, contents: _Contents.empty);
      await m.begin();
      try {
        // 初めて開いたホームには案内が出る。閉じてから空のホームを撮る。
        await m.start(firstLaunch: true);
        await m.firstLaunchCells();
        for (final w in _boundaryWidths) {
          await m.setPc(w >= 760);
          await m.resize(
            Size(w.toDouble(), w >= 760 ? _pcHeight : _phoneHeight),
          );
          for (final view in _View.values) {
            await m.cell('empty', view);
          }
        }
        for (final (size, pc) in _shortScreens) {
          await m.setPc(pc);
          await m.resize(size);
          for (final view in _View.values) {
            await m.cell('emptyshort', view);
          }
        }
        await m.setPc(false);
        await m.setTextScale(2);
        for (final w in const [320, 390]) {
          await m.resize(Size(w.toDouble(), _phoneHeight));
          for (final view in _View.values) {
            await m.cell('emptyscale', view);
          }
        }
        await m.setTextScale(1);
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    });

    testWidgets('Home whose storage cannot be read ($language): '
        'every tab at the boundary widths, then Retry', (tester) async {
      final m = _HomeMatrix(
        tester,
        language,
        _run,
        contents: _Contents.failing,
      );
      await m.begin();
      try {
        await m.start(failing: true);
        for (final w in _boundaryWidths) {
          await m.setPc(w >= 760);
          await m.resize(
            Size(w.toDouble(), w >= 760 ? _pcHeight : _phoneHeight),
          );
          for (final view in _View.values) {
            await m.cell('error', view);
          }
        }
        await m.setPc(false);
        await m.resize(const Size(640, 360));
        for (final view in _View.values) {
          await m.cell('errorshort', view);
        }
        await m.setTextScale(2);
        await m.resize(const Size(320, _phoneHeight));
        for (final view in _View.values) {
          await m.cell('errorscale', view);
        }
        await m.setTextScale(1);
        await m.retryCells();
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    });
  }

  testWidgets('Home while the works and trash lists are still loading', (
    tester,
  ) async {
    final m = _HomeMatrix(tester, 'ja', _run, contents: _Contents.loading);
    await m.begin();
    try {
      await m.start();
      // 書類フォルダの答えを止めて、一覧の読み込みを終わらせない。
      m.holdDocuments = Completer<void>();
      ExportStorage.invalidate();
      for (final language in _languages) {
        await m.setLanguage(language);
        for (final w in const [320, 760, 1280]) {
          await m.setPc(w >= 760);
          await m.resize(
            Size(w.toDouble(), w >= 760 ? _pcHeight : _phoneHeight),
          );
          for (final view in const [_View.works, _View.trash]) {
            await m.cell('loading', view);
          }
        }
      }
      // 答えが返れば、読み込み中の表示は空の一覧に替わる。
      m.holdDocuments!.complete();
      m.holdDocuments = null;
      m.contents = _Contents.empty;
      for (final view in const [_View.works, _View.trash]) {
        await m.cell('loaded', view);
      }
    } finally {
      debugDisableShadows = true;
    }
    m.expectNoFailures();
  });
}

// 表示マトリクスの道具（helpers/home_matrix_harness.dart）の短い名前。
typedef _HomeMatrix = HomeMatrix;
typedef _View = HomeView;
typedef _Contents = HomeContents;
const _languages = kHomeMatrixLanguages;
const _widths = kHomeMatrixWidths;
const _boundaryWidths = kHomeMatrixBoundaryWidths;
const _stateWidths = kHomeMatrixStateWidths;
const _phoneHeight = kHomeMatrixPhoneHeight;
const _pcHeight = kHomeMatrixPcHeight;
const _shortScreens = kHomeMatrixShortScreens;

/// 以前の既知の不具合は、どれも今のホームで直っている（どれかの観察が
/// 出たら「not a known defect」で落ちる）：
/// - D1 ゴミ箱へフォルダごと移したフォルダがフォルダとして出ず、中の作品が
///   1件ずつの行に出た → フォルダのカード1つに中身ごと出る（所有者の判断2・
///   A006）。
/// - D2 保存先を読めないとき、共有の2つの一覧とゴミ箱が「空です」とだけ
///   出た → 知らせと「再試行」（DISC082〜086・A003-D2。[_expectedContent]で
///   確かめる）。
/// - D3 ゴミ箱の種類・共有の2つの一覧の名前が手書きの表で英語・簡体字の
///   まま → 7言語のARB（所有者の判断10）。
/// - D4 メニューが暗い自作テーマで、選んでいないタブのアイコンが上部バーの
///   上で1:1前後。
/// - D5 共有の切り替えを大きな文字で8割未満まで縮めた → 入らない幅では
///   アイコンだけにして縮めない（所有者の判断3）。
/// - D6 上部バーの画面名を320/360pxで省略記号で切った → 入らないときは
///   出さない（所有者の判断4）。
final _knownDefects = <HomeMatrixKnownDefect>[];

final _run = HomeMatrixRun(
  Directory('build/home-matrix'),
  knownDefects: _knownDefects,
);
