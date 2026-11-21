// 保存の管理の画面（スロット）で、スロットの題（「Emplacement 1」）を語の
// 途中で折らず、語と番号を離さない（DISC191）。
//
// 題はサムネイル（58px）の横の欄に置いていたので、320px・文字2倍の仏語では
// 欄が202pxしかなく、題が「Emplacemen / t 1」と語の途中で折れていた。題は語と
// 番号を1つのかたまりにし、それがサムネイルの横に入らない幅では、サムネイルを
// 上に置いて題・メモ・日時を行の幅いっぱいで出す。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、保存したスロット（メモなし・
// メモあり）と空のスロットのカードの文が、カードの幅に入る語を途中で折らない
// こと、題が1行に入る幅では1行（語と番号が同じ行）であること、はみ出さない
// ことを見張る。
//
// 空のスロットの「保存データなし」は普通の`Text`で、韓国語・360px・文字2倍で
// 「저장 데이터 없 / 음」と語の途中で折れていた（DISC208）。韓国語の語も、
// 入る幅では途中で折らないことを見張る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

/// カードの中身の左右の余白と枠。
const _cardInset = 2 * 14.0 + 2 * 1.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_slot_words_');
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

  /// [language]のアプリで作品を1つ作り、スロット1（メモなし）・スロット2
  /// （メモあり）へ保存し、スロット4にはメモだけを付けてから、保存の管理の
  /// 画面を開く。
  Future<void> openSlots(WidgetTester tester, String language) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = const Size(360, _height);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': language,
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
    // 保存の無いスロットのメモ（メモの下に「保存データなし」が出る）。
    await tester.runAsync(() => saves.setSlotMemo(project.id, 3, 'Idea'));
    appRouter.push('/save-tree/${project.id}');
    await settleIo(tester, 6);
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('slot titles keep their words and numbers whole ($tag)', (
      tester,
    ) async {
      await openSlots(tester, language);
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
                  .ancestor(of: title, matching: find.byType(InkWell))
                  .first;
              final inner = tester.getSize(card).width - _cardInset;
              for (final paragraph in textParagraphsIn(card)) {
                for (final broken in wordsBrokenThatFit(
                  paragraph,
                  fitWidth: inner > paragraph.constraints.maxWidth
                      ? inner
                      : paragraph.constraints.maxWidth,
                )) {
                  problems.add('$at slot $slot: $broken');
                }
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
              if (joined.width > inner + 0.5) {
                debugPrint(
                  '$tag $at: 「$label」 is ${joined.width.toStringAsFixed(1)}px,'
                  ' wider than the card (${inner.toStringAsFixed(1)}px)',
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
