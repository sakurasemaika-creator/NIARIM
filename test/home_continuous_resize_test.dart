import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

/// ホームを開いたまま、窓の幅を320→1920→320と連続で変える。
///
/// 1つのアプリのまま幅だけを変え、1歩ごとに次を確かめる：例外・はみ出しが
/// 無い、選んだタブ・検索語（とその欄のフォーカス・欄そのもの）・選択（2件）・
/// 開いたフォルダ・ゴミ箱の絞り込み・引き出しが残る、一覧の位置が飛ばない
/// （中身が縮んだ分だけ詰まるのは良い）、表示サイズ（600・1000）と列数が
/// ここに書いた決まりどおり、タブ名・選択中の操作バーの文字は入るときだけ
/// 出て入らないときだけアイコンになる、一覧の一番下のカードが浮かぶボタンに
/// 隠れない。切り替えは戻すと同じ境目で元に戻る。
///
/// 幅は20pxずつ、監査の境目（559/560・640/641・759/760）の前後は1pxずつ
/// 動かし、ホームの境目（表示サイズの600・1000、ゴミ箱のカードの600×文字の
/// 倍率＝780、以前のゴミ箱の並び替えの416）は両側の幅を必ず通る。文字の幅で
/// 決まる切り替え（タブ名・選択中の操作バー・ゴミ箱のカードの操作を名前の
/// 右に置けるか）は、20pxの間で切り替わったらその間を1pxずつ歩き直して
/// 境目を探す。境目の両側を build/home-resize へ撮り、
/// 各テストの記録（歩いた幅・表示・列数・一覧の位置・見つけた境目・既知の
/// 不具合・問題）を同じ場所のJSONへ出す。
///
/// 表示サイズを選んでいない（画面の幅で決まる）状態で動かす。一覧の位置が
/// 飛んだときは記録してから元の位置へ戻し、次の境目も一覧を送った状態で
/// 確かめる。一番広い幅で一覧をさらに送ってから狭めていく（広い幅で見て
/// いた位置が、狭めたときに古い位置へ戻らないかを見るため）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  for (final scenario in _Scenario.values) {
    for (final language in const ['ja', 'fr']) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'continuous resize keeps ${scenario.name} ($language, text x$scale)',
          (tester) => _sweep(tester, scenario, language, scale),
          timeout: const Timeout(Duration(minutes: 10)),
        );
      }
    }
  }
}

/// 以前の既知の不具合：表示サイズを選んでいないとき、幅が600・1000をまたいで
/// 表示サイズが変わると、プロジェクトの一覧の位置が失われた（広げると一番上へ
/// 飛び、狭めるとその大きさで前に見ていた古い位置へ戻る）。一覧の
/// PageStorageKeyに今の表示サイズが入っていて、一覧が作り直されたため。
/// 今のホームはキーに開いたときの表示サイズ（_scrollMemoryViewMode）を使い、
/// またいでも飛ばない。
///
/// falseなので、600・1000をまたいだ歩の位置の飛びもほかの歩と同じく失敗に
/// なる。trueにすると、またいだ歩の飛びだけを「既知」として記録し（失敗に
/// しない）、飛ばなくなったら失敗として知らせる。
const _knownViewSizeSwitchLosesScroll = false;

const double _height = 800;
var _fontsLoaded = false;

/// 1pxずつ動かす範囲（両端を含む）。
const _fineWindows = <(int, int)>[(552, 568), (632, 648), (752, 768)];

/// 両側を撮る境目（左が狭い側）。監査の境目と、ホームの境目。
const _boundaryPairs = <(int, int)>[
  (415, 416),
  (559, 560),
  (599, 600),
  (640, 641),
  (759, 760),
  (779, 780),
  (999, 1000),
];

List<int> _upWidths() {
  final widths = <int>{};
  var width = 320;
  while (width < 1920) {
    widths.add(width);
    final inWindow = _fineWindows.any((r) => width >= r.$1 && width < r.$2);
    if (inWindow) {
      width += 1;
      continue;
    }
    final next = width + 20;
    final window = _fineWindows
        .where((r) => r.$1 > width && r.$1 < next)
        .firstOrNull;
    width = window?.$1 ?? next;
  }
  widths.add(1920);
  for (final pair in _boundaryPairs) {
    widths.addAll([pair.$1, pair.$2]);
  }
  return widths.toList()..sort();
}

/// 表示サイズを選んでいないときの表示サイズの境目（600未満は小、1000未満は
/// 中、それ以上は大）。コードの関数から求めずにここへ書く（境目が動いたら
/// 気づけるように）。
const _viewSizeEdges = [600, 1000];

ProjectViewMode _expectedViewMode(double width) => width < 600
    ? ProjectViewMode.small
    : width < 1000
    ? ProjectViewMode.medium
    : ProjectViewMode.large;

bool _crossesViewSizeEdge(int a, int b) => _viewSizeEdges.any(
  (edge) => math.min(a, b) < edge && math.max(a, b) >= edge,
);

/// カードの列数（gridWidthは一覧の幅＝画面の幅から左右8pxずつ引いたもの）。
/// 基準の幅（小130・中170・大240、間隔8）で並ぶ数を切り上げ、中は小より、
/// 大は中より少なくとも1列少なくする（どの幅でも大・中・小が違って見える）。
int _expectedColumns(ProjectViewMode mode, double gridWidth) {
  int fit(double extent) => math.max(1, (gridWidth / (extent + 8)).ceil());
  final small = fit(130);
  final medium = math.max(1, math.min(fit(170), small - 1));
  final large = math.max(1, math.min(fit(240), medium - 1));
  return switch (mode) {
    ProjectViewMode.small => small,
    ProjectViewMode.medium => medium,
    ProjectViewMode.large => large,
    ProjectViewMode.detail => 1,
  };
}

/// タブ名の書式（見出しのくらむぼん、14px、w600）。TabBarはこれをテーマの
/// titleSmallに重ねて描く（字間0.1が加わる）。
const _tabLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
);

enum _Scenario {
  /// プロジェクトのタブを下へ送り、2件を選んだまま。
  projects,

  /// 検索欄を開いて語を入れ、結果を下へ送って2件を選んだまま。
  search,

  /// フォルダを開き、中を下へ送って2件を選んだまま。
  folder,

