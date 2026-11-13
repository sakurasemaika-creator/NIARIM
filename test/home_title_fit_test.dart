import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

// ホームのアプリバーの題（画面名）は、入るときはそのまま出し、入らないときは
// 出さない（所有者の判断4：「画面名が入らないときは画面名は書かなくていい」）。
// 省略記号で「プロジ…」と切らない。読み上げの見出しの名前は残す。
// 本物のアプリを起動処理から組み立て、4つのタブと、単独で開く共有・ゴミ箱を
// 7言語・幅320/360/1280px・文字1.0/1.3/2.0倍で確かめる。

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
const _scales = [1.0, 1.3, 2.0];

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<SettingsService> _openHome(WidgetTester tester) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': 'ja',
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  final dir = Directory.systemTemp.createTempSync('home-title-fit-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
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
  return tester.element(find.byType(HomeScreen)).read<SettingsService>();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

/// いちばん上の画面のアプリバーの題の文字（タブの名前は除く）。
List<RenderParagraph> _titleParagraphs(WidgetTester tester, String title) {
  final appBar = find.byType(AppBar).last;
  return [
    for (final element
        in find.descendant(of: appBar, matching: find.text(title)).evaluate())
      if (element.findAncestorWidgetOfExactType<TabBar>() == null)
        element.renderObject! as RenderParagraph,
  ];
}

/// [title]を読み上げの見出しの名前に持つ所があるか。
bool _hasHeaderLabel(String title) => find.semantics
    .byPredicate((node) {
      final data = node.getSemanticsData();
      return data.label == title && data.flagsCollection.isHeader;
    })
    .evaluate()
    .isNotEmpty;

/// 題の状態：'shown'（切れずに出ている）・'hidden'（出していない）・
/// それ以外は問題の説明。
String _titleState(WidgetTester tester, String title) {
  final paragraphs = _titleParagraphs(tester, title);
  if (!_hasHeaderLabel(title)) return 'no header label';
  if (paragraphs.isEmpty) return 'hidden';
  if (paragraphs.length > 1) return '${paragraphs.length} titles';
  final paragraph = paragraphs.single;
  if (paragraph.didExceedMaxLines ||
      paragraph.getMaxIntrinsicWidth(double.infinity) >
          paragraph.size.width + 0.5) {
    return 'cut';
  }
  return 'shown';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home titles are shown whole or not at all, and stay the '
      'screen-reader heading (4 tabs, 7 languages)', (tester) async {
    final semantics = tester.ensureSemantics();
    final settings = await _openHome(tester);
    final problems = <String>[];
    final shown = <String>{};
    final hidden = <String>{};
    final tabController = tester
        .widget<TabBarView>(find.byType(TabBarView))
        .controller!;
    for (final tab in [0, 1, 2, 3]) {
      tabController.animateTo(tab);
      await _frames(tester, 8);
      await _settleIo(tester, 2);
      for (final language in _languages) {
        await tester.runAsync(() => settings.setLanguage(language));
        for (final width in [320.0, 360.0, 1280.0]) {
          for (final scale in _scales) {
            tester.view.physicalSize = Size(width, 800);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await _frames(tester, 3);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(HomeScreen)),
            )!;
            final title = [
              l10n.homeTabProjects,
              l10n.homeTabWorks,
              l10n.homeTabShared,
              l10n.homeTabTrash,
            ][tab];
            final where = 'tab$tab $language ${width.round()} x$scale';
            final state = _titleState(tester, title);
            if (state == 'shown') {
              shown.add(where);
            } else if (state == 'hidden') {
              hidden.add(where);
            } else {
              problems.add('$where: $state');
            }
            final error = tester.takeException();
            if (error != null) problems.add('$where: $error');
          }
        }
      }
    }
    debugPrint('hidden titles: ${(hidden.toList()..sort()).join(', ')}');
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 入る所では出す（広い画面はどれも入る）。
    for (final tab in [0, 1, 2, 3]) {
      for (final language in _languages) {
        for (final scale in _scales) {
          expect(shown, contains('tab$tab $language 1280 x$scale'));
        }
      }
    }
    // 幅320px・文字2倍の日本語の「プロジェクト」は戻る・表示サイズ・検索・
    // メニューのボタンの間に入らない（以前は「プロ…」と切れていた）。
    expect(hidden, contains('tab0 ja 320 x2.0'));
    semantics.dispose();
    await _close(tester);
  });

  testWidgets('the standalone Shared and Trash screens follow the same rule', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = await _openHome(tester);
    final problems = <String>[];
    for (final route in ['/shared', '/trash']) {
      appRouter.push(route);
      await _frames(tester, 10);
      await _settleIo(tester, 2);
      for (final language in _languages) {
        await tester.runAsync(() => settings.setLanguage(language));
        for (final width in [320.0, 360.0]) {
          for (final scale in _scales) {
            tester.view.physicalSize = Size(width, 800);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await _frames(tester, 3);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(AppBar).last),
            )!;
            final title = route == '/shared'
                ? l10n.homeTabShared
                : l10n.homeTabTrash;
            final where = '$route $language ${width.round()} x$scale';
            final state = _titleState(tester, title);
            if (state != 'shown' && state != 'hidden') {
              problems.add('$where: $state');
            }
            final error = tester.takeException();
            if (error != null) problems.add('$where: $error');
          }
        }
      }
      appRouter.pop();
      await _frames(tester, 10);
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    semantics.dispose();
    await _close(tester);
  });
}
