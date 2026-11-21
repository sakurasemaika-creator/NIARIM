// 保存の管理の画面の上書き・読み込みの確認で、スロットの題（「Emplacement 1」）を
// 語の途中で折らず、語と番号を離さない（DISC209）。
//
// 確認の中の要約（_SlotConfirmationSummary）は、題を68pxのサムネイルの横の
// 欄に置いていた。320px・文字2倍の仏語では、ダイアログが画面の左右に既定の
// 40pxずつ空けて240pxしかなく、欄が122pxで、題が「Emplacemen / t 1」と語の
// 途中で折れていた。スロットのカード（DISC191）と同じく、題は語と番号を1つの
// かたまりにし、それがサムネイルの横に入らない幅ではサムネイルを上に置く。
// ダイアログは、Materialの最小の幅（280px）を画面の左右に16pxずつ残せる限り
// 取る（DISC189と同じ）。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、上書きと読み込みの確認の文が、
// 入る幅に入る語を途中で折らないこと（要約の中の語は、要約の幅で数える）、
// 題が要約の幅に入るなら1行であること、ダイアログが取れる幅で描かれること、
// はみ出さないことを見張る。
import 'dart:io';
import 'dart:math' as math;

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

/// Materialのダイアログの最小の幅・画面の左右に残す空きの下限と既定。
const _minDialogWidth = 280.0;
const _screenMargin = 16.0;
const _usualMargin = 40.0;

/// 要約の中身の左右の余白と枠。
const _summaryInset = 2 * 10.0 + 2 * 1.0;

/// 幅[width]の画面で、ダイアログが少なくとも取れる幅（最小の幅280pxを、
/// 左右に16pxずつ残せる限り。広い画面では既定の空き40pxを除いた幅）。
double _dialogRoom(double width) {
  final usual = width - 2 * _usualMargin;
  final widest = width - 2 * _screenMargin;
  final room = usual > _minDialogWidth ? usual : _minDialogWidth;
  return room < widest ? room : widest;
}

/// 開いているダイアログ（[AlertDialog]の面）の幅。
double _dialogWidth(WidgetTester tester) => tester
    .getRect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    )
    .width;

/// 要約（枠のある入れ物）。
final Finder _summary = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).border != null,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_slot_confirm_');
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
  /// （メモあり）へ保存してから、保存の管理の画面を作品の詳細から開く
  /// （読み込みもできる入口）。
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
    appRouter.push('/save-tree/${project.id}?entry=projectDetail');
    await settleIo(tester, 6);
  }

  /// 開いている確認を、幅と文字の大きさを変えながら調べる。[label]は確認の
  /// 対象のスロットの題。
  Future<List<String>> sweep(
    WidgetTester tester,
    String where,
    String label,
  ) async {
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
          final at = '$where ${width.toInt()}px x$scale';
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget, reason: at);
          final room = _dialogRoom(width);
          final drawn = _dialogWidth(tester);
          // 狭い画面では、ダイアログはMaterialの最小の幅を取る（広い画面では、
          // 中身が狭ければダイアログも狭くてよい）。
          if (width < 360 && drawn < room - 0.5) {
            problems.add(
              '$at: the dialog is ${drawn.toStringAsFixed(0)}px, narrower '
              'than it can be (${room.toStringAsFixed(0)}px)',
            );
          }
          final missing = math.max(0.0, room - drawn);
          expect(_summary, findsOneWidget, reason: at);
          final inner = tester.getSize(_summary).width - _summaryInset;
          final inSummary = textParagraphsIn(_summary).toSet();
          for (final paragraph in textParagraphsIn(dialog)) {
            final fit = inSummary.contains(paragraph)
                ? math.max(paragraph.constraints.maxWidth, inner + missing)
                : paragraph.constraints.maxWidth + missing;
            for (final broken in wordsBrokenThatFit(paragraph, fitWidth: fit)) {
              problems.add('$at: $broken');
            }
            // 1つの語がその幅より広い（どう並べても途中で折れる）ときは
            // 数えない。所有者の決まりを待っている件（DISC118・145・155）。
            for (final wide in wordsWiderThanLine(paragraph, fitWidth: fit)) {
              debugPrint('$at: wider than the line (DISC155): $wide');
            }
          }
          // 題は、語と番号をつないだ幅が要約に入るなら1行。
          final title = textParagraphsIn(
            find.descendant(of: _summary, matching: find.text(label)).first,
          ).single;
          final joined = TextPainter(
            text: TextSpan(
              text: label.replaceAll(' ', ' '),
              style: title.text.style,
            ),
            textDirection: TextDirection.ltr,
            textScaler: title.textScaler,
          )..layout();
          final lines = ParagraphLines(title).lines;
          if (joined.width <= inner + 0.5 && lines.length > 1) {
            problems.add(
              '$at: the title「$label」(${joined.width.toStringAsFixed(0)}px, '
              'summary ${inner.toStringAsFixed(0)}px) is on ${lines.length} '
              'lines: ${lines.join(' / ')}',
            );
          }
          joined.dispose();
          for (final error in errors) {
            problems.add('$at: $error');
          }
          errors.clear();
        }
      }
    } finally {
      FlutterError.onError = onError;
    }
    tester.view.physicalSize = const Size(360, _height);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return problems;
  }

  Future<void> cancel(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.commonCancel),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byType(AlertDialog).evaluate().isNotEmpty;
      i++
    ) {
      await settleIo(tester, 1);
    }
    expect(find.byType(AlertDialog), findsNothing);
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the slot overwrite and restore confirmations keep their '
        'words whole ($tag)', (tester) async {
      await openSlots(tester, language);
      final problems = <String>[];

      // スロット1（保存・メモなし）へ書き込む＝上書きの確認。
      await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
      await settleIo(tester, 3);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.saveTreeOverwriteConfirmBody),
        ),
        findsOneWidget,
      );
      problems.addAll(
        await sweep(tester, 'overwrite', l10n.saveTreeSlotLabel(1)),
      );
      await cancel(tester, l10n);

      // スロット2（保存・メモあり）を読み込む確認。
      final load = find.descendant(
        of: find.byKey(const ValueKey('manual-save-slot-1')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == l10n.saveTreeSlotLoadTooltip,
        ),
      );
      await tester.ensureVisible(load);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(load).onPressed, isNotNull);
      await tester.tap(load);
      await settleIo(tester, 3);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.saveTreeProjectDetailResumeBody),
        ),
        findsOneWidget,
      );
      problems.addAll(
        await sweep(tester, 'restore', l10n.saveTreeSlotLabel(2)),
      );
      await cancel(tester, l10n);

      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }
}