  /// ゴミ箱のタブで「受け取った共有」を外し、一覧を下へ送ったまま。
  trash,

  /// プロジェクトのタブを下へ送って2件を選び、引き出しを開いたまま。
  drawer,

  /// プロジェクトのタブを一番下まで送り、何も選ばない。1歩ごとに一番下へ
  /// 送り直し、最後の行のカードが浮かぶボタンより上で終わることを見る。
  listEnd;

  /// 一覧の位置が残ることを確かめる（listEndは毎歩一番下へ送り直す）。
  bool get keepsScroll => this != listEnd;

  /// プロジェクトのタブの一覧を見る（表示サイズで作り直される一覧）。
  bool get onProjects => this != trash;
}

class _Seed {
  _Seed({
    required this.folderId,
    required this.folderName,
    required this.trashedIds,
    required this.receivedTrashId,
  });

  final String folderId;
  final String folderName;

  /// ゴミ箱へ移した作った作品（移した順）。
  final List<String> trashedIds;
  final String receivedTrashId;
}

const _searchQuery = '海';

String _projectName(int index) =>
    'A003R ${index.toString().padLeft(3, '0')} ${index.isEven ? '海の街' : '森の道'}';

/// 一番上に61件（フォルダ1つと作品60件）、フォルダの中に40件、ゴミ箱に
/// 作った作品21件と受け取った共有1件。
Future<_Seed> _seedProjects(ProjectService service) async {
  const folderName = 'A003R フォルダ';
  final folder = await service.createFolder(folderName);
  const papers = [0xFFFFFFFF, 0xFF000000, 0xFFF3EAD6, 0x00000000];
  Future<String> create(int index) async {
    final project = await service.createProject(
      name: _projectName(index),
      fps: 1,
      durationSeconds: 1,
      backgroundColor: papers[index % papers.length],
      exportWidth: 32,
      exportHeight: 24,
    );
    return project.id;
  }

  for (var i = 0; i < 60; i++) {
    await create(i);
  }
  for (var i = 60; i < 100; i++) {
    await service.moveToFolder(await create(i), folder.id);
  }
  final trashed = [for (var i = 100; i < 121; i++) await create(i)];
  final source = service.projects.firstWhere((p) => p.id == trashed.last);
  final share = await service.createOutgoingShare(project: source);
  final received = await service.importSharedProject(
    await NiaproSerializer.loadShare(share.path),
  );
  // ゴミ箱は移した日時の新しい順に並ぶ。受け取った共有を途中で移し、上から
  // 6行目（一覧を送った位置で作られている行）に来るようにする（最初か最後に
  // 移すと、送った位置では作られない行になり、出ても気づけない）。
  for (final id in trashed.take(16)) {
    await service.deleteProject(id);
  }
  await service.deleteProject(received.id);
  for (final id in trashed.skip(16)) {
    await service.deleteProject(id);
  }
  return _Seed(
    folderId: folder.id,
    folderName: folderName,
    trashedIds: trashed,
    receivedTrashId: received.id,
  );
}

/// 幅で決まる表示。nullはその画面に無いもの。
class _Layout {
  const _Layout({
    this.viewMode,
    required this.tabLabels,
    this.toolbarCompact,
    this.trashCompact,
    this.trashSortLabel,
  });

  /// プロジェクトの一覧の表示サイズ（選んでいなければ画面の幅で決まる）。
  final ProjectViewMode? viewMode;

  /// タブに名前が出ているか（入らなければアイコンだけ）。
  final bool tabLabels;

  /// 選択中の操作バーの全選択・全解除がアイコンか。
  final bool? toolbarCompact;

  /// ゴミ箱のカードの操作（コピー・復元・完全削除）が名前の下にあるか
  /// （名前の右ではなく）。
  final bool? trashCompact;

  /// ゴミ箱の並び替えに「名前／更新日時」の文字が出ているか。
  final bool? trashSortLabel;

  Map<String, Object?> toJson() => {
    'viewMode': viewMode?.name,
    'tabLabels': tabLabels,
    'toolbarCompact': toolbarCompact,
    'trashCompact': trashCompact,
    'trashSortLabel': trashSortLabel,
  };
}

/// 文字の幅で決まる切り替え（境目は言語・文字の倍率で変わる）。
///
/// ゴミ箱のカードの操作も、幅600×文字の倍率以上で名前の右に置けるかは
/// ボタンの名前の幅で決まる（所有者の判断1）。
const _textDriven = ['tabLabels', 'toolbarCompact', 'trashCompact'];

bool _textDrivenChanged(_Layout a, _Layout b) {
  final x = a.toJson();
  final y = b.toJson();
  return _textDriven.any((k) => x[k] != y[k]);
}

