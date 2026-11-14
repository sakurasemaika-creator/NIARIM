import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:niarim/widgets/collection_tile_layout.dart';
import 'package:niarim/widgets/empty_state_placeholder.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

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

  setUpAll(() => _out.createSync(recursive: true));
  tearDownAll(() {
    File('${_out.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'cells': _results.where((r) => r['image'] != null).length,
        'resizeSteps': _results.where((r) => r['group'] == 'resize').length,
        'failures': [
          for (final r in _results)
            if ((r['problems']! as List).isNotEmpty)
              '${r['cell']}: ${(r['problems']! as List).join(' | ')}',
        ],
        'observations': [
          for (final r in _results)
            if ((r['observations']! as List).isNotEmpty)
              '${r['cell']}: ${(r['observations']! as List).join(' | ')}',
        ],
        'knownDefects': {
          for (final d in _knownDefects)
            d.id: {
              'summary': d.summary,
              'cells': _results
                  .where((r) => (r['knownDefects']! as List).contains(d.id))
                  .length,
            },
        },
        'results': _results,
      }),
    );
  });

  for (final language in _languages) {
    testWidgets('seeded Home ($language): Projects at 24 widths x phone/PC, '
        'the other tabs and the states at the boundary widths', (tester) async {
      final m = _HomeMatrix(tester, language);
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
        final m = _HomeMatrix(tester, language);
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
      final m = _HomeMatrix(tester, language);
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
      final m = _HomeMatrix(tester, language, contents: _Contents.empty);
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
      final m = _HomeMatrix(tester, language, contents: _Contents.failing);
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
    final m = _HomeMatrix(tester, 'ja', contents: _Contents.loading);
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

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
const _widths = [
  320, 360, 375, 390, 430, 480, 520, 559, 560, 600, 640, 641, 700, //
  759, 760, 834, 900, 1024, 1180, 1280, 1366, 1440, 1600, 1920,
];
const _boundaryWidths = [320, 559, 560, 640, 641, 759, 760, 1280, 1920];
const _stateWidths = {320, 559, 560, 760, 1280};
const _phoneHeight = 844.0;
const _pcHeight = 900.0;
const _shortScreens = [
  (Size(320, 568), false),
  (Size(640, 360), false),
  (Size(1280, 600), true),
];

final _out = Directory('build/home-matrix');
final _results = <Map<String, Object?>>[];
var _fontsLoaded = false;
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

/// 撮る画面。共有タブは「受け取ったもの」「自分が作成したもの」の2つ。
enum _View { projects, works, sharedReceived, sharedOutgoing, trash }

/// その回のホームの中身（各画面が本当にその状態かを確かめるのに使う）。
enum _Contents { seeded, empty, failing, loading }

/// 種で入れる作品（名前・用紙の色・縦長・お気に入り）。韓国語・中国語の名前は
/// 同梱のサブセットフォントにある字だけで作る（無い字は豆腐で撮れてしまう）。
const _seededProjects = [
  ('夕暮れの街を歩く猫と少女の長い長いアニメーション（第二部・完結編）', 0xFF000000, false, true),
  ('Walk cycle', 0xFFFFFFFF, false, false),
  ('ポーズ集', 0x00000000, true, false),
  (
    'Une très longue séquence d’animation pour le festival d’été',
    0xFFF3EAD6,
    false,
    false,
  ),
  ('애니메이션 연습 장면과 표정 연습 모음', 0xFF000000, true, false),
  ('背景动画与人物动作的最终版本（第二稿）', 0xFFFFFFFF, false, true),
  (
    'Ciclo de caminata con sombras largas y viento del norte',
    0xFF1E2A44,
    false,
    false,
  ),
  ('動畫專案的最終版本與分鏡測試', 0x00000000, true, false),
  ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJ', 0xFFF3EAD6, true, false),
];
const _seriesFolder = 'シリーズ';
const _favouriteProject = '背景动画与人物动作的最终版本（第二稿）';
const _trashedFolder = 'ゴミ箱へ移したフォルダ';
const _trashedFolderProject = '移したフォルダの中の作品';
const _noMatchQuery = 'zzqx';

/// 一覧のカードで省略されない、種で入れた短い名前（とカットの名前）。
const _shortSeededNames = {
  _seriesFolder,
  'Walk cycle',
  'ポーズ集',
  'シーン01',
  'シーン02 夜',
};
final _seededCut = RegExp(r'^カット\d+$');

/// 幅を続けて変えても残るはずの状態。
enum _Kept { search, selection, folder, scroll }

// ─── 直していない既知の不具合 ─────────────────────────────────────────

// 観察の文（manifest.jsonのobservations）。表と見張りで同じ文を使う。
const _obsEmptyWhenUnreadable =
    'storage could not be read, but the tab shows an empty list '
    '(no notice, no retry)';
const _obsTrashedFolderHidden =
    'a folder moved to the trash with its contents is not shown as a folder';
const _obsTrashedFolderLoose =
    'a project moved to the trash with its folder is listed on its own '
    'with restore/delete';
const _obsForeignLabels = 'labels not in this language: ';
const _obsTabContrast = 'unselected tab icons have ';
const _obsMenuGlyphRole =
    'a card\'s round menu button is not in the menu text colour: ';
const _obsShrunkSwitch = 'shared received/created switch drawn at ';
const _obsTitleCut = 'app bar title cut ';

/// 直していない既知の不具合。セルで観察した見え方は、[expected]がその
/// セルで見込んだものだけを許す。表に無い見え方が出たら失敗、見込んだセルで
/// 出なくなったら（直った・作りが変わった）表を直すよう失敗にする。
class _KnownDefect {
  const _KnownDefect(this.id, this.summary, this.expected);

  final String id;
  final String summary;

  /// そのセル（[_HomeMatrix]の今の言語・幅・文字の大きさ・テーマ・中身と
  /// [_View]）で出るはずの観察の文（先頭の一致で比べる）。出ないなら空。
  final List<String> Function(_HomeMatrix m, _View view) expected;
}

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
final _knownDefects = <_KnownDefect>[];

/// 表示サイズを選んでいないときの大きさ（幅600未満は小・1000未満は中・
/// それ以上は大）。
ProjectViewMode _defaultViewMode(double width) => width < 600
    ? ProjectViewMode.small
    : width < 1000
    ? ProjectViewMode.medium
    : ProjectViewMode.large;

/// 表示サイズ（大・中・小）のカードの基準の幅（プロジェクトの一覧と同じ）。
double _targetExtent(ProjectViewMode mode) => switch (mode) {
  ProjectViewMode.large => kCollectionTileLargeExtent,
  ProjectViewMode.medium => kCollectionTileMediumExtent,
  _ => kCollectionTileSmallExtent,
};

/// 描く文から語結合子（行の途中で折り返さない印）を除くと[text]になる文。
/// 失敗の文は、韓国語の語と押すボタンの名前を折り返さないよう、描く文に
/// だけ語結合子を入れている（読み上げは元の文）。
Finder _drawnText(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ??
                  widget.textSpan?.toPlainText(includeSemanticsLabels: false))
              ?.replaceAll('\u2060', '') ==
          text,
);

/// `first_launch`をfalseにする書き込みだけを断れる（falseを返す）保存先。
/// ほかの読み書きはそのまま元の保存先へ渡す。
class _FirstLaunchStore extends SharedPreferencesStorePlatform {
  _FirstLaunchStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;
  bool reject = false;
  int attempts = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.first_launch' && value == false) {
      attempts++;
      if (reject) return Future.value(false);
    }
    return delegate.setValue(valueType, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) => delegate.remove(key);

  @override
  Future<bool> clear() => delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      delegate.clearWithParameters(parameters);
}

class _HomeMatrix {
  _HomeMatrix(this.tester, this.language, {this.contents = _Contents.seeded});

  final WidgetTester tester;
  String language;
  _Contents contents;
  final _boundary = GlobalKey();
  late Directory _directory;
  bool failDocuments = false;
  Completer<void>? holdDocuments;
  late ProjectService projects;
  late SettingsService settings;
  late ThemeService themes;
  late WorkFolderService workFolders;
  Size size = const Size(390, _phoneHeight);
  bool pc = false;
  double textScale = 1;
  String theme = 'default';
  // 表示サイズを選んだら（選んでいなければ幅で決まる大きさ）。
  ProjectViewMode? chosenViewMode;
  late _FirstLaunchStore firstLaunchStore;
  final failures = <String>[];

  AppLocalizations get l10n =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  /// フォント・影・画面の大きさ（テストごとに1回）。
  Future<void> begin() async {
    if (!_fontsLoaded) {
      await loadAppFonts(tester);
      _fontsLoaded = true;
    }
    // テストの既定では影が黒い縁取りで描かれ、実機と違う画面になる。
    // テスト本体の最後で true へ戻す（各テストの finally）。
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// 空の保存先で本物のアプリを起動し、ホームを開く。[failing]なら書類
  /// フォルダを最初から取れない（保存先を読めない端末）。[firstLaunch]なら
  /// 初回の案内を見たことがまだ保存されていない。
  Future<void> start({bool failing = false, bool firstLaunch = false}) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': firstLaunch,
      'language': language,
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final store = _FirstLaunchStore(SharedPreferencesStorePlatform.instance);
    SharedPreferencesStorePlatform.instance = store;
    firstLaunchStore = store;
    addTearDown(() => SharedPreferencesStorePlatform.instance = store.delegate);
    _directory = Directory.systemTemp.createTempSync('niarim_home_matrix_');
    failDocuments = failing;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        final gate = holdDocuments;
        if (gate != null) await gate.future;
        if (failDocuments) return null;
      }
      return _directory.path;
    });
    // 書き出した動画の表紙を作るとき、FFmpegKitが最初に知らせの流れを
    // 購読する。テストの環境にはその実装が無く、購読の失敗が例外として
    // 次のセルに出る（端末には実装がある）。購読だけを受けておく（表紙は
    // 作れず、作品一覧は絵の無いカードのまま）。
    messenger.setMockStreamHandler(
      _ffmpegEventChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() {
      holdDocuments?.complete();
      messenger.setMockMethodCallHandler(_pathChannel, null);
      messenger.setMockStreamHandler(_ffmpegEventChannel, null);
      if (_directory.existsSync()) _directory.deleteSync(recursive: true);
    });
    // 書き出した作品の一覧は前のテストの保存先を覚えているので捨てる。
    ExportStorage.invalidate();
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: RepaintBoundary(key: _boundary, child: const NiarimApp()),
      ),
    );
    await frames(6);
    await settleIo();
    final home = tester.element(find.byType(HomeScreen));
    projects = home.read<ProjectService>();
    settings = home.read<SettingsService>();
    themes = home.read<ThemeService>();
    workFolders = home.read<WorkFolderService>();
  }

  /// 4つのタブすべてに中身を入れる。プロジェクト（長い名前・各文字体系・
  /// 縦長/横長・黒/透明/ベージュの用紙・お気に入り・お気に入りのフォルダ）、
  /// 書き出した作品（フォルダあり）、受け取った共有（共有フォルダあり）と
  /// 自分が作成した共有ファイル、ゴミ箱（作成したプロジェクト・受け取った
  /// 共有・フォルダごと移したフォルダ・書き出した作品・共有ファイル）。
  Future<void> seedRich() async {
    await tester.runAsync(() async {
      final exports = await ExportStorage.createManagedDirectory();
      final still = img.encodePng(img.Image(width: 64, height: 36));
      final gif = img.encodeGif(img.Image(width: 32, height: 32));
      final files = <String, List<int>>{
        'NIARIM_夕暮れの街を歩く猫と少女_2026-11-10_final_render_v12.mp4': List<int>.filled(
          2048,
          7,
        ),
        'walk_cycle_loop.gif': gif,
        'still_frame_042.png': still,
        'festival_teaser_vertical.webm': List<int>.filled(4096, 3),
        'discarded_take_03.mp4': List<int>.filled(512, 1),
      };
      for (final entry in files.entries) {
        File('${exports.path}/${entry.key}').writeAsBytesSync(entry.value);
      }

      final byName = <String, String>{};
      for (final (name, paper, portrait, favourite) in _seededProjects) {
        final project = await projects.createProject(
          name: name,
          fps: 12,
          durationSeconds: 2,
          backgroundColor: paper,
          exportWidth: portrait ? 1080 : 1920,
          exportHeight: portrait ? 1920 : 1080,
        );
        byName[name] = project.id;
        if (favourite) await projects.setFavorite(project.id, true);
      }
      final series = await projects.createFolder(_seriesFolder);
      await projects.toggleFolderFavorite(series.id);
      for (final name in const ['シーン01', 'シーン02 夜']) {
        final project = await projects.createProject(
          name: name,
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await projects.moveToFolder(project.id, series.id);
      }
      await projects.createFolder(
        'Archive of finished commissions with a very long folder name 2026',
      );
      // スマホの幅でも一覧がスクロールするだけの数（最後まで送ったときに
      // 浮かぶボタンが最後の行を隠さないことを確かめるため）。
      for (var i = 1; i <= 10; i++) {
        await projects.createProject(
          name: 'カット${i.toString().padLeft(2, '0')}',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: i.isEven ? 0xFFFFFFFF : 0x00000000,
          exportWidth: 640,
          exportHeight: 360,
        );
      }

      // 自分が作成した共有ファイルと、それを受け取った共有。
      final received = <String>[];
      for (final name in [
        'Walk cycle',
        _favouriteProject,
        'ポーズ集',
        'Une très longue séquence d’animation pour le festival d’été',
      ]) {
        final source = projects.projects.firstWhere(
          (p) => p.id == byName[name],
        );
        final saved = await projects.createOutgoingShare(project: source);
        final data = await NiaproSerializer.loadShare(saved.path);
        received.add((await projects.importSharedProject(data)).id);
      }
      final sharedFolder = await projects.createSharedFolder('受け取った資料');
      await projects.moveToSharedFolder(received[2], sharedFolder.id);
      await projects.deleteProject(received[3]);
      final outgoing = projects.outgoingShares.last;
      await LocalFileTrashService.move(
        File(outgoing.path),
        LocalTrashKind.outgoingShare,
      );
      await projects.refreshOutgoingShares();

      // ゴミ箱：作成したプロジェクト・フォルダごと・書き出した作品。
      final draft = await projects.createProject(
        name: '古い下書き（削除済み）',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFF3EAD6,
      );
      await projects.deleteProject(draft.id);
      final folder = await projects.createFolder(_trashedFolder);
      final inside = await projects.createProject(
        name: _trashedFolderProject,
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFF000000,
      );
      await projects.moveToFolder(inside.id, folder.id);
      await projects.moveFolderToTrash(folder.id);
      await LocalFileTrashService.move(
        File('${exports.path}/discarded_take_03.mp4'),
        LocalTrashKind.exportedWork,
      );

      final workFolder = await workFolders.createFolder('書き出しフォルダ');
      await workFolders.moveFileToFolder('still_frame_042.png', workFolder.id);
      ExportStorage.invalidate();
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });
    await frames(4);
    await settleIo();
  }

  /// 一覧の一番上に、小さなプロジェクトを[count]件足す。
  Future<void> seedMoreCuts(int count) async {
    await tester.runAsync(() async {
      for (var i = 11; i < 11 + count; i++) {
        await projects.createProject(
          name: 'カット$i',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 640,
          exportHeight: 360,
        );
      }
    });
    await frames(4);
    await settleIo();
  }

  Future<void> frames([int count = 8, int ms = 50]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  /// ファイルの読み書き（本物の非同期）を終わらせてから描く。
  Future<void> settleIo([int rounds = 3]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> resize(Size next) async {
    size = next;
    tester.view.physicalSize = next;
    await frames(3, 60);
  }

  Future<void> setPc(bool value) async {
    if (pc == value && settings.forcePcMode == value) return;
    pc = value;
    await tester.runAsync(() => settings.setForcePcMode(value));
    await frames(4);
  }

  Future<void> setTextScale(double value) async {
    textScale = value;
    tester.platformDispatcher.textScaleFactorTestValue = value;
    await frames(3);
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await tester.runAsync(() => settings.setLanguage(value));
    await frames(4);
  }

  Future<void> applyTheme(String name) async {
    theme = name;
    switch (name) {
      case 'dark':
        themes.applyPreset(AppThemePreset.defaultDark.id);
      case 'custom':
        // 用紙は明るく、メニュー（上部バー・引き出し・カード）は暗い自作の色。
        themes.previewCurrent(
          const AppThemePreset(
            id: ThemeService.customCurrentId,
            name: 'Matrix custom',
            accentColor: Color(0xFF2E7D6B),
            textColor: Color(0xFF1F2328),
            buttonTextColor: Color(0xFFFFFFFF),
            menuTextColor: Color(0xFFEDEFF2),
            selectionTextColor: Color(0xFFFFFFFF),
            panelBgColor: Color(0xFFF7F4EC),
            menuBgColor: Color(0xFF1E2430),
            selectionColor: Color(0xFF2E7D6B),
            updateMarkColor: Color(0xFFE0A100),
          ),
        );
      default:
        await tester.runAsync(themes.resetToDefault);
    }
    await frames(4);
  }

  int get tabIndex =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;

  /// タブ（と共有の2つの一覧）を切り替える。タブはタップで切り替え、
  /// 本文の送りが終わるまで何フレームか描く。
  Future<void> show(_View view) async {
    final tab = switch (view) {
      _View.projects => 0,
      _View.works => 1,
      _View.sharedReceived || _View.sharedOutgoing => 2,
      _View.trash => 3,
    };
    if (tabIndex != tab) {
      await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
      await frames(8);
    }
    if (tab == 2) {
      final outgoing = view == _View.sharedOutgoing;
      final control = find.byKey(const Key('sharedDirectionSegmentedControl'));
      if (tester.widget<SegmentedButton<bool>>(control).selected.single !=
          outgoing) {
        await tester.tap(
          find.byKey(
            Key(outgoing ? 'sharedOutgoingFilter' : 'sharedReceivedFilter'),
          ),
        );
        await frames(6);
      }
    }
    // 一覧はファイルを読んでから出る。読み終わる（その回の中身が出る）まで
    // 実時間を進める。
    for (var i = 0; i < 40 && !_ready(view); i++) {
      await settleIo(1);
    }
    await frames(2);
  }

  /// [view]の読み込みが終わったか。
  bool _ready(_View view) {
    bool any(Finder f) => f.evaluate().isNotEmpty;
    int keys(String prefix) => find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(prefix),
        )
        .evaluate()
        .length;
    if (contents == _Contents.loading) return true;
    if (any(find.byType(CircularProgressIndicator))) return false;
    if (contents != _Contents.seeded) return true;
    return switch (view) {
      _View.projects => true,
      _View.works => any(find.byType(ExportedWorkCard)),
      _View.sharedReceived => keys('receivedShareMenu_') > 0,
      _View.sharedOutgoing => keys('outgoingShareMenu_') > 0,
      // ファイルのゴミ箱（書き出した作品・共有ファイル）を読み終えた。
      // いちばん新しい書き出した作品が先頭に来る。
      _View.trash => keys('trash-restore-local-') > 0,
    };
  }

  String cellName(String group, String what) {
    final scale = textScale == 1 ? '' : '_x$textScale';
    final colours = theme == 'default' ? '' : '_$theme';
    final w = size.width.round();
    final h = size.height.round();
    return '${group}_${language}_${pc ? 'pc' : 'sp'}_${w}x$h$scale${colours}_$what';
  }

  /// [view]を開いて確かめ、撮る。最後までスクロールできる一覧は、最後まで
  /// 送った状態でも確かめる（[captureEnd]ならそれも撮る）。
  Future<void> cell(String group, _View view, {bool captureEnd = false}) async {
    await show(view);
    final observations = [..._observations(view), ..._titleCut()];
    final defects = _matchKnownDefects(view, observations);
    await _shoot(
      group,
      view.name,
      problems: {..._expectedContent(view), ...defects.problems},
      observations: observations,
      knownDefects: defects.ids,
      captureEnd: captureEnd,
    );
  }

  /// 観察した見え方を既知の不具合の表と突き合わせる。表に無い見え方と、
  /// 表がこのセルで見込んだのに出なかった見え方を失敗にする。
  ({List<String> problems, List<String> ids}) _matchKnownDefects(
    _View view,
    List<String> observations,
  ) {
    final expected = [
      for (final defect in _knownDefects)
        for (final text in defect.expected(this, view))
          (id: defect.id, text: text),
    ];
    final problems = <String>[];
    final ids = <String>{};
    for (final observation in observations) {
      final known = expected
          .where((e) => observation.startsWith(e.text))
          .firstOrNull;
      if (known == null) {
        problems.add('not a known defect: $observation');
      } else {
        ids.add(known.id);
      }
    }
    for (final e in expected) {
      if (!observations.any((o) => o.startsWith(e.text))) {
        problems.add(
          'known defect ${e.id} no longer shows in this cell '
          '("${e.text}"); update _knownDefects',
        );
      }
    }
    return (problems: problems, ids: ids.toList()..sort());
  }

  /// 上部バーの画面名（タブ名と同じ文）が省略されていないか（記録だけ）。
  List<String> _titleCut() {
    final l10n = this.l10n;
    final title = switch (tabIndex) {
      1 => l10n.homeTabWorks,
      2 => l10n.homeTabShared,
      3 => l10n.homeTabTrash,
      _ => l10n.homeTabProjects,
    };
    for (final e
        in find
            .descendant(of: find.byType(AppBar), matching: find.text(title))
            .evaluate()) {
      var inTabs = false;
      e.visitAncestorElements((a) {
        inTabs = a.widget is TabBar;
        return !inTabs;
      });
      if (inTabs) continue;
      final paragraph = e.renderObject! as RenderParagraph;
      if (paragraph.didExceedMaxLines ||
          paragraph.getMaxIntrinsicWidth(double.infinity) >
              paragraph.size.width + 0.5) {
        return ['$_obsTitleCut"$title"'];
      }
    }
    return const [];
  }

  /// 現在の画面を確かめて撮り、記録する。
  Future<void> _shoot(
    String group,
    String what, {
    required Set<String> problems,
    List<String> observations = const [],
    List<String> knownDefects = const [],
    bool captureEnd = false,
  }) async {
    final name = cellName(group, what);
    problems.addAll(inspect());
    await capture(name);
    final images = ['$name.png'];
    final end = await _scrollEnd(name, capture: captureEnd);
    problems.addAll(end.problems);
    if (end.image != null) images.add(end.image!);
    record(
      name,
      group,
      what,
      images,
      problems.toList(),
      observations,
      knownDefects: knownDefects,
    );
  }

  void record(
    String name,
    String group,
    String what,
    List<String>? images,
    List<String> problems,
    List<String> observations, {
    List<String> knownDefects = const [],
  }) {
    _results.add({
      'cell': name,
      'group': group,
      'language': language,
      'mode': pc ? 'pc' : 'sp',
      'width': size.width.round(),
      'height': size.height.round(),
      'orientation': size.width > size.height ? 'landscape' : 'portrait',
      'textScale': textScale,
      'theme': theme,
      'view': what,
      'image': images?.first,
      'images': images,
      'problems': problems,
      'observations': observations,
      'knownDefects': knownDefects,
    });
    if (problems.isNotEmpty) failures.add('$name: ${problems.join(' | ')}');
  }

  void expectNoFailures() {
    expect(tester.takeException(), isNull);
    expect(failures, isEmpty, reason: failures.join('\n'));
  }

  Future<void> capture(String name) async {
    await tester.runAsync(() async {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 0.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(
        '${_out.path}/$name.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  // ─── 状態のセル（検索・お気に入り・選択・引き出し） ─────────────────────

  Future<void> stateCells() async {
    await show(_View.projects);
    final l10n = this.l10n;

    // 検索で何も見つからない。
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.search),
      ),
    );
    await frames(4);
    await tester.enterText(find.byType(TextField), 'zzqx');
    await frames(4);
    await _shoot(
      'state',
      'nomatch',
      problems: {
        if (find.byIcon(Icons.search_off).evaluate().isEmpty)
          'no-match state not shown',
      },
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.close),
      ),
    );
    await frames(6);

    // お気に入りだけ（中身あり）と、お気に入りの無いフォルダで空。
    final favourites = find.widgetWithText(FilterChip, l10n.homeFavoritesOnly);
    await tester.tap(favourites);
    await frames(4);
    await _shoot(
      'state',
      'favonly',
      problems: {
        if (find.text(_favouriteProject).evaluate().isEmpty)
          'favourite project not listed',
      },
    );
    await tester.tap(favourites);
    await frames(4);
    await _openSeries();
    await tester.tap(favourites);
    await frames(4);
    await _shoot(
      'state',
      'favempty',
      problems: {
        // お気に入りはほかにあるので、「このフォルダにお気に入りは
        // ありません」（A004の空の表示：フォルダの中で絞った）。
        if (find
            .text(l10n.projectListNoFavoritesInFolderTitle)
            .evaluate()
            .isEmpty)
          'favourites-only empty state not shown',
      },
    );
    await tester.tap(find.text(l10n.projectListShowAll));
    await frames(4);
    await tester.tap(find.byTooltip(l10n.projectListFolderRootOption));
    await frames(6);

    // 選択中の操作バー（フォルダと作品を選ぶ。フォルダを含むのでコピーは
    // 押せない）。
    await tester.longPress(await _cardText(_seriesFolder));
    await frames(4);
    await tester.tap(await _cardText(_favouriteProject));
    await frames(4);
    await _shoot('state', 'select', problems: {..._selectionBarProblems()});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(4);
    if (find.byType(HomeSelectionToolbar).evaluate().isNotEmpty) {
      record(
        cellName('state', 'select-escape'),
        'state',
        'select-escape',
        null,
        ['Escape did not end the selection'],
        const [],
      );
      await tester.tap(find.byTooltip(l10n.homeSelectionAllDeselect));
      await frames(4);
    }
    _projectsScrollable()?.position.jumpTo(0);
    await frames(2);

    await drawerCell('state');
  }

  /// 上部バーの表示サイズのメニューで[mode]を選んで撮る。並んだ列数
  /// （詳細ならnull）を返す。
  Future<int?> viewModeCell(ProjectViewMode mode) async {
    await show(_View.projects);
    await tester.tap(find.byType(ProjectViewModeMenu));
    // メニューが開き終わるまで待つ（開く途中のタップは届かない）。
    await frames(6);
    await tester.tap(
      find.byType(PopupMenuItem<ProjectViewMode>).at(mode.index),
    );
    await frames(6);
    chosenViewMode = mode;
    final menu = tester.widget<ProjectViewModeMenu>(
      find.byType(ProjectViewModeMenu),
    );
    final columns = _gridColumns();
    await _shoot(
      'viewsize',
      mode.name,
      problems: {
        if (menu.value != mode) 'view size ${menu.value.name} != ${mode.name}',
        if (mode == ProjectViewMode.detail &&
            find.byType(ListTile).evaluate().isEmpty)
          'detail rows not shown',
        if (mode != ProjectViewMode.detail && columns == null)
          'project grid not shown',
      },
      captureEnd: true,
    );
    return columns;
  }

  /// 大・中・小の列数が、大＜中＜小の順に違う（どれを選んでも見た目が
  /// 変わる）。
  void expectColumnOrder(Map<ProjectViewMode, int?> columns) {
    final large = columns[ProjectViewMode.large];
    final medium = columns[ProjectViewMode.medium];
    final small = columns[ProjectViewMode.small];
    record(
      cellName('viewsize', 'column-order'),
      'viewsize',
      'column-order',
      null,
      [
        if (large == null ||
            medium == null ||
            small == null ||
            !(large < medium && medium < small))
          'columns large=$large medium=$medium small=$small are not '
              'large < medium < small',
      ],
      const [],
    );
  }

  Future<void> _openSeries() async {
    await tester.tap(await _cardText(_seriesFolder));
    await frames(6);
  }

  /// 引き出しを開いて確かめ、撮って閉じる。画面の下に出た行き先は、
  /// 引き出しをスクロールすると押せる所まで来る（来れば最後の位置も撮る）。
  Future<void> drawerCell(String group) async {
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await frames(8);
    final name = cellName(group, 'drawer');
    final problems = {...inspect(drawer: true)};
    await capture(name);
    final images = ['$name.png'];
    final screen = Offset.zero & size;
    var scrolled = false;
    for (final MapEntry(key: link, value: finder) in _drawerLinks().entries) {
      if (finder.evaluate().length != 1) continue;
      if (_contains(screen, tester.getRect(finder))) continue;
      scrolled = true;
      await tester.ensureVisible(finder);
      await frames(2);
      final box = tester.renderObject<RenderBox>(finder);
      final rect = _globalRect(box);
      if (!_contains(screen, rect)) {
        problems.add('drawer link "$link" cannot be scrolled on screen $rect');
      } else if (!_hits(box, rect.center)) {
        problems.add('drawer link "$link" not hit-testable after scrolling');
      }
    }
    if (scrolled) {
      problems.addAll(inspect(drawer: true));
      await capture('${name}_end');
      images.add('${name}_end.png');
    }
    record(name, group, 'drawer', images, problems.toList(), const []);
    final drawer = find.byType(Drawer);
    if (drawer.evaluate().isNotEmpty) {
      Navigator.of(tester.element(drawer)).pop();
      await frames(8);
    }
  }

  // ─── 初回の案内 ─────────────────────────────────────────────────────

  static const _firstLaunchScreens = [
    (Size(320, _phoneHeight), false, 1.0),
    (Size(640, 360), false, 1.0),
    (Size(760, _pcHeight), true, 1.0),
    (Size(1280, _pcHeight), true, 1.0),
    (Size(320, _phoneHeight), false, 2.0),
  ];

  /// 初回の案内を各画面で撮る。見たことの保存を断らせて「はじめる」を押し、
  /// 失敗の知らせ（その言語の文）と「はじめる」が出ることを各画面で撮り、
  /// 保存できるようにして押すと閉じることを確かめる。
  Future<void> firstLaunchCells() async {
    for (final failed in const [false, true]) {
      if (failed) {
        firstLaunchStore.reject = true;
        await _pressFirstLaunchStart();
      }
      for (final (screen, pc, scale) in _firstLaunchScreens) {
        await setPc(pc);
        await resize(screen);
        await setTextScale(scale);
        await _firstLaunchCell(failed: failed);
      }
      await setTextScale(1);
    }
    firstLaunchStore.reject = false;
    await _pressFirstLaunchStart();
    record(cellName('firstlaunch', 'done'), 'firstlaunch', 'done', null, [
      if (find.byType(AlertDialog).evaluate().isNotEmpty)
        'first-launch notice still open after a successful save',
      if (settings.isFirstLaunch) 'first launch not marked as done',
      if (firstLaunchStore.attempts != 2)
        'first_launch written ${firstLaunchStore.attempts} times (want 2)',
      ...inspect(),
    ], const []);
  }

  Future<void> _pressFirstLaunchStart() async {
    final start = _firstLaunchStart();
    if (start.evaluate().length != 1) return;
    await tester.tap(start);
    await frames(6);
    await settleIo(2);
  }

  Finder _firstLaunchStart() => find.ancestor(
    of: find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(l10n.homeFirstLaunchStart),
    ),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  Future<void> _firstLaunchCell({required bool failed}) async {
    final what = failed ? 'savefailed' : 'notice';
    final name = cellName('firstlaunch', what);
    final problems = {...inspect(firstLaunchFailed: failed)};
    await capture(name);
    final images = ['$name.png'];
    // 案内の中身はスクロールする。失敗の文はスクロールすると見える。
    final failure = find.descendant(
      of: find.byType(AlertDialog),
      matching: _drawnText(l10n.homeFirstLaunchSaveFailed),
    );
    if (failed && failure.evaluate().length == 1) {
      final surface = _firstLaunchSurface();
      if (!_contains(surface, tester.getRect(failure))) {
        await tester.ensureVisible(failure);
        await frames(2);
        if (!_contains(_firstLaunchSurface(), tester.getRect(failure))) {
          problems.add('save-failure text cannot be scrolled into view');
        }
        problems.addAll(inspect(firstLaunchFailed: failed));
        await capture('${name}_end');
        images.add('${name}_end.png');
      }
    }
    record(name, 'firstlaunch', what, images, problems.toList(), const []);
  }

  Rect _firstLaunchSurface() => tester.getRect(
    find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first,
  );

  /// 初回の案内：1つだけ画面内にあり、その言語の案内と「はじめる」（押せる）
  /// があり、文が横にはみ出さない。[failed]なら失敗の知らせ（その言語）も
  /// ある。
  List<String> _firstLaunchProblems({required bool failed}) {
    final l10n = this.l10n;
    final dialog = find.byType(AlertDialog);
    final count = dialog.evaluate().length;
    if (count != 1) return ['first-launch notice shown $count times'];
    final screen = Offset.zero & size;
    final surface = _firstLaunchSurface();
    final problems = <String>[
      if (!_contains(screen, surface))
        'first-launch notice off screen $surface',
      if (find
              .descendant(
                of: dialog,
                matching: find.text(l10n.homeFirstLaunchMessage),
              )
              .evaluate()
              .length !=
          1)
        'first-launch message not shown in this language',
    ];
    final failure = find
        .descendant(
          of: dialog,
          matching: _drawnText(l10n.homeFirstLaunchSaveFailed),
        )
        .evaluate()
        .length;
    if (failed && failure != 1) {
      problems.add('save-failure text not shown in this language');
    }
    if (!failed && failure != 0) {
      problems.add('save-failure text shown before a failed save');
    }
    final start = _firstLaunchStart();
    final starts = start.evaluate().length;
    if (starts != 1) {
      problems.add('start button found $starts times');
    } else {
      final button = tester.widget<ButtonStyleButton>(start);
      final box = tester.renderObject<RenderBox>(start);
      final rect = _globalRect(box);
      if (!button.enabled) problems.add('start button disabled');
      if (!_contains(surface, rect) || !_contains(screen, rect)) {
        problems.add('start button outside the notice $rect');
      } else if (!_hits(box, rect.center)) {
        problems.add('start button not hit-testable');
      }
    }
    for (final e
        in find
            .descendant(of: dialog, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = e.renderObject! as RenderParagraph;
      if (!paragraph.hasSize) continue;
      final rect = _globalRect(paragraph);
      if (rect.left < surface.left - 0.5 || rect.right > surface.right + 0.5) {
        problems.add(
          'notice text cut sideways: "${paragraph.text.toPlainText()}"',
        );
      }
    }
    return problems;
  }

  // ─── 保存先を読めないときの「再試行」 ─────────────────────────────────

  /// 読めないまま「再試行」を押しても知らせが残り、読めるようになってから
  /// 押すと一覧（空）に替わる（プロジェクト・作品一覧）。
  Future<void> retryCells() async {
    await setPc(false);
    await resize(const Size(390, _phoneHeight));
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    final works = find.byKey(const PageStorageKey<String>('home-works'));
    final worksFailure = find.text(l10n.homeWorksLoadFailed);
    await show(_View.projects);
    await _pressRetry(notice, notice);
    await _shoot(
      'retry',
      'projects-still-failing',
      problems: {..._expectedContent(_View.projects)},
    );
    await show(_View.works);
    await _pressRetry(works, worksFailure);
    await _shoot(
      'retry',
      'works-still-failing',
      problems: {..._expectedContent(_View.works)},
    );

    failDocuments = false;
    contents = _Contents.empty;
    await _pressRetry(works, worksFailure);
    await _shoot(
      'retry',
      'works-recovered',
      problems: {
        ..._expectedContent(_View.works),
        if (worksFailure.evaluate().isNotEmpty)
          'works failure still shown after a successful retry',
      },
    );
    await show(_View.projects);
    await _pressRetry(notice, notice);
    await _shoot(
      'retry',
      'projects-recovered',
      problems: {
        ..._expectedContent(_View.projects),
        if (notice.evaluate().isNotEmpty)
          'projects failure notice still shown after a successful retry',
      },
    );
  }

  /// [scope]の「再試行」を押し、読み直しが終わるまで待つ。読み直しの間も
  /// 前の失敗の表示が残る（FutureBuilderは前の結果を持ったまま待つ）ので、
  /// [failure]が消えるまで（消えないはずなら決まった回数だけ）待つ。
  Future<void> _pressRetry(Finder scope, Finder failure) async {
    final retry = find.descendant(
      of: scope,
      matching: find.text(l10n.communityRetry),
    );
    // 無ければ、撮るときの確かめ（_expectedContent）が知らせる。
    if (retry.evaluate().length != 1) return;
    await _reveal(retry);
    await frames(2);
    await tester.tap(retry);
    await frames(2);
    await settleIo(6);
    for (var i = 0; i < 20 && !failDocuments; i++) {
      if (failure.evaluate().isEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
      await settleIo(1);
    }
    await frames(2);
  }

  /// プロジェクトの一覧で[text]の項目（遅延して作る一覧なので、無ければ
  /// 作られるまで下へ送る）を、見える所へ出して返す。
  Future<Finder> _cardText(String text) async {
    final finder = find.text(text);
    final scrollable = _projectsScrollable();
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      if (scrollable == null) break;
      final position = scrollable.position;
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        math.min(position.pixels + 300, position.maxScrollExtent),
      );
      await frames(1);
    }
    await _reveal(finder.first);
    return finder.first;
  }

  /// [finder]を、いちばん近い縦のスクロールだけを動かして見える所へ出す。
  /// （tester.ensureVisibleは横に送るタブの本文まで動かし、次のタブが端から
  /// のぞいたままになる。）
  Future<void> _reveal(Finder finder) async {
    final element = finder.evaluate().first;
    final scrollable = _scrollAncestors(
      element,
    ).where((s) => s.position.axis == Axis.vertical).firstOrNull;
    if (scrollable != null) {
      await scrollable.position.ensureVisible(
        element.renderObject!,
        alignment: 0.5,
      );
    }
    await frames(2);
  }

  /// タブの本文（横に送る一覧）がちょうど今のタブの位置にあり、隣のタブが
  /// 端からのぞいていない。
  List<String> _pageProblems() {
    for (final e
        in find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.byType(Scrollable),
            )
            .evaluate()) {
      final state = (e as StatefulElement).state as ScrollableState;
      final position = state.position;
      if (position.axis != Axis.horizontal) continue;
      if (!position.hasPixels || !position.hasViewportDimension) continue;
      final page = position.pixels / position.viewportDimension;
      if ((page - tabIndex).abs() * position.viewportDimension > 0.5) {
        return ['tab pages sit at ${page.toStringAsFixed(3)}, not $tabIndex'];
      }
      return const [];
    }
    return const [];
  }

  // ─── 確かめること ───────────────────────────────────────────────────

  /// その回の中身が本当に画面に出ているか（撮る画面を取り違えていないか）。
  List<String> _expectedContent(_View view) {
    final l10n = this.l10n;
    bool any(Finder f) => f.evaluate().isNotEmpty;
    bool hasKey(String prefix) => any(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(prefix),
      ),
    );
    final empty = any(find.byType(EmptyStatePlaceholder));
    return switch ((contents, view)) {
      // 並び順（既定は更新日時の新しい順）はフォルダと作品を一緒に並べる
      // ので、低い画面では後から足したカットだけが作られていることがある。
      (_Contents.seeded, _View.projects) => [
        if (!any(
          // カードの名前は、読み上げの名前に名前の全部を持つText.rich。
          find.byWidgetPredicate((w) {
            if (w is! Text) return false;
            final name = w.data ?? w.textSpan?.toPlainText() ?? '';
            return _shortSeededNames.contains(name) ||
                _seededCut.hasMatch(name);
          }),
        ))
          'seeded projects not listed',
      ],
      (_Contents.seeded, _View.works) => [
        if (!any(find.byType(ExportedWorkCard))) 'exported works not listed',
      ],
      (_Contents.seeded, _View.sharedReceived) => [
        if (!hasKey('receivedShareMenu_')) 'received shares not listed',
      ],
      (_Contents.seeded, _View.sharedOutgoing) => [
        if (!hasKey('outgoingShareMenu_')) 'created share files not listed',
      ],
      // フォルダごと移したフォルダは、中身ごと1つのカードで出す（所有者の
      // 判断2・A006）。中の作品の名前はそのカードの中にだけ出る。
      (_Contents.seeded, _View.trash) => [
        if (!hasKey('trash-restore-')) 'trash not listed',
        if (!hasKey('trashedFolder_')) 'trashed folder card not listed',
      ],
      (_Contents.empty, _View.projects) => [
        if (!any(find.text(l10n.projectListEmptyTitle)))
          'empty projects state not shown',
      ],
      (_Contents.empty, _View.works) => [
        if (!any(find.text(l10n.homeWorksEmpty))) 'empty works state not shown',
      ],
      (_Contents.empty, _View.sharedReceived) => [
        if (!any(find.text(l10n.homeSharedEmpty)))
          'empty received shares state not shown',
      ],
      (_Contents.empty, _View.sharedOutgoing) => [
        if (!empty) 'empty created shares state not shown',
      ],
      (_Contents.empty, _View.trash) => [
        if (!any(find.text(l10n.homeTrashEmpty))) 'empty trash state not shown',
      ],
      (_Contents.failing, _View.projects) => _failureProblems(
        'projects load failure notice',
        find.byKey(const Key('homeProjectsLoadFailed')),
        l10n.homeProjectsLoadFailed,
      ),
      (_Contents.failing, _View.works) => _failureProblems(
        'works load failure',
        find.byKey(const PageStorageKey<String>('home-works')),
        l10n.homeWorksLoadFailed,
      ),
      // 共有の2つの一覧とゴミ箱も、「空です」ではなく知らせと「再試行」
      // （以前の既知の不具合D2。DISC082〜086・A003-D2で直った）。
      (_Contents.failing, _View.sharedReceived) => _failureProblems(
        'shared load failure notice',
        find.byKey(const Key('sharedProjectsLoadFailed')),
        l10n.homeProjectsLoadFailed,
      ),
      (_Contents.failing, _View.sharedOutgoing) => _failureProblems(
        'created shares load failure notice',
        find.byKey(const Key('outgoingSharesLoadFailed')),
        l10n.homeOutgoingSharesLoadFailed,
      ),
      (_Contents.failing, _View.trash) => _failureProblems(
        'trash load failure notice',
        find.byKey(const Key('trashProjectsLoadFailed')),
        l10n.homeProjectsLoadFailed,
      ),
      (_Contents.loading, _) => [
        if (!any(find.byType(CircularProgressIndicator)))
          'loading indicator not shown',
      ],
    };
  }

  /// 読み込めなかった知らせ：[scope]の中に、その言語の[message]と押せる
  /// 「再試行」（その言語）が1つずつある。
  List<String> _failureProblems(String what, Finder scope, String message) {
    final scopes = scope.evaluate().length;
    if (scopes != 1) return ['$what not shown (found $scopes)'];
    final texts = find
        .descendant(of: scope, matching: find.text(message))
        .evaluate()
        .length;
    final retry = find.ancestor(
      of: find.descendant(of: scope, matching: find.text(l10n.communityRetry)),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final retries = retry.evaluate().length;
    return [
      if (texts != 1) '$what: "$message" shown $texts times',
      if (retries != 1)
        '$what: Retry button "${l10n.communityRetry}" found $retries times'
      else ...[
        if (!tester.widget<ButtonStyleButton>(retry).enabled)
          '$what: Retry disabled',
        ?_operableProblem('$what Retry', retry),
      ],
    ];
  }

  /// 失敗にはしないが、記録しておく見え方（既知の不具合の表と突き合わせる）。
  List<String> _observations(_View view) {
    final empty = find.byType(EmptyStatePlaceholder).evaluate().isNotEmpty;
    return [
      if (contents == _Contents.failing &&
          view.index >= _View.sharedReceived.index &&
          empty)
        _obsEmptyWhenUnreadable,
      if (contents == _Contents.seeded && view == _View.trash) ...[
        if (find.text(_trashedFolder).evaluate().isEmpty)
          _obsTrashedFolderHidden,
        if (_listedOutsideFolderCard(_trashedFolderProject))
          _obsTrashedFolderLoose,
      ],
      ..._foreignLabels(),
      ..._tabContrast(),
      ..._menuGlyphRoles(),
      ..._shrunkSharedSwitch(),
    ];
  }

  /// [name]が、ゴミ箱のフォルダのカード（中身の名前を並べる）の外に、
  /// 自分の行として出ているか。
  bool _listedOutsideFolderCard(String name) =>
      find.text(name).evaluate().any((e) {
        var inFolderCard = false;
        e.visitAncestorElements((a) {
          final key = a.widget.key;
          inFolderCard =
              key is ValueKey<String> && key.value.startsWith('trashedFolder_');
          return !inFolderCard;
        });
        return !inFolderCard;
      });

  /// 手書きのラベル表（ゴミ箱の種類・共有の2つの一覧）が、その言語の文でなく
  /// 英語・簡体字のまま出ていないか（記録だけ）。
  List<String> _foreignLabels() {
    const english = {
      'Created project',
      'Received share',
      'Created share',
      'Exported work',
      'Received',
      'Created by me',
    };
    const simplified = {
      '创建的项目',
      '收到的共享文件',
      '创建的共享文件',
      '导出的作品',
      '收到的文件',
      '我创建的文件',
    };
    final shown = <String>[
      for (final kind in const [
        'createdProject',
        'receivedShare',
        'createdShare',
        'exportedWork',
      ])
        for (final e
            in find
                .descendant(
                  of: find.byKey(ValueKey('trashKind_$kind')),
                  matching: find.byType(Text),
                )
                .evaluate())
          (e.widget as Text).data ?? '',
      // 共有の切り替えは、入らない幅ではアイコンだけになる（所有者の判断3）。
      // そのときは読み上げの名前（長押しで出る名前と同じ）を見る。
      for (final key in const ['sharedReceivedFilter', 'sharedOutgoingFilter'])
        for (final e in find.byKey(Key(key)).evaluate())
          switch (e.widget) {
            Text(:final data) => data ?? '',
            Icon(:final semanticLabel) => semanticLabel ?? '',
            final other => '${other.runtimeType}',
          },
    ];
    final foreign = [
      for (final text in shown)
        if ((language != 'en' && english.contains(text)) ||
            (language == 'zh_Hant' && simplified.contains(text)))
          text,
    ];
    return [
      if (foreign.isNotEmpty) '$_obsForeignLabels${foreign.toSet().join(', ')}',
    ];
  }

  /// 選んでいないタブのアイコンが上部バーの地の色の上で見えるか（WCAGの
  /// 部品のコントラスト3:1、記録だけ）。
  List<String> _tabContrast() {
    final bar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(Material),
    );
    if (bar.evaluate().isEmpty) return const [];
    final background = tester.widget<Material>(bar.first).color;
    if (background == null) return const [];
    var worst = double.infinity;
    for (var i = 0; i < 4; i++) {
      if (i == tabIndex) continue;
      final icons = find
          .descendant(
            of: find.byKey(ValueKey('home_tab_$i')),
            matching: find.byType(Icon),
          )
          .evaluate();
      if (icons.isEmpty) continue;
      final icon = icons.first;
      final colour = (icon.widget as Icon).color ?? IconTheme.of(icon).color;
      if (colour == null) continue;
      worst = math.min(
        worst,
        _contrast(Color.alphaBlend(colour, background), background),
      );
    }
    return [
      if (worst < 3)
        '$_obsTabContrast${worst.toStringAsFixed(2)}:1 contrast '
            'on the app bar',
    ];
  }

  /// カードの丸い操作のうち「⋮」（メニュー）は、どのカードでもメニューの
  /// 文字色（上部バー・メニューの項目と同じ役目）で描く。1か所だけ本文の
  /// 文字色で描くと、本文とメニューで色を分けたテーマでそのカードの「⋮」
  /// だけ色が違い、メニューが暗い自作テーマでは見えなくなった。
  List<String> _menuGlyphRoles() {
    final wrong = <String>{};
    for (final e in find.byIcon(Icons.more_vert).evaluate()) {
      var inFrame = false;
      e.visitAncestorElements((a) {
        inFrame = a.widget is CollectionActionFrame;
        return !inFrame;
      });
      if (!inFrame) continue;
      final drawn = (e.widget as Icon).color ?? IconTheme.of(e).color;
      final menu = Theme.of(e).popupMenuTheme.iconColor;
      if (drawn != menu) {
        wrong.add(
          '0x${drawn?.toARGB32().toRadixString(16)} instead of '
          '0x${menu?.toARGB32().toRadixString(16)}',
        );
      }
    }
    return [if (wrong.isNotEmpty) '$_obsMenuGlyphRole${wrong.join(', ')}'];
  }

  static double _contrast(Color a, Color b) {
    double channel(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    double luminance(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    final la = luminance(a);
    final lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// 共有の2つの一覧の切り替えは収まらないと縮めて描く。大きな文字で
  /// 元の大きさの8割未満まで縮んでいないか（記録だけ）。
  List<String> _shrunkSharedSwitch() {
    final control = find.byKey(const Key('sharedDirectionSegmentedControl'));
    if (control.evaluate().isEmpty) return const [];
    final box = tester.renderObject<RenderBox>(control);
    final drawn = _globalRect(box).width;
    final scale = box.size.width == 0 ? 1.0 : drawn / box.size.width;
    return [
      if (scale < 0.8) '$_obsShrunkSwitch${(scale * 100).round()}% of its size',
    ];
  }

  /// 1つの画面の確かめ。[firstLaunchFailed]を渡すと、ホームの上の初回の
  /// 案内（保存に失敗した後か）を確かめる。
  List<String> inspect({
    bool drawer = false,
    bool atEnd = false,
    bool? firstLaunchFailed,
  }) {
    final problems = <String>[];
    final error = tester.takeException();
    if (error != null) {
      problems.add('exception: ${'$error'.split('\n').first}');
    }
    problems.addAll(_flexOverflows());
    final screen = Offset.zero & size;
    if (firstLaunchFailed != null) {
      problems.addAll(_firstLaunchProblems(failed: firstLaunchFailed));
      return problems;
    }
    if (drawer) {
      problems.addAll(_drawerProblems(screen));
      problems.addAll(
        _actionProblems(find.byType(Drawer), screen, fabRule: false),
      );
      return problems;
    }
    problems.addAll(_tabProblems(screen));
    problems.addAll(_pageProblems());
    problems.addAll(
      _actionProblems(find.byType(HomeScreen), screen, atEnd: atEnd),
    );
    if (atEnd) {
      problems.addAll(_textUnderFab(screen));
    } else {
      problems.addAll(_requiredControlProblems());
      problems.addAll(_gridProblems());
    }
    return problems;
  }

  /// 今出ている画面（タブと、共有のどちらの一覧か）。
  _View get currentView {
    switch (tabIndex) {
      case 0:
        return _View.projects;
      case 1:
        return _View.works;
      case 2:
        final control = find.byKey(
          const Key('sharedDirectionSegmentedControl'),
        );
        if (control.evaluate().length == 1 &&
            tester.widget<SegmentedButton<bool>>(control).selected.single) {
          return _View.sharedOutgoing;
        }
        return _View.sharedReceived;
      default:
        return _View.trash;
    }
  }

  /// その画面に必ずある操作。ちょうど1つずつあり、画面内で押せる（スクロール
  /// する一覧の中で外に出ているものは、スクロールすれば届くので許す）。
  /// 選択中は浮かぶボタンを出さない作り。検索中は表示サイズ・検索の代わりに
  /// 閉じる・検索の対象の切り替え・入力欄を出す。
  List<String> _requiredControlProblems() {
    final l10n = this.l10n;
    Finder fab(String heroTag, String tooltip) => find.byWidgetPredicate(
      (w) =>
          w is FloatingActionButton &&
          w.heroTag == heroTag &&
          w.tooltip == tooltip,
    );
    final appBar = find.byType(AppBar);
    Finder appBarButton(String tooltip) => find.descendant(
      of: appBar,
      matching: find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == tooltip,
      ),
    );
    final searchField = find.descendant(
      of: appBar,
      matching: find.byType(TextField),
    );
    final selecting = find.byType(HomeSelectionToolbar).evaluate().isNotEmpty;
    final searching = searchField.evaluate().isNotEmpty;
    final list = find.byType(ProjectListWidget);
    final shared = find.byType(SharedScreen);
    final trash = find.byType(TrashScreen);
    final controls = <String, Finder>{
      'back': find.byKey(const Key('homeBackToSplashButton')),
      'drawer': find.byKey(const Key('homeMenuButton')),
      ...switch (currentView) {
        _View.projects => {
          if (searching) ...{
            'close search': appBarButton(l10n.commonClose),
            'search by tag': appBarButton(l10n.projectDetailTagsQuickAction),
            'search field': searchField,
          } else ...{
            'view size': find.byType(ProjectViewModeMenu),
            'search': appBarButton(l10n.commonSearch),
          },
          // 一覧の先頭の行。スクロールして外に出ても作ってある。
          'favourites only': find.descendant(
            of: list,
            matching: find.byType(FilterChip, skipOffstage: false),
            skipOffstage: false,
          ),
          'sort': find.descendant(
            of: list,
            matching: find.byType(SortModeControl, skipOffstage: false),
            skipOffstage: false,
          ),
          if (!selecting) ...{
            'add': fab('home-add-project', l10n.commonAdd),
            'scroll to top': fab(
              'home-scroll-to-top',
              l10n.communityScrollToTop,
            ),
          },
        },
        _View.works => {
          'new works folder': fab(
            'home-add-work-folder',
            l10n.homeAddSheetNewFolder,
          ),
        },
        _View.sharedReceived => {
          'received/created': find.byKey(
            const Key('sharedDirectionSegmentedControl'),
          ),
          'favourites only': find.descendant(
            of: shared,
            matching: find.byType(FilterChip),
          ),
          'sort': find.descendant(
            of: shared,
            matching: find.byType(SortModeControl),
          ),
          'new shared folder': fab(
            'shared-add-folder',
            l10n.homeAddSheetNewFolder,
          ),
        },
        _View.sharedOutgoing => {
          'received/created': find.byKey(
            const Key('sharedDirectionSegmentedControl'),
          ),
        },
        _View.trash => {
          for (final kind in TrashEntryKind.values)
            'trash kind ${kind.name}': find.byKey(
              ValueKey('trashKind_${kind.name}'),
            ),
          'sort': find.descendant(
            of: trash,
            matching: find.byType(SortModeControl),
          ),
        },
      },
    };
    return [
      for (final MapEntry(key: name, value: finder) in controls.entries)
        ?_operableProblem('required control "$name"', finder),
    ];
  }

  /// [finder]がちょうど1つあり、画面内で押せるか。中の押せる部品（無ければ
  /// 自分）の1つでもヒットテストに当たればよい。スクロールする一覧の中で
  /// 見えていないものは、スクロールすれば届くので見ない。
  String? _operableProblem(String name, Finder finder) {
    final found = finder.evaluate().toList();
    if (found.length != 1) return '$name found ${found.length} times';
    final element = found.single;
    final box = element.renderObject;
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return '$name not laid out';
    }
    final rect = _globalRect(box);
    Rect? viewport;
    for (final s in _scrollAncestors(element)) {
      final r = _globalRect(s.context.findRenderObject()! as RenderBox);
      viewport = viewport == null ? r : viewport.intersect(r);
    }
    if (viewport != null && !_contains(viewport, rect)) return null;
    final screen = Offset.zero & size;
    if (!_contains(screen, rect)) return '$name off screen $rect';
    final targets = <Element>[if (_isAction(element.widget)) element];
    void visit(Element e) {
      if (_isAction(e.widget)) {
        targets.add(e);
        return;
      }
      e.visitChildElements(visit);
    }

    if (targets.isEmpty) element.visitChildElements(visit);
    if (targets.isEmpty) targets.add(element);
    final pressable = targets.any((e) {
      final b = e.renderObject;
      if (b is! RenderBox || !b.hasSize || b.size.isEmpty) return false;
      final r = _globalRect(b);
      return _contains(screen, r) && _hits(b, r.center);
    });
    return pressable ? null : '$name not hit-testable $rect';
  }

  /// プロジェクトの一覧：表示サイズは選んだもの（選んでいなければ幅で
  /// 決まる大きさ）で、列数はその表示サイズの列数
  /// （[collectionTileColumnCount]）。
  List<String> _gridProblems() {
    if (tabIndex != 0) return const [];
    final lists = find.byType(ProjectListWidget).evaluate().toList();
    if (lists.length != 1) return ['project list found ${lists.length} times'];
    final list = lists.single.widget as ProjectListWidget;
    final expected = chosenViewMode ?? _defaultViewMode(size.width);
    final problems = <String>[
      if (list.viewMode != expected)
        'view size ${list.viewMode.name}, expected ${expected.name} '
            'at ${size.width.round()}px',
    ];
    final menu = find.byType(ProjectViewModeMenu);
    if (menu.evaluate().length == 1) {
      final shown = tester.widget<ProjectViewModeMenu>(menu).value;
      if (shown != expected) {
        problems.add(
          'view size menu shows ${shown.name}, not ${expected.name}',
        );
      }
    }
    final grid = _projectGrid();
    final listed =
        find.byType(EmptyStatePlaceholder).evaluate().isEmpty &&
        contents == _Contents.seeded;
    if (grid == null) {
      if (expected != ProjectViewMode.detail && listed) {
        problems.add('project grid not shown');
      }
      return problems;
    }
    if (expected == ProjectViewMode.detail) {
      problems.add('grid shown in the detail view');
      return problems;
    }
    final extent = grid.constraints.crossAxisExtent;
    final columns = _gridColumns();
    final want = collectionTileColumnCount(
      _targetExtent(expected),
      extent,
      textScale: textScale,
    );
    if (columns != want) {
      problems.add(
        'grid has $columns columns, collectionTileColumnCount(${expected.name}, '
        '${extent.toStringAsFixed(1)}, x$textScale) = $want',
      );
    }
    return problems;
  }

  RenderSliverGrid? _projectGrid() {
    final grids = find
        .descendant(
          of: find.byType(ProjectListWidget),
          matching: find.byType(SliverGrid),
        )
        .evaluate()
        .toList();
    if (grids.length != 1) return null;
    final grid = grids.single.renderObject;
    return grid is RenderSliverGrid && grid.attached ? grid : null;
  }

  /// プロジェクトの一覧の列数（格子でなければnull）。
  int? _gridColumns() {
    final grid = _projectGrid();
    if (grid == null) return null;
    final layout = grid.gridDelegate.getLayout(grid.constraints);
    return layout is SliverGridRegularTileLayout ? layout.crossAxisCount : null;
  }

  /// 格子の1行の高さ（行どうしの間隔を含む）。
  double? _gridRowStride() {
    final grid = _projectGrid();
    if (grid == null) return null;
    final layout = grid.gridDelegate.getLayout(grid.constraints);
    return layout is SliverGridRegularTileLayout ? layout.mainAxisStride : null;
  }

  /// RenderFlexの子が主軸の長さを超えていないか（はみ出しの警告は同じ
  /// RenderFlexにつき1回しか出ないので、幾何で毎回確かめる）。
  List<String> _flexOverflows() {
    final out = <String>[];
    for (final ro in tester.allRenderObjects.toSet()) {
      if (ro is! RenderFlex || !ro.attached || !ro.hasSize) continue;
      final horizontal = ro.direction == Axis.horizontal;
      var extent = 0.0;
      var count = 0;
      var child = ro.firstChild;
      while (child != null) {
        if (child.hasSize) {
          extent += horizontal ? child.size.width : child.size.height;
        }
        count++;
        child = (child.parentData! as FlexParentData).nextSibling;
      }
      extent += ro.spacing * math.max(0, count - 1);
      final available = horizontal ? ro.size.width : ro.size.height;
      if (extent > available + 0.5) {
        out.add(
          'RenderFlex overflowed by '
          '${(extent - available).toStringAsFixed(1)}px: ${_creator(ro)}',
        );
      }
    }
    return out;
  }

  String _creator(RenderObject ro) {
    final creator = ro.debugCreator;
    if (creator is! DebugCreator) return ro.runtimeType.toString();
    final text = _firstText(creator.element);
    return '${creator.element.widget.toStringShort()}'
        '${text == null ? '' : ' "$text"'}';
  }

  /// タブ：4つともあり、アイコンがあり、画面内で押せる。名前を出すときは
  /// 切れていない。幅760px以上（文字の大きさ1倍）では名前を出す。
  List<String> _tabProblems(Rect screen) {
    final problems = <String>[];
    final labels = [
      l10n.homeTabProjects,
      l10n.homeTabWorks,
      l10n.homeTabShared,
      l10n.homeTabTrash,
    ];
    for (var i = 0; i < labels.length; i++) {
      final tab = find.byKey(ValueKey('home_tab_$i'));
      final elements = tab.evaluate().toList();
      if (elements.length != 1) {
        problems.add('tab $i missing');
        continue;
      }
      final box = elements.single.renderObject! as RenderBox;
      final rect = _globalRect(box);
      if (!_contains(screen, rect)) {
        problems.add('tab $i off screen $rect');
      } else if (!_hits(box, rect.center)) {
        problems.add('tab $i not hit-testable');
      }
      if (find
          .descendant(of: tab, matching: find.byType(Icon))
          .evaluate()
          .isEmpty) {
        problems.add('tab $i icon missing');
      }
      final text = find.descendant(of: tab, matching: find.text(labels[i]));
      if (text.evaluate().isEmpty) {
        if (textScale == 1 && size.width >= 760) {
          problems.add('tab label "${labels[i]}" hidden');
        }
        continue;
      }
      final paragraph = tester.renderObject<RenderParagraph>(text);
      if (paragraph.getMaxIntrinsicWidth(double.infinity) >
          paragraph.size.width + 0.5) {
        problems.add('tab label cut "${labels[i]}"');
      }
    }
    return problems;
  }

  static bool _isAction(Widget w) =>
      w is IconButton ||
      w is ButtonStyleButton ||
      w is FloatingActionButton ||
      w is PopupMenuButton ||
      w is FilterChip;

  /// 操作ボタン：画面内に収まり、ヒットテストで当たる。スクロールの途中で
  /// 一部が隠れているものは見ない。浮かぶボタン（FAB）の下にあるものは、
  /// スクロールして避けられるときだけ許す（最後まで送った状態では許さない）。
  List<String> _actionProblems(
    Finder scope,
    Rect screen, {
    bool atEnd = false,
    bool fabRule = true,
  }) {
    final problems = <String>[];
    final fabs = _fabRects();
    final elements = find
        .descendant(of: scope, matching: find.byWidgetPredicate(_isAction))
        .evaluate();
    for (final e in elements) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty) continue;
      final rect = _globalRect(box);
      final scrollables = _scrollAncestors(e);
      Rect? viewport;
      for (final s in scrollables) {
        final r = _globalRect(s.context.findRenderObject()! as RenderBox);
        viewport = viewport == null ? r : viewport.intersect(r);
      }
      if (viewport != null && !_contains(viewport, rect)) continue;
      final label = _describe(e);
      if (!_contains(screen, rect)) {
        problems.add('button off screen: $label $rect');
        continue;
      }
      if (fabRule &&
          e.widget is! FloatingActionButton &&
          fabs.any((f) => f.overlaps(rect))) {
        final vertical = scrollables
            .where((s) => s.position.axis == Axis.vertical)
            .firstOrNull;
        final canScrollAway =
            !atEnd &&
            vertical != null &&
            vertical.position.maxScrollExtent > 0 &&
            vertical.position.pixels < vertical.position.maxScrollExtent;
        if (!canScrollAway) {
          problems.add('button under a floating button: $label $rect');
        }
        continue;
      }
      if (!_hits(box, rect.center)) {
        problems.add('button not hit-testable: $label $rect');
      }
    }
    return problems;
  }

  /// 最後まで送った一覧で、名前・説明が浮かぶボタンに隠れていないか。
  List<String> _textUnderFab(Rect screen) {
    final problems = <String>[];
    final fabs = _fabRects();
    if (fabs.isEmpty) return problems;
    final fabElements = find.byType(FloatingActionButton).evaluate().toSet();
    for (final e
        in find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      var insideFab = false;
      e.visitAncestorElements((a) {
        insideFab = fabElements.contains(a);
        return !insideFab;
      });
      if (insideFab) continue;
      final box = e.renderObject;
      if (box is! RenderParagraph || !box.hasSize || box.size.isEmpty) continue;
      final rect = _globalRect(box);
      Rect? viewport;
      for (final s in _scrollAncestors(e)) {
        final r = _globalRect(s.context.findRenderObject()! as RenderBox);
        viewport = viewport == null ? r : viewport.intersect(r);
      }
      if (viewport != null && !_contains(viewport, rect)) continue;
      if (!_contains(screen, rect)) continue;
      if (fabs.any((f) => f.overlaps(rect.deflate(1)))) {
        problems.add(
          'text under a floating button: "${box.text.toPlainText()}" $rect',
        );
      }
    }
    return problems;
  }

  /// 引き出しの5つの行き先（コイン・特典／契約状態／使い方／設定／容量削減）。
  Map<String, Finder> _drawerLinks() {
    final drawer = find.byType(Drawer);
    final l10n = this.l10n;
    // 画面の下に出た行も作ってあれば見つける（一覧が描く範囲の外の行は
    // 既定の探し方では見つからない）。
    Finder tile(String title) => find.ancestor(
      of: find.descendant(
        of: drawer,
        matching: find.text(title, skipOffstage: false),
        skipOffstage: false,
      ),
      matching: find.byType(ListTile, skipOffstage: false),
    );
    return {
      'coins': find.byKey(
        const Key('homeCoinBenefitsMenuItem'),
        skipOffstage: false,
      ),
      'membership': find.byKey(
        const Key('homeMembershipBenefitsMenuItem'),
        skipOffstage: false,
      ),
      'guide': find.byKey(const Key('homeGuideMenuItem'), skipOffstage: false),
      'settings': tile(l10n.homeDrawerSettings),
      'storage': tile(l10n.homeDrawerStorage),
    };
  }

  /// 引き出し：5つの行き先がすべてあり、横に切れず、画面に見えているものは
  /// 押せる（画面の下に出たものは[drawerCell]がスクロールして確かめる）。
  List<String> _drawerProblems(Rect screen) {
    final problems = <String>[];
    final drawer = find.byType(Drawer);
    if (drawer.evaluate().isEmpty) return ['drawer not open'];
    final links = _drawerLinks();
    final drawerRect = _globalRect(
      tester.renderObject<RenderBox>(drawer.first),
    );
    for (final MapEntry(key: name, value: finder) in links.entries) {
      final found = finder.evaluate().toList();
      if (found.length != 1) {
        problems.add('drawer link "$name" found ${found.length}');
        continue;
      }
      final box = found.single.renderObject! as RenderBox;
      final rect = _globalRect(box);
      if (rect.left < drawerRect.left - 0.5 ||
          rect.right > drawerRect.right + 0.5 ||
          rect.left < -0.5 ||
          rect.right > screen.right + 0.5) {
        problems.add('drawer link "$name" cut sideways $rect');
        continue;
      }
      if (_contains(screen, rect) && !_hits(box, rect.center)) {
        problems.add('drawer link "$name" not hit-testable');
      }
    }
    return problems;
  }

  /// 選択中の操作バー（1行）：全選択・全解除・切り取り・コピー・ゴミ箱が
  /// そろって画面内にあり、省略した文字は長押し・ホバーで全文が読める。
  /// 全選択・全解除は省略しない（収まらなければアイコン）。
  List<String> _selectionBarProblems() {
    final problems = <String>[];
    final l10n = this.l10n;
    final bar = find.byType(HomeSelectionToolbar);
    if (bar.evaluate().isEmpty) return ['selection toolbar not shown'];
    for (final text in [
      l10n.homeSelectionAllSelect,
      l10n.homeSelectionAllDeselect,
    ]) {
      if (find
              .descendant(of: bar, matching: find.byTooltip(text))
              .evaluate()
              .length !=
          1) {
        problems.add('selection control "$text" missing');
      }
    }
    final screen = Offset.zero & size;
    for (final icon in const [
      Icons.content_cut,
      Icons.content_copy,
      Icons.delete,
    ]) {
      final button = find.ancestor(
        of: find.descendant(of: bar, matching: find.byIcon(icon)),
        matching: find.byType(IconButton),
      );
      if (button.evaluate().length != 1) {
        problems.add('selection button $icon=${button.evaluate().length}');
        continue;
      }
      if (!_contains(screen, tester.getRect(button))) {
        problems.add('selection button off screen $icon');
      }
    }
    for (final e
        in find
            .descendant(of: bar, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = e.renderObject! as RenderParagraph;
      if (!paragraph.didExceedMaxLines) continue;
      final cut = paragraph.text.toPlainText();
      if (cut == l10n.homeSelectionAllSelect ||
          cut == l10n.homeSelectionAllDeselect) {
        problems.add('select/deselect label cut "$cut"');
      }
      var inTooltip = false;
      e.visitAncestorElements((a) {
        inTooltip = a.widget is Tooltip;
        return !inTooltip;
      });
      if (!inTooltip) problems.add('selection text cut "$cut"');
    }
    return problems;
  }

  /// 一覧を最後まで送って確かめ（[capture]なら撮り）、先頭へ戻す。
  Future<({List<String> problems, String? image})> _scrollEnd(
    String name, {
    required bool capture,
  }) async {
    final scrollable = _contentScrollable();
    if (scrollable == null || scrollable.position.maxScrollExtent <= 0) {
      return (problems: inspect(atEnd: true), image: null);
    }
    // 遅延して作る一覧は、送るたびに最後の位置が延びる。
    for (var i = 0; i < 6; i++) {
      final max = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(max);
      await tester.pump();
      if (scrollable.position.maxScrollExtent == max) break;
    }
    await frames(2);
    final problems = inspect(atEnd: true);
    String? image;
    if (capture) {
      image = '${name}_end.png';
      await this.capture('${name}_end');
    }
    scrollable.position.jumpTo(0);
    await frames(2);
    return (problems: problems, image: image);
  }

  /// いま見えているタブの本文の縦スクロール（いちばん大きいもの）。
  ScrollableState? _contentScrollable() {
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
      final rect = _globalRect(box).intersect(Offset.zero & size);
      if (rect.isEmpty) continue;
      final area = rect.width * rect.height;
      if (area > bestArea) {
        bestArea = area;
        best = state;
      }
    }
    return best;
  }

  ScrollableState? _projectsScrollable() =>
      tabIndex == 0 ? _contentScrollable() : null;

  List<Rect> _fabRects() => [
    for (final e in find.byType(FloatingActionButton).evaluate())
      if (e.renderObject case final RenderBox box when box.hasSize)
        _globalRect(box),
  ];

  bool _hits(RenderBox box, Offset point) =>
      tester.hitTestOnBinding(point).path.any((entry) => entry.target == box);

  static Rect _globalRect(RenderBox box) => Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );

  static bool _contains(Rect outer, Rect inner) =>
      inner.left >= outer.left - 0.5 &&
      inner.top >= outer.top - 0.5 &&
      inner.right <= outer.right + 0.5 &&
      inner.bottom <= outer.bottom + 0.5;

  static List<ScrollableState> _scrollAncestors(Element e) {
    final out = <ScrollableState>[];
    e.visitAncestorElements((a) {
      if (a is StatefulElement && a.state is ScrollableState) {
        out.add(a.state as ScrollableState);
      }
      return true;
    });
    return out;
  }

  static String _describe(Element e) {
    final w = e.widget;
    final tip = switch (w) {
      IconButton(:final tooltip) => tooltip,
      FloatingActionButton(:final tooltip) => tooltip,
      PopupMenuButton(:final tooltip) => tooltip,
      _ => null,
    };
    final text = _firstText(e);
    return '${w.runtimeType}'
        '${tip == null ? '' : '("$tip")'}'
        '${text == null ? '' : ' "$text"'}';
  }

  static String? _firstText(Element root) {
    String? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is Text && w.data != null) {
        found = w.data;
        return;
      }
      if (w is Icon && w.icon != null) {
        found = 'icon U+${w.icon!.codePoint.toRadixString(16)}';
        return;
      }
      e.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return found;
  }

  // ─── 幅を続けて変える ───────────────────────────────────────────────

  /// 境目の前後を1pxずつ往復し、全体を80pxずつ広げて狭める。画像は撮らず、
  /// 各段で例外・はみ出し・タブ・操作ボタンを確かめる。
  Future<void> resizeSweep() async {
    await show(_View.projects);
    for (final mode in const [false, true]) {
      await setPc(mode);
      final height = mode ? _pcHeight : _phoneHeight;
      final steps = <int>[
        for (final edge in const [560, 641, 760]) ...[
          for (var w = edge - 6; w <= edge + 5; w++) w,
          for (var w = edge + 5; w >= edge - 6; w--) w,
        ],
        for (var w = 320; w <= 1920; w += 80) w,
        for (var w = 1920; w >= 320; w -= 80) w,
      ];
      for (final (index, w) in steps.indexed) {
        size = Size(w.toDouble(), height);
        tester.view.physicalSize = size;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final problems = inspect();
        final name = cellName('resize', 'step$index');
        record(name, 'resize', 'projects', null, problems, const []);
      }
      await frames(4);
    }
  }

  /// 検索（見つからない語）・選択（フォルダと作品の2つ）・フォルダの中・
  /// 一覧の途中までのスクロールのそれぞれを保ったまま、境目の前後を1pxずつ
  /// 往復し、PCモードを切り替える。各段で画面を確かめ、その状態が残って
  /// いることを確かめる。600・1000は幅で決まる表示サイズが替わる所
  /// （スクロール位置は表示サイズごとに覚える作りなので、スクロールは
  /// 替わらない範囲だけ）。
  Future<void> keptStateSweep() async {
    await setPc(false);
    await setTextScale(1);
    await resize(const Size(554, _phoneHeight));
    await show(_View.projects);
    for (final kept in _Kept.values) {
      await setPc(false);
      await resize(const Size(554, _phoneHeight));
      await _enterKept(kept);
      final edges = kept == _Kept.scroll
          ? const [560, 641, 760]
          : const [560, 600, 641, 760, 1000];
      for (final edge in edges) {
        double? reference;
        if (kept == _Kept.scroll) {
          await resize(Size(edge - 6.0, _phoneHeight));
          reference = await _scrollToMiddle();
        }
        final steps = [
          for (var w = edge - 6; w <= edge + 5; w++) w,
          for (var w = edge + 5; w >= edge - 6; w--) w,
        ];
        for (final (index, w) in steps.indexed) {
          size = Size(w.toDouble(), _phoneHeight);
          tester.view.physicalSize = size;
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
          // 境目そのもの（上りの最後）は撮る。
          await _checkKept(kept, 'w$w-$index', reference, shoot: index == 11);
        }
        for (final next in [!pc, pc]) {
          await setPc(next);
          await _checkKept(kept, 'pc-$next', reference);
        }
      }
      await _leaveKept(kept);
    }
  }

  Future<void> _enterKept(_Kept kept) async {
    switch (kept) {
      case _Kept.search:
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.search),
          ),
        );
        await frames(4);
        await tester.enterText(find.byType(TextField), _noMatchQuery);
        await frames(4);
      case _Kept.selection:
        await tester.longPress(await _cardText(_seriesFolder));
        await frames(4);
        await tester.tap(await _cardText(_favouriteProject));
        await frames(4);
        _projectsScrollable()?.position.jumpTo(0);
        await frames(2);
      case _Kept.folder:
        await _openSeries();
      case _Kept.scroll:
        break;
    }
  }

  /// 状態を終える。途中で状態が失われていたら（各段で失敗として記録済み）
  /// 押すものが無いので何もしない。
  Future<void> _leaveKept(_Kept kept) async {
    final button = switch (kept) {
      _Kept.search => find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.close),
      ),
      _Kept.selection => find.byTooltip(l10n.homeSelectionAllDeselect),
      _Kept.folder => find.byTooltip(l10n.projectListFolderRootOption),
      _Kept.scroll => null,
    };
    if (button == null) {
      _projectsScrollable()?.position.jumpTo(0);
    } else if (button.evaluate().length == 1) {
      await tester.tap(button);
    }
    await frames(6);
  }

  /// 一覧を途中（最後までの半分）まで送り、その位置を返す。
  Future<double?> _scrollToMiddle() async {
    final scrollable = _projectsScrollable();
    if (scrollable == null) return null;
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
    await frames(2);
    return scrollable.position.pixels;
  }

  Future<void> _checkKept(
    _Kept kept,
    String step,
    double? reference, {
    bool shoot = false,
  }) async {
    final l10n = this.l10n;
    final problems = [
      ...inspect(),
      if (tabIndex != 0) 'tab changed to $tabIndex',
    ];
    switch (kept) {
      case _Kept.search:
        final field = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        );
        if (field.evaluate().length != 1) {
          problems.add('search closed');
        } else {
          final text = tester.widget<TextField>(field).controller?.text;
          if (text != _noMatchQuery) problems.add('search text lost: "$text"');
        }
        if (find.byIcon(Icons.search_off).evaluate().isEmpty) {
          problems.add('no-match state not shown');
        }
      case _Kept.selection:
        final bar = find.byType(HomeSelectionToolbar);
        if (bar.evaluate().length != 1) {
          problems.add('selection ended');
        } else {
          final count = tester.widget<HomeSelectionToolbar>(bar).selectedCount;
          if (count != 2) problems.add('selection count $count (want 2)');
          problems.addAll(_selectionBarProblems());
        }
      case _Kept.folder:
        final list = find.byType(ProjectListWidget);
        final crumb = find.descendant(
          of: list,
          matching: find.widgetWithText(TextButton, _seriesFolder),
        );
        if (crumb.evaluate().length != 1) problems.add('folder path lost');
        if (find
            .descendant(
              of: list,
              matching: find.byTooltip(l10n.projectListFolderRootOption),
            )
            .evaluate()
            .isEmpty) {
          problems.add('folder path root button lost');
        }
        if (find.text('シーン01').evaluate().isEmpty) {
          problems.add('folder contents not shown');
        }
      case _Kept.scroll:
        final scrollable = _projectsScrollable();
        final stride = _gridRowStride();
        if (reference == null || scrollable == null || stride == null) {
          problems.add('project grid not scrollable');
        } else if (reference < 2 * stride) {
          problems.add(
            'list scrolls only ${reference.toStringAsFixed(1)}px to its middle '
            '(one row is ${stride.toStringAsFixed(1)}); add projects',
          );
        } else if ((scrollable.position.pixels - reference).abs() > stride) {
          problems.add(
            'scroll moved ${reference.toStringAsFixed(1)} -> '
            '${scrollable.position.pixels.toStringAsFixed(1)} '
            '(one row is ${stride.toStringAsFixed(1)})',
          );
        }
    }
    final name = cellName('sweep', '${kept.name}_$step');
    if (shoot) await capture(name);
    record(
      name,
      'sweep',
      kept.name,
      shoot ? ['$name.png'] : null,
      problems,
      const [],
    );
  }
}
