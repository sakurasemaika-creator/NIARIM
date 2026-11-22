// セーブツリーの画面のツリーの表示で、名前の無い保存の題（アプリの文
// 「保存」「Sauvegarde」「저장」）を1行の「…」で切らず、折り返して全部出す
// （DISC227）。利用者が付けた名前は今までどおり1行で省略する。
//
// ツリーの行の題は、利用者の名前もアプリの文も同じ1つの`Text`で`maxLines: 1`・
// 省略記号にしていたので、行に入らないアプリの文が「Sauvega…」と切れていた
// （スロットの表示のメモの行〔DISC220〕と同じ形）。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、名前の無い保存（一番上と、その下の
// 枝）の題が1行に限られず省略されないこと、行に入る語を途中で折らないこと、
// 利用者の名前の保存の題は1行・省略記号であること、はみ出さないことを見る。
// 1語が行より広い（どう並べても入らない）語も失敗として数える
// （所有者の判断、2026-11-22：行より広い1語は短い訳に替える）。仏語・西語の題「Sauvegarde」「Guardado」はどの短い訳も
// 320px・文字2倍の題の欄（80px）に入らないので、ツリーを横へ広げる。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

/// 利用者が付けた名前（行に入らない長さ）。
const _userName = 'Background done, ready for the colour pass';

/// 描いた文から、幅の無い字（語結合子・幅の無い空白）を除き、改行しない
/// 空白を普通の空白にしたもの。
String _plain(String text) => text
    .replaceAll('⁠', '')
    .replaceAll('​', '')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];
  final rootKey = GlobalKey();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_tree_node_title_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [locale]のアプリで作品を1つ作り、ツリー方式で名前の無い保存・その下の
  /// 名前の無い保存・利用者の名前の保存を作ってから、セーブツリーの画面を
  /// ツリーの表示で開く。
  Future<void> openTree(WidgetTester tester, Locale locale) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = const Size(360, _height);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': locale.toLanguageTag().replaceAll('-', '_'),
    });
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final projects = home.read<ProjectService>();
    final saves = home.read<SaveTreeService>()..setTreeMode(true);
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'Storyboard',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    Future<String> save({String? parentId, String? comment}) async =>
        (await tester.runAsync(
          () => saves.saveAsChild(
            projectId: project.id,
            project: project,
            scenes: projects.scenesOf(project.id),
            tileManager: projects.tileManagerOf(project.id),
            parentId: parentId,
            comment: comment,
          ),
        ))!.id;
    final root = await save();
    await save(parentId: root);
    await save(parentId: root, comment: _userName);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: locale,
              theme: context.watch<ThemeService>().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SaveTreeScreen(
                projectId: project.id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
            ),
          ),
        ),
      ),
    );
    await settleIo(tester, 6);
    tester.takeException();
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('save tree node default titles are shown in full ($tag)', (
      tester,
    ) async {
      await openTree(tester, locale);
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, _height);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            final at = '${width.toInt()}px x$scale';
            final rows = find.descendant(
              of: find.byKey(const Key('saveTreeHorizontalScroll')),
              matching: find.byType(ListTile),
            );
            var defaults = 0;
            var named = 0;
            for (final row in rows.evaluate()) {
              final rowFinder = find.byElementPredicate((e) => e == row);
              final title = (row.widget as ListTile).title!;
              final titleParagraphs = textParagraphsIn(
                find.descendant(of: rowFinder, matching: find.byWidget(title)),
              );
              for (final paragraph in titleParagraphs) {
                final shown = _plain(
                  paragraph.text.toPlainText(includeSemanticsLabels: false),
                );
                if (shown == _plain(l10n.saveTreeNodeDefaultTitle)) {
                  defaults++;
                  if (paragraph.didExceedMaxLines) {
                    problems.add(
                      '$at: the app title「$shown」is cut short: '
                      '${ParagraphLines(paragraph).lines.join(' / ')}',
                    );
                  }
                  if (paragraph.maxLines != null) {
                    problems.add(
                      '$at: the app title「$shown」is limited to '
                      '${paragraph.maxLines} line(s)',
                    );
                  }
                  for (final broken in wordsBrokenThatFit(paragraph)) {
                    problems.add('$at: $broken');
                  }
                  for (final wide in wordsWiderThanLine(paragraph)) {
                    problems.add(
                      '$tag $at: wider than the line (DISC155): $wide',
                    );
                  }
                  for (final char in ParagraphLines(
                    paragraph,
                  ).charsOutsideWidth()) {
                    problems.add('$at: runs past its line: $char');
                  }
                } else if (shown == _userName) {
                  named++;
                  if (paragraph.maxLines != 1 ||
                      paragraph.overflow != TextOverflow.ellipsis) {
                    problems.add(
                      '$at: the user name is not one line with an ellipsis',
                    );
                  }
                }
              }
            }
            if (defaults != 2 || named != 1) {
              problems.add(
                '$at: found $defaults default titles and $named named titles',
              );
            }
            for (final error in errors) {
              problems.add('$at: ${error.split('\n').first}');
            }
            errors.clear();
            if (shots != null && scale == 2.0 && width < 400) {
              await tester.runAsync(() async {
                final boundary =
                    rootKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC227-${tag}_${width.toInt()}_x2.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(20)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