Finder _verticalScrollableIn(Finder parent) => find
    .descendant(
      of: parent,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

Finder _searchField() =>
    find.descendant(of: find.byType(AppBar), matching: find.byType(TextField));

/// 1行の文字の幅（折り返さない）。
double _textWidth(
  String text,
  TextStyle style,
  TextScaler scaler,
  Locale locale,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    locale: locale,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

Future<void> _sweep(
  WidgetTester tester,
  _Scenario scenario,
  String language,
  double scale,
) async {
  SharedPreferences.setMockInitialValues({
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    'first_launch': false,
    'language': language,
  });
  // 読み込んだフォントは同じテストのファイルの中で残る。テストごとに読み込むと
  // そのたびに約80MBずつ増え、20本で2GBを超えた。
  if (!_fontsLoaded) {
    await loadAppFonts(tester);
    _fontsLoaded = true;
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, _height);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final cell = '${scenario.name}_${language}_x$scale';
  final out = Directory('build/home-resize')..createSync(recursive: true);
  final images = <String>[];
  final steps = <Map<String, Object?>>[];
  final problems = <String>[];
  // 既知の不具合として記録だけするもの（_knownViewSizeSwitchLosesScroll）。
  final knownDefects = <String>[];
  // 表示の切り替え（広げる向き・狭める向きごとの、狭い側と広い側の幅）。
  final flipLog = <Map<String, Object?>>[];
  double? startOffset;
  double? topOffset;
  double? endOffset;

  // テストの既定では影が黒い縁取りで描かれ、実機と違う画面になる。
  // 途中で止まっても、終わりのfinallyで（テスト本体の中で）戻す。
  debugDisableShadows = false;
  try {
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: RepaintBoundary(key: boundary, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomeScreen), findsOneWidget);
    final homeElement = tester.element(find.byType(HomeScreen));
    final service = homeElement.read<ProjectService>();
    final seed = (await tester.runAsync(() => _seedProjects(service)))!;
    await _settle(tester);

    Future<void> capture(String name) async {
      final file = '${cell}_$name.png';
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 0.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('${out.path}/$file').writeAsBytesSync(png!.buffer.asUint8List());
      });
      images.add(file);
    }

    // ---- 幅を変える前の状態を作る（320px） ----
    final list = find.byType(ProjectListWidget);
    final selected = <String>{};
    final expectedTab = scenario == _Scenario.trash ? 3 : 0;
    const hiddenKinds = {'receivedShare'};
    switch (scenario) {
      case _Scenario.projects:
      case _Scenario.drawer:
        await _scrollBy(tester, _verticalScrollableIn(list), 700);
        selected.addAll(await _selectTwo(tester, service, (_) => true));
      case _Scenario.search:
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.search),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(_searchField(), _searchQuery);
        await tester.pump(const Duration(milliseconds: 300));
        await _scrollBy(tester, _verticalScrollableIn(list), 600);
        selected.addAll(
          await _selectTwo(
            tester,
            service,
            (p) => p.name.contains(_searchQuery),
          ),
        );
      case _Scenario.folder:
        // フォルダは作品と一緒に並び順（既定は更新日時の新しい順）で並ぶ
        // ので、一番古いこのフォルダは最後のカードになり、狭い幅では
        // まだ作られていない。一覧を最後まで送って作らせる。
        final folderName = find.descendant(
          of: list,
          matching: find.text(seed.folderName),
        );
        if (folderName.evaluate().isEmpty) {
          final position = tester
              .state<ScrollableState>(_verticalScrollableIn(list))
              .position;
          for (var i = 0; i < 6 && folderName.evaluate().isEmpty; i++) {
            position.jumpTo(position.maxScrollExtent);
            await tester.pump(const Duration(milliseconds: 50));
          }
        }
        await tester.tap(folderName);
        await tester.pump(const Duration(milliseconds: 300));
        await _scrollBy(tester, _verticalScrollableIn(list), 500);
        selected.addAll(
          await _selectTwo(tester, service, (p) => p.folderId == seed.folderId),
        );
      case _Scenario.trash:
        final tab = find.byKey(const ValueKey('home_tab_3'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await _settle(tester, frames: 12);
        await tester.tap(find.byKey(const ValueKey('trashKind_receivedShare')));
        await _settle(tester);
        await _scrollBy(
          tester,
          _verticalScrollableIn(find.byType(TrashScreen)),
          400,
        );
        // 受け取った共有の行の両隣（上から5行目と7行目）が作られている。
        // 外した共有が出てしまえば、作られている行の中に見える。カードが
        // 高い言語（仏語の狭い幅は操作のボタンが縦に3つ並ぶ）では400pxでは
        // まだ作られないので、両隣が作られるまで少しずつ送る。
        final order = seed.trashedIds;
        Finder row(String id) =>
            find.byKey(ValueKey('trash-restore-$id'), skipOffstage: false);
        for (
          var i = 0;
          i < 20 &&
              (row(order[16]).evaluate().isEmpty ||
                  row(order[15]).evaluate().isEmpty);
          i++
        ) {
          await _scrollBy(
            tester,
            _verticalScrollableIn(find.byType(TrashScreen)),
            100,
          );
        }
        for (final id in [order[16], order[15]]) {
          expect(
            find.byKey(ValueKey('trash-restore-$id'), skipOffstage: false),
            findsOneWidget,
            reason: 'the rows around the hidden share must be built',
          );
        }
      case _Scenario.listEnd:
        final position = tester
            .state<ScrollableState>(_verticalScrollableIn(list))
            .position;
        position.jumpTo(position.maxScrollExtent);
        await _settle(tester);
    }
    if (scenario == _Scenario.drawer) {
      await tester.tap(find.byKey(const Key('homeMenuButton')));
      await _settle(tester, frames: 8);
    }
    final hadSearchFocus =
        scenario == _Scenario.search &&
        tester.widget<TextField>(_searchField()).focusNode!.hasFocus;
    // 検索欄が作り直されると、打っている途中のキーボードのつながりが切れる。
    final searchState = scenario == _Scenario.search
        ? tester.state<EditableTextState>(
            find.descendant(
              of: _searchField(),
              matching: find.byType(EditableText),
            ),
          )
        : null;
    expect(tester.takeException(), isNull, reason: 'before the sweep');
    final selecting = switch (scenario) {
      _Scenario.trash || _Scenario.listEnd => false,
      _ => true,
    };
    expect(selected, hasLength(selecting ? 2 : 0));
    // 指で一覧を送り、作品を選んでも、打っている検索欄からは離れない。
    if (scenario == _Scenario.search) expect(hadSearchFocus, isTrue);

    Finder scrollable() => scenario == _Scenario.trash
        ? _verticalScrollableIn(find.byType(TrashScreen))
        : _verticalScrollableIn(list);
    double? offsetNow() {
      final finder = scrollable();
      if (finder.evaluate().isEmpty) return null;
      return tester.state<ScrollableState>(finder).position.pixels;
    }

    startOffset = offsetNow();
    expect(startOffset, greaterThan(100), reason: 'the list must be scrolled');
    final homeScaffold = tester.state<ScaffoldState>(
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    // 文字の幅は窓の幅で変わらないので、テストごとに1回だけ測る。
    final textScaler = homeElement
        .getInheritedWidgetOfExactType<MediaQuery>()!
        .data
        .textScaler;
    final locale = Locale(language);
    final tabStyle = Theme.of(
      homeElement,
    ).textTheme.titleSmall!.merge(_tabLabelStyle);
    final tabLabelWidths = <String, double>{};
    double tabLabelWidth(String label) => tabLabelWidths[label] ??= _textWidth(
      label,
      tabStyle,
      textScaler,
      locale,
    );
    final toolbarWidths = <String, double>{};

    // ---- 1歩ごとの確かめ ----
    final flips = <String>{};
    _Layout? previousLayout;
    int? previousWidth;
    int? previousColumns;
    var previousOffset = startOffset!;
    var listMissing = false;
    // 最後の行のカードの下端から浮かぶボタンの上端まで（listEnd）。
    double? fabGap;

    _Layout layoutOf(_Scan scan) {
      final onProjects = expectedTab == 0;
      return _Layout(
        viewMode: onProjects && scan.projectLists.length == 1
            ? (scan.projectLists.single.widget as ProjectListWidget).viewMode
            : null,
        tabLabels: scan.tabTexts.isNotEmpty,
        toolbarCompact: scan.toolbars.isEmpty
            ? null
            : scan.toolbarSelectAllIcon,
        trashCompact: onProjects || !scan.trashCards
            ? null
            : scan.trashActionsBelow,
        trashSortLabel: onProjects ? null : scan.trashSortText,
      );
    }

    /// 描いたカードの列数（カードの左端の位置の種類）。
    int? columnsOf(_Scan scan) {
      if (scan.grids.length != 1) return null;
      final grid = scan.grids.single.renderObject! as RenderSliverGrid;
      final lefts = <int>{};
      for (var c = grid.firstChild; c != null; c = grid.childAfter(c)) {
        final data = c.parentData! as SliverGridParentData;
        lefts.add((data.crossAxisOffset ?? 0).round());
      }
      return lefts.length;
    }

    List<String> inspect(int width, int? from, _Scan scan, _Layout layout) {
      final found = <String>[];
      final error = tester.takeException();
      if (error != null) found.add('exception: $error');
      final w = width.toDouble();
      bool onScreen(Rect r) =>
          r.left >= -0.5 &&
          r.top >= -0.5 &&
          r.right <= w + 0.5 &&
          r.bottom <= _height + 0.5;

      // 選んだタブと、その中身が画面いっぱいに出ていること。
      if (scan.tabBars.length != 1) {
        found.add('tab bars ${scan.tabBars.length}');
      } else {
        final index = (scan.tabBars.single.widget as TabBar).controller!.index;
        if (index != expectedTab) found.add('tab $index');
      }
      final pages = expectedTab == 3 ? scan.trashScreens : scan.projectLists;
      if (pages.length != 1) {
        found.add('tab page missing');
      } else {
        final r = _globalRect(pages.single);
        if (r.left.abs() > 0.5 || (r.width - w).abs() > 0.5) {
          found.add('tab page not aligned $r');
        }
      }

      // 選択・検索・フォルダ。
      if (expectedTab == 0 && scan.projectLists.length == 1) {
        final widget = scan.projectLists.single.widget as ProjectListWidget;
        if (widget.isSelectionMode != selected.isNotEmpty ||
            !setEquals(widget.selectedIds, selected)) {
          found.add('selection ${widget.selectedIds} != $selected');
        }
        final bars = scan.toolbars;
        final barOk = selected.isEmpty
            ? bars.isEmpty
            : bars.length == 1 &&
                  (bars.single.widget as HomeSelectionToolbar).selectedCount ==
                      selected.length;
        if (!barOk) found.add('selection toolbar ${bars.length}');
        final query = scenario == _Scenario.search ? _searchQuery : '';
        if (widget.searchQuery != query) {
          found.add('search query "${widget.searchQuery}"');
        }
        final folder = scenario == _Scenario.folder ? seed.folderId : null;
        if (widget.currentFolderId != folder) {
          found.add('folder ${widget.currentFolderId} != $folder');
        }
      }
      if (scenario == _Scenario.search) {
        if (scan.textFields.length != 1) {
          found.add('search field closed');
        } else {
          final field = scan.textFields.single.widget as TextField;
          if (field.controller!.text != _searchQuery) {
            found.add('search field "${field.controller!.text}"');
          }
          if (hadSearchFocus && !field.focusNode!.hasFocus) {
            found.add('search field lost focus');
          }
          // 欄の枠は文字の倍率で上のバーより高くなり、上下にはみ出すのは
          // Flutterの作りどおり（AppBarの見出しは高さを制限しない）。打った
          // 文字の行が画面内にあることを見る。
          final line = scan.searchEditables.length == 1
              ? scan.searchEditables.single
              : null;
          if (line == null || !onScreen(_globalRect(line))) {
            found.add('search text off screen');
          } else if ((line as StatefulElement).state != searchState) {
            found.add('search field rebuilt');
          }
        }
      } else if (scan.textFields.isNotEmpty) {
        found.add('search field opened');
      }

      // ゴミ箱の絞り込み：外した「受け取った共有」の行が無く、作った作品の
      // 21行だけが並ぶ。
      if (scenario == _Scenario.trash) {
        for (final kind in const [
          'createdProject',
          'receivedShare',
          'createdShare',
          'exportedWork',
        ]) {
          final chip = scan.keyed['trashKind_$kind'];
          if (chip == null) {
            found.add('trash filter $kind missing');
          } else if ((chip.widget as FilterChip).selected ==
              hiddenKinds.contains(kind)) {
            found.add('trash filter $kind changed');
          }
        }
        if (scan.keyed.containsKey('trash-restore-${seed.receivedTrashId}')) {
          found.add('filtered-out received share shown');
        }
        if (scan.trashItemCount != seed.trashedIds.length) {
          found.add(
            'trash rows ${scan.trashItemCount} != ${seed.trashedIds.length}',
          );
        }
        for (final key in scan.keyed.keys) {
          if (!key.startsWith('trash-restore-') ||
              key.startsWith('trash-restore-local-')) {
            continue;
          }
          final id = key.substring('trash-restore-'.length);
          if (!seed.trashedIds.contains(id)) found.add('trash row $id');
        }
        if (!scan.trashCards) found.add('trash rows missing');
      }

      // 引き出し（ホームの画面が作り直されていないことも）。
      if (!homeScaffold.mounted) {
        found.add('home scaffold rebuilt');
      } else if (homeScaffold.isEndDrawerOpen !=
          (scenario == _Scenario.drawer)) {
        found.add('drawer open=${homeScaffold.isEndDrawerOpen}');
      }
      if (scenario == _Scenario.drawer) {
        if (scan.drawers.length != 1) {
          found.add('drawer missing');
        } else {
          final r = _globalRect(scan.drawers.single);
          if ((r.right - w).abs() > 0.5 || r.left < -0.5) {
            found.add('drawer not at the right edge $r');
          }
        }
      }

      // 上のバーのメニュー・浮かぶボタンが画面内。浮かぶボタンは選んで
      // いる間とゴミ箱のタブでは出ない。
      final menu = scan.keyed['homeMenuButton'];
      if (menu == null || !onScreen(_globalRect(menu))) {
        found.add('menu button off screen');
      }
      final expectedFabs = scenario == _Scenario.listEnd ? 2 : 0;
      if (scan.fabs.length != expectedFabs) {
        found.add('floating buttons ${scan.fabs.length} != $expectedFabs');
      }
      double? fabTop;
      for (final fab in scan.fabs) {
        final box = fab.renderObject! as RenderBox;
        final r = _globalRect(fab);
        // 拡大・縮小の動きの途中（幅を変えただけでは動かないはず）。
        if ((r.width - box.size.width).abs() > 0.5 ||
            (r.height - box.size.height).abs() > 0.5) {
          found.add('floating button animating $r');
        }
        if (!onScreen(r)) found.add('FAB off screen $r');
        fabTop = math.min(fabTop ?? r.top, r.top);
      }
      // 一番下まで送ったとき、最後の行のカードが浮かぶボタンより上で終わる
      // （一覧の下に浮かぶボタンの分の余白がある）。
      if (scenario == _Scenario.listEnd &&
          scan.grids.length == 1 &&
          fabTop != null) {
        final grid = scan.grids.single.renderObject! as RenderSliverGrid;
        final last = grid.lastChild;
        final count = (scan.grids.single.widget as SliverGrid)
            .delegate
            .estimatedChildCount;
        if (last == null || count == null || grid.indexOf(last) != count - 1) {
          found.add('last card not built at the end');
        } else {
          final r = _globalRect(last);
          fabGap = fabTop - r.bottom;
          if (r.bottom > fabTop + 0.5) {
            found.add(
              'last card ends at ${r.bottom.toStringAsFixed(1)}, under the '
              'floating buttons at ${fabTop.toStringAsFixed(1)}',
            );
          }
        }
      }

      // 文字が出ているときは切れていない。
      for (final e in [
        ...scan.tabTexts,
        if (layout.toolbarCompact == false) ...scan.toolbarTexts,
      ]) {
        final p = e.renderObject! as RenderParagraph;
        if (p.didExceedMaxLines ||
            p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5) {
          found.add('text cut "${p.text.toPlainText()}"');
        }
      }

      // タブ名は、4つとも「アイコン24＋間8＋名前＋余白16」がタブの幅に
      // 入るときだけ出し、入らないときだけアイコンにする。ホームは名前を
      // TabBarが足す字間（1字0.1px）を除いて測るので、2pxまでは余白の内で
      // ずれてよい（余白16pxがあるので名前は切れない。切れれば上で分かる）。
      if (scan.tabBars.length == 1) {
        final cellWidth =
            (scan.tabBars.single.renderObject! as RenderBox).size.width / 4;
        final labels = [
          for (var i = 0; i < 4; i++)
            (scan.keyed['home_tab_$i']?.widget as Semantics?)?.properties.label,
        ];
        if (labels.any((l) => l == null || l.isEmpty)) {
          found.add('tab names unknown $labels');
        } else {
          final needed = labels
              .map((l) => 24 + 8 + tabLabelWidth(l!) + 16)
              .reduce(math.max);
          if (layout.tabLabels && needed > cellWidth + 2) {
            found.add(
              'tab names shown although they need '
              '${needed.toStringAsFixed(1)} of ${cellWidth.toStringAsFixed(1)}px',
            );
          } else if (!layout.tabLabels && needed <= cellWidth - 2) {
            found.add(
              'tab names hidden although they need '
              '${needed.toStringAsFixed(1)} of ${cellWidth.toStringAsFixed(1)}px',
            );
          }
          // 測った幅が描いた文字と同じ（測り方がずれていたら上の確かめは
          // 意味が無い）。
          for (final e in scan.tabTexts) {
            final p = e.renderObject! as RenderParagraph;
            final text = p.text.toPlainText();
            final drawn = p.getMaxIntrinsicWidth(double.infinity);
            if ((drawn - tabLabelWidth(text)).abs() > 0.5) {
              found.add(
                'tab name "$text" drawn ${drawn.toStringAsFixed(1)}px, '
                'measured ${tabLabelWidth(text).toStringAsFixed(1)}px',
              );
            }
          }
        }
      }
      if (w == 1920 && !layout.tabLabels) found.add('tab names hidden');

      // 選択中の操作バー：全選択・全解除・件数の3つがそれぞれ「残りの幅の
      // 3分の1」に入るとき（ボタンは押せる48pxも）だけ文字、入らないとき
      // だけアイコン。
      if (scan.toolbars.length == 1) {
        final bar = scan.toolbars.single;
        final inner = (bar.renderObject! as RenderBox).size.width - 16;
        final third = (inner - 3 * 48) / 3;
        final l10n = AppLocalizations.of(bar)!;
        final theme = Theme.of(bar);
        final buttonStyle =
            theme.textButtonTheme.style?.textStyle?.resolve({}) ??
            theme.textTheme.labelLarge!;
        final countStyle = theme.textTheme.bodyMedium!;
        double measure(String text, TextStyle style) =>
            toolbarWidths[text] ??= _textWidth(text, style, textScaler, locale);
        final selectAll = l10n.homeSelectionAllSelect;
        final deselect = l10n.homeSelectionAllDeselect;
        final count = l10n.homeSelectionCount(selected.length);
        final needed = [
          48.0,
          measure(selectAll, buttonStyle) + 8,
          measure(deselect, buttonStyle) + 8,
          measure(count, countStyle),
        ].reduce(math.max);
        if (layout.toolbarCompact == false && needed > third + 0.01) {
          found.add('selection words shown in ${third.toStringAsFixed(1)}px');
        } else if (layout.toolbarCompact == true && needed <= third - 1) {
          found.add(
            'selection icons although the words need '
            '${needed.toStringAsFixed(1)} of ${third.toStringAsFixed(1)}px',
          );
        }
        if (layout.toolbarCompact == false) {
          for (final e in scan.toolbarTexts) {
            final p = e.renderObject! as RenderParagraph;
            final text = p.text.toPlainText();
            final measured = toolbarWidths[text];
            final drawn = p.getMaxIntrinsicWidth(double.infinity);
            if (measured == null || (drawn - measured).abs() > 0.5) {
              found.add(
                'selection word "$text" drawn ${drawn.toStringAsFixed(1)}px, '
                'measured ${measured?.toStringAsFixed(1)}px',
              );
            }
          }
        }
        if (w == 1920 && layout.toolbarCompact != false) {
          found.add('selection icons');
        }
      }

      // 表示サイズと列数は、ここに書いた決まりどおり。600・1000をまたぐと
      // 列数が変わる（大きさを変えても見た目が同じ、にならない）。
      if (layout.viewMode != null) {
        final mode = _expectedViewMode(w);
        if (layout.viewMode != mode) {
          found.add('view size ${layout.viewMode!.name}');
        }
        final columns = columnsOf(scan);
        final expected = _expectedColumns(mode, w - 16);
        if (columns != expected) found.add('columns $columns != $expected');
        if (from != null &&
            _crossesViewSizeEdge(from, width) &&
            columns != null &&
            columns == previousColumns) {
          found.add('columns stay $columns across $from/$width');
        }
      }
      // ゴミ箱のカードの操作（所有者の判断1）：幅が600×文字の倍率より
      // 狭いと名前の下の右端、広いと名前の右。ただし右に置くと名前の欄が
      // 名前の文字15字分（先頭の絵48と余白16＋16＋24を足した幅）より狭く
      // なるなら名前の下。
      if (layout.trashCompact != null) {
        final room = scan.trashBesideRoom;
        final below =
            w < 600 * scale ||
            (room != null && room < 16 + 48 + 16 + 24 + 15 * 16 * scale);
        if (room == null && w >= 600 * scale) {
          found.add('trash card name/actions not measured');
        } else if (layout.trashCompact != below) {
          found.add(
            'trash card compact=${layout.trashCompact} '
            '(room beside ${room?.toStringAsFixed(1)})',
          );
        }
      }
      // ゴミ箱の並び替えは、今の作り（一覧の上の並び替えの行、枠が96px
      // 未満のときだけメニューになる）ではどの幅でも「名前／更新日時」を出す。
      if (layout.trashSortLabel != null && layout.trashSortLabel != true) {
        found.add('trash sort label=${layout.trashSortLabel}');
      }
      return found;
    }

    /// 幅を変えて確かめ、新しく見つけた表示の切り替え（キー名）を返す。
    Future<List<String>> step(
      int width,
      String direction, {
      String? tag,
    }) async {
      final from = previousWidth;
      tester.view.physicalSize = Size(width.toDouble(), _height);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      if (scenario == _Scenario.listEnd) {
        // 一番下へ送り直す（狭めると中身が伸び、一番下が画面の外へ出る）。
        final position = _Scan().listScrollable?.position;
        if (position != null) {
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
        }
      }
      final scan = _Scan();
      final layout = layoutOf(scan);
      fabGap = null;
      final found = inspect(width, from, scan, layout);
      // 一覧の位置：中身が縮んで下端が上がった分だけ詰まるのは良いが、
      // それ以外に動いてはいけない。
      final scrollable = scenario == _Scenario.trash
          ? scan.trashScrollable
          : scan.listScrollable;
      double? offset;
      double? maxOffset;
      if (scrollable == null) {
        // 一覧が消えても止めずに記録し、次の歩へ進む（最初の歩だけ撮る）。
        found.add('the list has no scrollable');
        if (!listMissing) await capture('${direction}_${width}_no_list');
        listMissing = true;
      } else {
        listMissing = false;
        final scroll = scrollable.position;
        final floor = math.min(previousOffset, scroll.maxScrollExtent);
        final moved = scroll.pixels;
        if (scenario.keepsScroll &&
            (moved < floor - 1 || moved > previousOffset + 1)) {
          final text =
              'scroll moved ${previousOffset.toStringAsFixed(1)} -> '
              '${moved.toStringAsFixed(1)} '
              '(max ${scroll.maxScrollExtent.toStringAsFixed(1)})';
          final known =
              _knownViewSizeSwitchLosesScroll &&
              scenario.onProjects &&
              from != null &&
              _crossesViewSizeEdge(from, width);
          if (known) {
            knownDefects.add('$direction $width: $text');
          } else {
            found.add(text);
          }
          await capture(
            '${direction}_${width}_${known ? 'known_' : ''}scroll_jump',
          );
          // 記録したら元の位置へ戻し、次の境目も同じ条件で確かめる。
          scroll.jumpTo(math.min(previousOffset, scroll.maxScrollExtent));
          await tester.pump();
        }
        offset = scroll.pixels;
        maxOffset = scroll.maxScrollExtent;
        previousOffset = scroll.pixels;
      }
      final newFlips = <String>[];
      final fromLayout = previousLayout?.toJson();
      final toLayout = layout.toJson();
      final forward =
          from != null &&
          (direction == 'up' ? width - from == 1 : from - width == 1);
      if (forward && fromLayout != null) {
        for (final key in toLayout.keys) {
          final a = fromLayout[key];
          final b = toLayout[key];
          if (a == b || a == null || b == null) continue;
          final narrow = math.min(from, width);
          final wide = math.max(from, width);
          final narrowValue = direction == 'up' ? a : b;
          final wideValue = direction == 'up' ? b : a;
          final id = '$direction $key $narrow/$wide';
          if (flips.add(id)) {
            newFlips.add(key);
            flipLog.add({
              'direction': direction,
              'key': key,
              'narrow': narrow,
              'wide': wide,
              'narrowValue': narrowValue,
              'wideValue': wideValue,
            });
          }
        }
      }
      final columns = layout.viewMode == null ? null : columnsOf(scan);
      steps.add({
        'width': width,
        'direction': direction,
        'tag': ?tag,
        'layout': toLayout,
        'columns': ?columns,
        'fabGap': ?fabGap,
        'offset': ?offset,
        'maxOffset': ?maxOffset,
        'problems': found,
      });
      for (final p in found) {
        problems.add('$direction $width: $p');
      }
      previousLayout = layout;
      previousWidth = width;
      previousColumns = columns;
      return newFlips;
    }

    final captureAt = {
      for (final pair in _boundaryPairs) ...[pair.$1, pair.$2],
    };

    /// 1px進め、切り替わったら境目の両側を撮る（決まった境目は別に撮る）。
    Future<void> stepAndCaptureFlip(int width, String direction) async {
      final from = previousWidth!;
      final flipped = await step(width, direction, tag: 'fine');
      if (flipped.isEmpty ||
          (captureAt.contains(width) && captureAt.contains(from))) {
        return;
      }
      final name = flipped.join('+');
      await capture('${direction}_${width}_${name}_after');
      await step(from, direction, tag: 'flip-before');
      await capture('${direction}_${from}_${name}_before');
      await step(width, direction, tag: 'flip-resume');
    }

    Future<void> sweep(List<int> widths, String direction) async {
      for (final width in widths) {
        final from = previousWidth!;
        final fromLayout = previousLayout!;
        if ((width - from).abs() == 1) {
          await stepAndCaptureFlip(width, direction);
        } else {
          await step(width, direction);
          // 20pxの間で文字の幅による切り替えが起きたら、その間を1pxずつ
          // 歩き直して境目を探す。
          if (_textDrivenChanged(fromLayout, previousLayout!)) {
            await step(from, direction, tag: 'refine-back');
            final sign = width > from ? 1 : -1;
            for (var w = from + sign; w != width + sign; w += sign) {
              await stepAndCaptureFlip(w, direction);
            }
          }
        }
        if (captureAt.contains(width)) await capture('${direction}_$width');
      }
    }

    await step(320, 'start');
    await capture('start_320');
    final up = _upWidths();
    await sweep(up.skip(1).toList(), 'up');
    await capture('top_1920');
    // 一番広い幅で一覧をさらに送ってから狭める（引き出しの上からは送れず、
    // listEndは一番下にいる）。
    if (scenario.keepsScroll &&
        scenario != _Scenario.drawer &&
        scrollable().evaluate().isNotEmpty) {
      await _scrollBy(tester, scrollable(), 150);
      previousOffset = offsetNow() ?? previousOffset;
    }
    topOffset = offsetNow();
    await sweep(up.reversed.skip(1).toList(), 'down');
    await capture('end_320');
    endOffset = offsetNow();

    // 切り替えは広げたときと狭めたときで同じ境目で1回ずつ、逆向きの値で。
    for (final key in _Layout(tabLabels: false).toJson().keys) {
      final upFlips = flipLog
          .where((f) => f['key'] == key && f['direction'] == 'up')
          .toList();
      final downFlips = flipLog
          .where((f) => f['key'] == key && f['direction'] == 'down')
          .toList();
      String describe(List<Map<String, Object?>> f) => f
          .map(
            (e) =>
                '${e['narrowValue']}@${e['narrow']}/${e['wideValue']}@${e['wide']}',
          )
          .join(', ');
      final same =
          upFlips.length == downFlips.length &&
          [
            for (var i = 0; i < upFlips.length; i++)
              upFlips[i]['narrow'] ==
                      downFlips[downFlips.length - 1 - i]['narrow'] &&
                  upFlips[i]['narrowValue'] ==
                      downFlips[downFlips.length - 1 - i]['narrowValue'],
          ].every((ok) => ok);
      if (!same) {
        problems.add(
          '$key switched differently: up [${describe(upFlips)}] '
          'down [${describe(downFlips)}]',
        );
      }
      if (_textDriven.contains(key) && upFlips.length > 1) {
        problems.add('$key switched ${upFlips.length} times');
      }
    }

    // 既知の不具合がまだ起きていること（直ったら_knownViewSizeSwitchLosesScroll
    // をfalseにして、またいだ歩も普通に確かめる）。広げて600・1000をまたぐと、
    // 送ってあった一覧が一番上へ飛ぶ。
    if (_knownViewSizeSwitchLosesScroll &&
        scenario.keepsScroll &&
        scenario.onProjects) {
      for (final edge in _viewSizeEdges) {
        if (!knownDefects.any((d) => d.startsWith('up $edge: '))) {
          problems.add(
            'the known scroll loss at up $edge is gone: set '
            '_knownViewSizeSwitchLosesScroll to false',
          );
        }
      }
    }
  } catch (error, stack) {
    // 途中で止まっても、それまでに見つけた問題と記録を残す。
    problems.add('stopped: $error');
    debugPrint('$stack');
  } finally {
    File('${out.path}/$cell.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'scenario': scenario.name,
        'language': language,
        'textScale': scale,
        'height': _height,
        'steps': steps.length,
        'startOffset': startOffset,
        'topOffset': topOffset,
        'endOffset': endOffset,
        'breakpoints': flipLog,
        'knownDefects': knownDefects,
        'problems': problems,
        'images': images,
        'log': steps,
      }),
    );
    // テスト本体の終わりで戻しておかないと、終了時の検査で失敗する。
    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox.shrink());
  }
  expect(problems, isEmpty, reason: problems.take(40).join('\n'));
}

