import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/empty_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

// ホームの小さな直しの見張り（文の折り返し・色・並び・タブの状態）。
// 本物のアプリを起動処理から組み立てて、ホームを開いて確かめる。

typedef _Home = ({
  ProjectService projects,
  SettingsService settings,
  ThemeService themes,
});

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 本物のファイルの読み書きを待ってから描く。
Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<_Home> _openHome(
  WidgetTester tester, {
  String language = 'ja',
  Size size = const Size(390, 844),
  double scale = 1,
  Map<String, Object> prefs = const {},
}) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': language,
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    ...prefs,
  });
  final dir = Directory.systemTemp.createTempSync('home-small-fixes-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 後始末の途中で保存が走っていても、テストの結果は変えない。
    }
  });
  // 作品一覧は書き出したファイルを本物の読み書きで調べる。先に調べておく
  // （偽の時計の下では終わらず、タブが読み込み中のままになる）。
  ExportStorage.invalidate();
  Directory('${dir.path}/exports').createSync();
  await tester.runAsync(
    () => ExportEngine.listExportedFiles(forceRefresh: true),
  );
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await _frames(tester);
  await _settleIo(tester);
  final home = tester.element(find.byType(HomeScreen));
  return (
    projects: home.read<ProjectService>(),
    settings: home.read<SettingsService>(),
    themes: home.read<ThemeService>(),
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

Future<void> _showTab(WidgetTester tester, int index) async {
  tester
      .widget<TabBarView>(find.byType(TabBarView))
      .controller!
      .animateTo(index);
  await _frames(tester, 8);
  await _settleIo(tester, 2);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

/// 語（空白で区切った単位）の途中で行が替わっている所。
List<String> _midWordBreaks(ParagraphLines lines) {
  final breaks = <String>[];
  for (var i = 1; i < lines.visible.length; i++) {
    final before = lines.lineOf(i - 1);
    final after = lines.lineOf(i);
    if (before == null || after == null || before == after) continue;
    if (lines.visible[i - 1].trim().isEmpty ||
        lines.visible[i].trim().isEmpty) {
      continue;
    }
    breaks.add('${lines.visible[i - 1]}|${lines.visible[i]}');
  }
  return breaks;
}

/// WCAGのコントラスト比（1〜21）。
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 韓国語は語（空白で区切った単位）の途中で折り返さない。空の一覧の文
  // 「프로젝트가 없습니다」が「…없습니／다」、「＋ 버튼으로 새로 만들기」が
  // 「…만들／기」と語の途中で切れていた（幅320px・文字2倍）。
  testWidgets('Korean empty states wrap only between words', (tester) async {
    final handle = tester.ensureSemantics();
    await _openHome(
      tester,
      language: 'ko',
      size: const Size(320, 568),
      scale: 2,
    );
    final l10n = _l10n(tester);
    final seen = <String>[];

    Future<void> check(String where, List<String> expected) async {
      final placeholder = find.byType(EmptyStatePlaceholder);
      expect(placeholder, findsOneWidget, reason: where);
      for (final plain in expected) {
        // 元の文のまま探せる（語結合子は描くときだけ入れる）。
        expect(
          find.descendant(of: placeholder, matching: find.text(plain)),
          findsOneWidget,
          reason: '$where: $plain',
        );
      }
      final drawn = <String>[];
      for (final element
          in find
              .descendant(of: placeholder, matching: find.byType(RichText))
              .evaluate()) {
        final lines = ParagraphLines(element.renderObject! as RenderParagraph);
        // 丸の中のアイコンも1字の段落として描かれる。
        if (lines.visible.trim().length < 2) continue;
        expect(
          _midWordBreaks(lines),
          isEmpty,
          reason: '$where: ${lines.lines.join(' / ')}',
        );
        expect(lines.charsOutsideWidth(), isEmpty, reason: where);
        drawn.add(lines.visible);
      }
      expect(drawn, containsAll(expected), reason: where);
      seen.addAll(drawn);
    }

    await check('projects', [
      l10n.projectListEmptyTitle,
      l10n.projectListEmptyHint,
    ]);
    await _showTab(tester, 1);
    await check('works', [l10n.homeWorksEmpty, l10n.homeWorksEmptyHint]);
    await _showTab(tester, 2);
    await check('shared received', [l10n.homeSharedEmpty]);
    tester
        .widget<SegmentedButton<bool>>(
          find.byKey(const Key('sharedDirectionSegmentedControl')),
        )
        .onSelectionChanged!({true});
    await _settleIo(tester);
    await check('shared created', const []);
    await _showTab(tester, 3);
    await check('trash', [l10n.homeTrashEmpty]);
    // 読み上げには語結合子を除いた元の文を渡す。
    final labels = [
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        if (node.label.isNotEmpty) node.label,
    ];
    expect(
      labels.where((label) => label.contains(wordJoiner)).toList(),
      isEmpty,
      reason: '$labels',
    );
    expect(
      labels.any((label) => label.contains(l10n.homeTrashEmpty)),
      isTrue,
      reason: '$labels',
    );
    // プロジェクト2・作品2・受け取った共有1・作成した共有1・ゴミ箱1。
    expect(seen, hasLength(7), reason: '$seen');
    expect(tester.takeException(), isNull);
    handle.dispose();
    await _close(tester);
  });

  // ハングルを含まない文はこれまでと同じ（語結合子を入れない）。
  testWidgets('empty states in other languages are drawn as before', (
    tester,
  ) async {
    for (final language in ['ja', 'en', 'zh']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          home: const Scaffold(
            body: EmptyStatePlaceholder(
              icon: Icons.delete_outline,
              title: 'ゴミ箱は空です / Trash is empty / 回收站是空的',
              hint: '＋ボタンで新規作成 / Tap + to create',
            ),
          ),
        ),
      );
      for (final element in find.byType(RichText).evaluate()) {
        expect(
          (element.renderObject! as RenderParagraph).text.toPlainText(),
          isNot(contains(wordJoiner)),
        );
      }
      expect(find.byType(Text), findsNWidgets(2));
    }
  });

  // タブはアプリバー（メニュー背景色）の上に描く。選んでいないタブの色は
  // メニュー文字色から作る。本文の文字色から作っていたので、メニューが暗く
  // 本文の文字も暗いテーマでは、選んでいないタブがほとんど見えなかった。
  testWidgets('unselected Home tabs take their colour from the app bar '
      'foreground', (tester) async {
    const preset = AppThemePreset(
      id: ThemeService.customCurrentId,
      name: 'dark menu, dark body text',
      accentColor: Color(0xFF2E7D6B),
      textColor: Color(0xFF1F2328),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFEDEFF2),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF7F4EC),
      menuBgColor: Color(0xFF1E2430),
      selectionColor: Color(0xFF2E7D6B),
      updateMarkColor: Color(0xFFE0A100),
    );
    final home = await _openHome(tester, size: const Size(390, 844));
    home.themes.previewCurrent(preset);
    await _frames(tester, 10);
    // 幅390pxはアイコンだけ、幅1280pxはアイコンと名前。
    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 844);
      await _frames(tester, 10);
      final background = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(background, preset.menuBgColor);
      final scheme = Theme.of(
        tester.element(find.byType(HomeScreen)),
      ).colorScheme;
      for (var i = 0; i < 4; i++) {
        final tab = find.byKey(ValueKey('home_tab_$i'));
        final colours = <Color>[
          for (final icon
              in find
                  .descendant(of: tab, matching: find.byType(Icon))
                  .evaluate())
            (icon.widget as Icon).color ?? IconTheme.of(icon).color!,
          for (final label
              in find
                  .descendant(of: tab, matching: find.byType(RichText))
                  .evaluate())
            if ((label.renderObject! as RenderParagraph).text
                    .toPlainText()
                    .length >
                1)
              (label.renderObject! as RenderParagraph).text.style!.color!,
        ];
        expect(colours, hasLength(width > 1000 ? 2 : 1), reason: 'tab $i');
        for (final colour in colours) {
          final where = 'tab $i at ${width.round()}px: $colour on $background';
          if (i == 0) {
            // 選んでいるタブは差し色のまま。
            expect(colour, scheme.primary, reason: where);
            continue;
          }
          expect(
            colour,
            preset.menuTextColor.withValues(alpha: 0.7),
            reason: where,
          );
          expect(
            _contrast(Color.alphaBlend(colour, background), background),
            greaterThan(3),
            reason: where,
          );
        }
      }
    }
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}
