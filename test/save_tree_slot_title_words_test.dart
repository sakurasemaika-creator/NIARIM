// セーブツリーの画面のスロットの表示で、スロットの題（「Emplacement 1」）を
// 語の途中で折らず、語と番号を離さない（DISC210）。
//
// 題はサムネイル（58px）の横の欄に置いていたので、320px・文字2倍の仏語では
// 欄が212pxしかなく、題（232px）が「Emplacement / 1」と番号だけ次の行へ
// 落ちていた。保存の管理の画面のカード（DISC191）と同じく、題は語と番号を
// 1つのかたまりにし、それがサムネイルの横に入らない幅では、サムネイルを上に
// 置いて題・メモ・日時を行の幅いっぱいで出す。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、保存したスロット（メモなし・
// メモあり）・空のスロット・メモだけのスロットのカードの文が、カードの幅に
// 入る語を途中で折らないこと（韓国語の語も）、題が1行に入る幅では1行（語と
// 番号が同じ行）であること、はみ出さないことを見張る。
//
// メモの行のアプリの文（「保存データなし」・スロットの題）は、1行で「…」と
// 切らずに折り返して全部出す（DISC220。320/360px・文字2倍で「Aucune
// donnée…」「저장 데이터 …」と切れていた）。利用者のメモは1行で省略する。
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

/// カードの中身の左右の余白。
const _cardInset = 2 * 14.0;

/// 利用者が付けたメモ（[openSlots]で付けるもの）。
const _userMemos = {'Background done', 'Idea'};

/// 描いた文から、幅の無い字（語結合子・幅の無い空白）を除き、改行しない
/// 空白を普通の空白にしたもの。
String _plain(String text) => text
    .replaceAll('\u2060', '')
    .replaceAll('\u200B', '')
    .replaceAll('\u00A0', ' ')
    .replaceAll('\u202F', ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;
  final shots = Platform.environment['NIARIM_SET1_SHOTS'];
  final rootKey = GlobalKey();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_tree_slot_words_');
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

  /// [locale]のアプリで作品を1つ作り、スロット1（メモなし）・スロット2
  /// （メモあり）へ保存し、スロット4にはメモだけを付けてから、セーブツリーの
  /// 画面をスロットの表示で開く。
  Future<void> openSlots(WidgetTester tester, Locale locale) async {
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
    final saves = home.read<SaveTreeService>()..setTreeMode(false);
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
    for (final (slot, comment) in [(0, null), (1, 'Background done')]) {
      await tester.runAsync(
        () => saves.saveToSlot(
          projectId: project.id,
          slotIndex: slot,
          project: project,
          scenes: projects.scenesOf(project.id),
          tileManager: projects.tileManagerOf(project.id),
          comment: comment,
        ),
      );
    }
    await tester.runAsync(() => saves.setSlotMemo(project.id, 3, 'Idea'));
    // スロットの表示は、セーブツリーの画面をスロット方式で開いたときのもの。
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

    testWidgets('save tree slot titles keep their words and numbers whole '
        '($tag)', (tester) async {
      await openSlots(tester, locale);
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
            // スロット1（保存・メモなし）・2（保存・メモあり）・3（空）・
            // 4（メモだけ）。
            for (final slot in [1, 2, 3, 4]) {
              final label = l10n.saveTreeSlotLabel(slot);
              await tester.ensureVisible(
                find.text(label, skipOffstage: false).first,
              );
              await tester.pump();
              final title = find.text(label).first;
              final card = find
                  .ancestor(of: title, matching: find.byType(Material))
                  .first;
              final inner = tester.getSize(card).width - _cardInset;
              for (final paragraph in textParagraphsIn(card)) {
                final fit = inner > paragraph.constraints.maxWidth
                    ? inner
                    : paragraph.constraints.maxWidth;
                for (final broken in wordsBrokenThatFit(
                  paragraph,
                  fitWidth: fit,
                )) {
                  problems.add('$at slot $slot: $broken');
                }
                // 1つの語がカードより広い（どう並べても途中で折れる）ときは
                // 数えない。所有者の決まりを待っている件（DISC118・145・155）。
                for (final wide in wordsWiderThanLine(
                  paragraph,
                  fitWidth: fit,
                )) {
                  debugPrint(
                    '$tag $at slot $slot: wider than the line (DISC155): $wide',
                  );
                }
              }
              // メモの行のアプリの文（「保存データなし」・スロットの題）は
              // 1行で「…」と切らず、折り返して全部出す（DISC220）。利用者の
              // メモは1行で省略する。
              for (final paragraph in textParagraphsIn(card)) {
                final shown = _plain(
                  paragraph.text.toPlainText(includeSemanticsLabels: false),
                );
                if (shown == _plain(l10n.saveTreeNoDataLabel) ||
                    shown == _plain(label)) {
                  if (paragraph.didExceedMaxLines) {
                    problems.add(
                      '$at slot $slot: the app text「$shown」is cut short: '
                      '${ParagraphLines(paragraph).lines.join(' / ')}',
                    );
                  }
                  if (paragraph.maxLines != null) {
                    problems.add(
                      '$at slot $slot: the app text「$shown」is limited to '
                      '${paragraph.maxLines} line(s)',
                    );
                  }
                } else if (_userMemos.contains(shown) &&
                    (paragraph.maxLines != 1 ||
                        paragraph.overflow != TextOverflow.ellipsis)) {
                  problems.add(
                    '$at slot $slot: the memo「$shown」is not one line with '
                    'an ellipsis',
                  );
                }
              }
              if (shots != null && slot == 3 && scale == 2.0 && width < 400) {
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC220-${tag}_${width.toInt()}_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
              }
              // 題は、語と番号をつないだ幅がカードに入るなら1行。
              final paragraph = textParagraphsIn(title).single;
              final joined = TextPainter(
                text: TextSpan(
                  text: label.replaceAll(' ', ' '),
                  style: paragraph.text.style,
                ),
                textDirection: TextDirection.ltr,
                textScaler: paragraph.textScaler,
              )..layout();
              final lines = ParagraphLines(paragraph).lines;
              if (joined.width <= inner + 0.5 && lines.length > 1) {
                problems.add(
                  '$at slot $slot: the title「$label」'
                  '(${joined.width.toStringAsFixed(0)}px, card '
                  '${inner.toStringAsFixed(0)}px) is on ${lines.length} '
                  'lines: ${lines.join(' / ')}',
                );
              }
              joined.dispose();
            }
            for (final error in errors) {
              problems.add('$at: $error');
            }
            errors.clear();
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, 2000),
            );
            await tester.pump();
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }
}