Future<void> _settle(WidgetTester tester, {int frames = 4}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// 指で一覧を送る（慣性で流れないよう、止めてから離す）。
Future<void> _scrollBy(
  WidgetTester tester,
  Finder scrollable,
  double by,
) async {
  final gesture = await tester.startGesture(tester.getCenter(scrollable));
  // 最初の動きはタッチスロップを越えるために使われ、送る量にならない。
  await gesture.moveBy(const Offset(0, -20));
  for (var moved = 0.0; moved < by; moved += 50) {
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await _settle(tester, frames: 6);
}

/// 一覧に見えている作品から2件を選ぶ（長押しで選択を始め、もう1件を押す）。
Future<Set<String>> _selectTwo(
  WidgetTester tester,
  ProjectService service,
  bool Function(Project project) eligible,
) async {
  final list = find.byType(ProjectListWidget);
  final viewport = tester.getRect(_verticalScrollableIn(list));
  final picks = <(String, Finder)>[];
  for (final project in service.projects.where(eligible)) {
    final name = find.descendant(of: list, matching: find.text(project.name));
    if (name.evaluate().length != 1) continue;
    final r = tester.getRect(name);
    // 浮かぶボタンの高さを避ける。
    if (r.top < viewport.top + 40 || r.bottom > viewport.bottom - 120) continue;
    picks.add((project.id, name));
    if (picks.length == 2) break;
  }
  expect(picks, hasLength(2), reason: 'two visible projects to select');
  await tester.longPress(picks[0].$2);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(picks[1].$2);
  await tester.pump(const Duration(milliseconds: 300));
  return {picks[0].$1, picks[1].$1};
}

/// 画面上の矩形（途中の拡大・縮小・回転を含む）。
Rect _globalRect(Object target) {
  final box = switch (target) {
    final Element e => e.renderObject! as RenderBox,
    final RenderBox b => b,
    _ => throw ArgumentError.value(target),
  };
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// 要素の木のどこをたどっているか。
class _Where {
  const _Where({
    this.list = false,
    this.trash = false,
    this.trashList = false,
    this.toolbar = false,
    this.tab = false,
    this.appBar = false,
    this.card = false,
    this.sort = false,
  });

  final bool list;
  final bool trash;
  final bool trashList;
  final bool toolbar;
  final bool tab;
  final bool appBar;
  final bool card;
  final bool sort;

  _Where copy({
    bool? list,
    bool? trash,
    bool? trashList,
    bool? toolbar,
    bool? tab,
    bool? appBar,
    bool? card,
    bool? sort,
  }) => _Where(
    list: list ?? this.list,
    trash: trash ?? this.trash,
    trashList: trashList ?? this.trashList,
    toolbar: toolbar ?? this.toolbar,
    tab: tab ?? this.tab,
    appBar: appBar ?? this.appBar,
    card: card ?? this.card,
    sort: sort ?? this.sort,
  );
}

/// 1歩ごとに要素の木を1回だけたどり、確かめに使う要素を集める
/// （find.byTypeは呼ぶたびに木全体をたどるので、1歩に何十回も呼ぶと遅い）。
/// 画面の外に作られている要素（一覧の先読みの分）も含める。
class _Scan {
  _Scan() {
    _visit(WidgetsBinding.instance.rootElement!, const _Where());
  }

  final projectLists = <Element>[];
  final trashScreens = <Element>[];
  final tabBars = <Element>[];
  final toolbars = <Element>[];
  final drawers = <Element>[];
  final textFields = <Element>[];
  final searchEditables = <Element>[];
  final fabs = <Element>[];
  final grids = <Element>[];
  final keyed = <String, Element>{};
  final tabTexts = <Element>[];
  final toolbarTexts = <Element>[];
  bool toolbarSelectAllIcon = false;
  bool trashCards = false;
  bool trashSortText = false;
  // 最初のゴミ箱のカードの、名前の行と操作の並び（ActionBesideOrBelow）。
  Element? _trashActionRow;
  int? trashItemCount;
  ScrollableState? listScrollable;
  ScrollableState? trashScrollable;

  ({RenderBox tile, RenderBox bar, RenderBox row})? get _trashRowBoxes {
    final row = _trashActionRow;
    if (row == null) return null;
    RenderBox? tile;
    RenderBox? bar;
    void visit(Element e) {
      if (e.widget is ListTile) tile ??= e.renderObject as RenderBox?;
      if (e.widget is OverflowBar) bar ??= e.renderObject as RenderBox?;
      e.visitChildElements(visit);
    }

    row.visitChildElements(visit);
    if (tile == null || bar == null || !tile!.hasSize || !bar!.hasSize) {
      return null;
    }
    return (tile: tile!, bar: bar!, row: row.renderObject! as RenderBox);
  }

  /// 最初のゴミ箱のカードで、操作が名前の行の下にあるか。
  bool? get trashActionsBelow {
    final boxes = _trashRowBoxes;
    if (boxes == null) return null;
    return _globalRect(boxes.bar).top >= _globalRect(boxes.tile).bottom - 0.5;
  }

  /// 操作を名前の右に1行で並べたとき、名前の行に残る幅（操作の右の余白8を
  /// 除く）。操作の幅は、ボタンを1行に並べた幅。
  double? get trashBesideRoom {
    final boxes = _trashRowBoxes;
    if (boxes == null) return null;
    return boxes.row.size.width -
        boxes.bar.getMaxIntrinsicWidth(double.infinity) -
        8;
  }

  void _visit(Element element, _Where where) {
    final widget = element.widget;
    var next = where;
    final key = widget.key;
    if (key is ValueKey<String>) {
      keyed[key.value] = element;
      if (key.value.startsWith('home_tab_')) next = next.copy(tab: true);
    }
    switch (widget) {
      case ProjectListWidget():
        projectLists.add(element);
        next = next.copy(list: true);
      case TrashScreen():
        trashScreens.add(element);
        next = next.copy(trash: true);
      case TabBar():
        tabBars.add(element);
      case HomeSelectionToolbar():
        toolbars.add(element);
        next = next.copy(toolbar: true);
      case HomeDrawer():
        drawers.add(element);
      case AppBar():
        next = next.copy(appBar: true);
      case TextField():
        if (where.appBar) textFields.add(element);
      case EditableText():
        if (where.appBar) searchEditables.add(element);
      case FloatingActionButton():
        fabs.add(element);
      case SliverGrid():
        if (where.list) grids.add(element);
      case SliverList(:final delegate):
        if (where.trashList && trashItemCount == null) {
          trashItemCount = delegate.estimatedChildCount;
        }
      case Card():
        if (where.trash) {
          trashCards = true;
          next = next.copy(card: true);
        }
      case ActionBesideOrBelow():
        if (where.card) _trashActionRow ??= element;
      case SortModeControl():
        next = next.copy(sort: true);
      case Text():
        if (where.tab) tabTexts.add(element);
        if (where.toolbar) toolbarTexts.add(element);
        if (where.trash && where.sort) trashSortText = true;
      case Icon(:final icon):
        if (where.toolbar && icon == Icons.select_all) {
          toolbarSelectAllIcon = true;
        }
      case Scrollable(axisDirection: AxisDirection.down):
        final state = (element as StatefulElement).state as ScrollableState;
        if (where.list) listScrollable ??= state;
        if (where.trash && trashScrollable == null) {
          trashScrollable = state;
          next = next.copy(trashList: true);
        }
      default:
        break;
    }
    element.visitChildElements((child) => _visit(child, next));
  }
}
