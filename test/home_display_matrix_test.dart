import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// ホーム画面の表示マトリクス（24幅 × スマホ/PC × 7言語 = 336通り）。
/// 各セルで例外・タブ名の省略・画面外の操作・PCの側面パネルの有無を確かめ、
/// 目視用に全セルの画像と一覧（manifest.json）を build/home-matrix へ出す。
/// 「作品一覧」「ブクマ済み」タブ、作品の詳細表示、検索で何も見つからない
/// ときは境目の幅（320/559/560/760/1280）で撮る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_home_matrix_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const widths = [
    320, 360, 375, 390, 430, 480, 520, 559, 560, 600, 640, 641, 700, //
    759, 760, 834, 900, 1024, 1180, 1280, 1366, 1440, 1600, 1920,
  ];
  const otherTabWidths = {320, 559, 560, 760, 1280};
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const modes = {'sp': 844.0, 'pc': 900.0};

  testWidgets('display matrix: 24 widths x phone/PC x 7 languages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
    });
    await loadAppFonts(tester);
    // テストの既定では影が黒い縁取りで描かれ、実機と違う画面になる。
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: RepaintBoundary(key: boundary, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final splash = tester.element(find.byType(Scaffold).first);
    final settings = splash.read<SettingsService>();
    final projects = splash.read<ProjectService>();
    await tester.runAsync(() async {
      // 一覧の見え方が変わる組み合わせ：黒・透明・ベージュの背景、縦長の
      // 作品、お気に入り、フォルダ（お気に入り付き）。
      for (final (name, paper, portrait, favorite) in const [
        ('夕暮れの街を歩く猫と少女の長い長いアニメーション（第二部・完結編）', 0xFF000000, false, true),
        ('Walk cycle', 0xFFFFFFFF, false, false),
        ('ポーズ集', 0x00000000, true, false),
        (
          'Une très longue séquence d’animation pour le festival',
          0xFFF3EAD6,
          false,
          false,
        ),
        ('표정 연습', 0xFF000000, true, false),
        ('背景动画', 0xFFFFFFFF, false, true),
      ]) {
        final project = await projects.createProject(
          name: name,
          fps: 12,
          durationSeconds: 1,
          backgroundColor: paper,
          exportWidth: portrait ? 1080 : 1920,
          exportHeight: portrait ? 1920 : 1080,
        );
        if (favorite) await projects.toggleFavorite(project.id);
      }
      final folder = await projects.createFolder('シリーズ');
      await projects.toggleFolderFavorite(folder.id);
    });
    appRouter.go('/home');
    await tester.pump(const Duration(seconds: 1));

    final out = Directory('build/home-matrix')..createSync(recursive: true);
    final manifest = <Map<String, Object?>>[];
    final failures = <String>[];

    Future<void> capture(String name) => tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 0.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    // ホームのタブは自前の部品で、各タブは選択肢のグループとして読み上げる。
    final tabItems = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.inMutuallyExclusiveGroup == true,
    );

    Future<void> selectTab(int index) async {
      await tester.tap(tabItems.at(index));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    List<String> inspect(Size size, {required bool pc}) {
      final problems = <String>[];
      final error = tester.takeException();
      if (error != null) problems.add('$error');
      final screen = Offset.zero & size;
      bool onScreen(Rect r) =>
          screen.contains(r.topLeft) &&
          screen.contains(r.bottomRight - const Offset(1, 1));
      // タブ名は1行で切れずに出ること。
      final labels = find
          .descendant(of: tabItems, matching: find.byType(RichText))
          .evaluate();
      if (labels.length != 3) problems.add('tab labels=${labels.length}');
      for (final e in labels) {
        // 1行・折り返しなしの文字は省略されず端で切れるので、行数ではなく
        // 文字の幅が枠に収まっているかで確かめる。
        final p = e.renderObject! as RenderParagraph;
        if (p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5) {
          problems.add('tab label cut "${p.text.toPlainText()}"');
        }
      }
      // 上部バーのボタンとFABが画面内にあること。
      final appBar = find.byType(AppBar).hitTestable();
      for (final e
          in find
              .descendant(of: appBar, matching: find.byType(IconButton))
              .evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (!onScreen(r)) problems.add('app bar button off screen $r');
      }
      for (final e in find.byType(FloatingActionButton).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (!onScreen(r)) problems.add('FAB off screen $r');
      }
      final side = find
          .byWidgetPredicate((w) => w is HomeDrawer && w.permanent)
          .evaluate()
          .isNotEmpty;
      final wantSide = pc && size.width >= 1000;
      if (side != wantSide) problems.add('side panel=$side want=$wantSide');
      return problems;
    }

    for (final language in languages) {
      await tester.runAsync(() => settings.setLanguage(language));
      for (final mode in modes.entries) {
        await tester.runAsync(() => settings.setForcePcMode(mode.key == 'pc'));
        // 言語・PCモードの切り替えに伴うテーマ・画面の切り替わりを待つ。
        await tester.pump(const Duration(seconds: 1));
        for (final w in widths) {
          final size = Size(w.toDouble(), mode.value);
          tester.view.physicalSize = size;
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final cell = '${language}_${mode.key}_$w';
          final problems = inspect(size, pc: mode.key == 'pc');
          await capture(cell);
          final shots = <String>['$cell.png'];
          if (otherTabWidths.contains(w)) {
            for (final tab in const [1, 2]) {
              await selectTab(tab);
              final extra = inspect(size, pc: mode.key == 'pc');
              problems.addAll(extra.map((p) => 'tab$tab: $p'));
              await capture('${cell}_tab$tab');
              shots.add('${cell}_tab$tab.png');
            }
            await selectTab(0);
            // 詳細表示と、検索で何も見つからないとき。
            await tester.tap(find.byType(ProjectViewModeMenu));
            // メニューが開き終わるまで待つ（開く途中のタップは届かない）。
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(find.byType(PopupMenuItem<ProjectViewMode>).last);
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
            problems.addAll(
              inspect(size, pc: mode.key == 'pc').map((p) => 'detail: $p'),
            );
            if (find.byType(ListTile).evaluate().isEmpty) {
              problems.add('detail view not shown');
            }
            await capture('${cell}_detail');
            shots.add('${cell}_detail.png');
            await tester.tap(find.byType(ProjectViewModeMenu));
            // メニューが開き終わるまで待つ（開く途中のタップは届かない）。
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(find.byType(PopupMenuItem<ProjectViewMode>).at(1));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(find.byIcon(Icons.search));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.enterText(find.byType(TextField), 'zzz');
            await tester.pump(const Duration(milliseconds: 400));
            if (find.byIcon(Icons.search_off).evaluate().isEmpty) {
              problems.add('no-match state not shown');
            }
            problems.addAll(
              inspect(size, pc: mode.key == 'pc').map((p) => 'no match: $p'),
            );
            await capture('${cell}_nomatch');
            shots.add('${cell}_nomatch.png');
            await tester.tap(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.byIcon(Icons.close),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
          }
          manifest.add({
            'cell': cell,
            'language': language,
            'mode': mode.key,
            'width': w,
            'height': mode.value,
            'orientation': w > mode.value ? 'landscape' : 'portrait',
            'images': shots,
            'problems': problems,
          });
          if (problems.isNotEmpty) {
            failures.add('$cell: ${problems.join(', ')}');
          }
        }
      }
    }
    File('${out.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'cells': manifest.length,
        'failures': failures,
        'results': manifest,
      }),
    );
    // テスト本体の終わりで戻しておかないと、終了時の検査で失敗する。
    debugDisableShadows = true;
    expect(manifest.length, 336);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // 文字を大きくした狭い画面：タブ名は切れず、横スクロールになっても
  // 選んだタブが画面内に来る。PCの側面パネルは状態バー・ナビゲーション
  // バーの下へ潜らない。
  testWidgets(
    'large text and system bars keep tabs and the side panel usable',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final settings = tester
          .element(find.byType(Scaffold).first)
          .read<SettingsService>();
      appRouter.go('/home');
      await tester.pump(const Duration(seconds: 1));
      final tabItems = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.inMutuallyExclusiveGroup == true,
      );
      final failures = <String>[];
      for (final language in languages) {
        await tester.runAsync(() => settings.setLanguage(language));
        for (final scale in const [1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final w in const [320.0, 360.0, 390.0]) {
            final size = Size(w, 760);
            tester.view.physicalSize = size;
            await tester.pump(const Duration(milliseconds: 300));
            for (final tab in const [1, 2, 0]) {
              final where = '$language x$scale ${w.round()} tab$tab';
              // 隣のタブへは一覧を横に送って移る（画面外のタブも押せるとは
              // 限らないため、本文のスワイプと同じ経路で切り替える）。
              tester
                  .widget<TabBarView>(find.byType(TabBarView))
                  .controller!
                  .animateTo(tab);
              for (var i = 0; i < 4; i++) {
                await tester.pump(const Duration(milliseconds: 150));
              }
              final error = tester.takeException();
              if (error != null) failures.add('$where: $error');
              final selected = tester.getRect(tabItems.at(tab));
              if (selected.left < -0.5 || selected.right > w + 0.5) {
                failures.add('$where: selected tab off screen $selected');
              }
              for (final e
                  in find
                      .descendant(of: tabItems, matching: find.byType(RichText))
                      .evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                if (p.getMaxIntrinsicWidth(double.infinity) >
                    p.size.width + 0.5) {
                  failures.add('$where: label cut "${p.text.toPlainText()}"');
                }
              }
            }
          }
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();

      // PC（DeX）の側面パネル：状態バー24px・ナビゲーションバー48px。
      await tester.runAsync(() => settings.setLanguage('ja'));
      await tester.runAsync(() => settings.setForcePcMode(true));
      const pcSize = Size(1005, 600);
      tester.view.physicalSize = pcSize;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      await tester.pump(const Duration(seconds: 1));
      final panel = find.byWidgetPredicate(
        (w) => w is HomeDrawer && w.permanent,
      );
      expect(panel, findsOneWidget);
      final header = tester.getRect(
        find.descendant(
          of: panel,
          matching: find.byIcon(Icons.movie_creation_outlined),
        ),
      );
      if (header.top < 24 - 0.5) {
        failures.add('side panel: header icon under the status bar $header');
      }
      final list = find.descendant(
        of: panel,
        matching: find.byType(Scrollable),
      );
      await tester.drag(list.first, const Offset(0, -2000));
      await tester.pump(const Duration(milliseconds: 500));
      final last = tester.getRect(
        find.descendant(of: panel, matching: find.byType(ListTile)).last,
      );
      if (last.bottom > pcSize.height - 48 + 0.5) {
        failures.add('side panel: last item under the navigation bar $last');
      }
      await tester.runAsync(() => settings.setForcePcMode(null));
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );
}
