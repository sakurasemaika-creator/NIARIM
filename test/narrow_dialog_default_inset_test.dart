// 左右の空き（insetPadding）を渡していないダイアログも、狭い画面ではMaterialの
// 最小の幅（280px）を取る（DISC211）。
//
// ダイアログは画面の左右に既定で40pxずつ空けるので、320pxの画面では240pxに
// なり、Materialの最小の幅より狭かった。DISC172・189では、打つ欄のある保存の
// ダイアログと、いくつかの確認（キャンバス・タイムラインの「プロジェクト一覧へ
// 戻る」、ゴミ箱へ移す・完全に削除する）にだけ狭い画面の空きを渡していて、
// ホームの「貼り付けたものをゴミ箱へ」「ゴミ箱から戻す」など、ほかの
// ダイアログ（lib配下で約120か所）は240pxのままだった（文字2倍の韓国語で、
// 280pxなら1行に入る語「복원하시겠습니까?」が字の途中で折れた）。
//
// 画面から開いたダイアログは、空きを渡していなければ、狭い画面で最小の幅が
// 取れるところまで左右の空きを縮める（dialogInsetPadding）。ここでは、
// （1）ホームの2つの確認を本物のアプリで開き、仏・西・韓・320px・文字1.0〜2.0で
// ダイアログが280pxで描かれ、その幅に入る題・本文・ボタンの語が途中で折れない
// こと、360・412pxではダイアログの形（左右の空き40px）が今までどおりである
// こと、（2）メニューの面のテーマ（本文とメニューの文字色が違う自作のテーマ）
// でもダイアログの中身はメニューの文字色のまま280pxを取ること、（3）自分で
// 空きを渡したダイアログはその空きのままであること、（4）開いたまま画面の
// 幅が360pxをまたいでも、ダイアログの中身は作り直されない（打った文字・
// 状態が消えない）ことを見張る。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

/// Materialのダイアログの最小の幅・画面の左右に残す空きの下限と既定。
const _minDialogWidth = 280.0;
const _screenMargin = 16.0;
const _usualMargin = 40.0;

/// 幅[width]の画面で、ダイアログが少なくとも取れる幅（最小の幅280pxを、
/// 左右に16pxずつ残せる限り。広い画面では既定の空き40pxを除いた幅）。
double _dialogRoom(double width) {
  final usual = width - 2 * _usualMargin;
  final widest = width - 2 * _screenMargin;
  final room = usual > _minDialogWidth ? usual : _minDialogWidth;
  return room < widest ? room : widest;
}

/// 開いているダイアログ（[AlertDialog]の面）の位置と大きさ。
Rect _dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

/// 用紙は明るく、メニューは暗い。本文の文字は暗く、メニューの文字は明るい
/// （menu_surface_ink_testと同じ自作のテーマ）。
const _darkMenu = AppThemePreset(
  id: ThemeService.customCurrentId,
  name: 'Dark menu',
  accentColor: Color(0xFF1E88A8),
  accentTextColor: Color(0xFF0B5F78),
  textColor: Color(0xFF20242A),
  buttonTextColor: Color(0xFFFFFFFF),
  menuTextColor: Color(0xFFEDEFF2),
  selectionTextColor: Color(0xFFFFFFFF),
  panelBgColor: Color(0xFFF4F1EA),
  menuBgColor: Color(0xFF262B33),
  selectionColor: Color(0xFF2F6F5E),
  updateMarkColor: Color(0xFFFFB020),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 開いている確認[dialog]を、幅と文字の大きさを変えながら調べる。
  Future<List<String>> sweep(
    HomeClipboardHarness home,
    Finder dialog,
    String where,
  ) async {
    final tester = home.tester;
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
          expect(dialog, findsOneWidget, reason: at);
          final rect = _dialogRect(tester);
          final room = _dialogRoom(width);
          // 狭い画面では、ダイアログはMaterialの最小の幅を取る（広い画面では、
          // 中身が狭ければダイアログも狭くてよい）。
          if (width < 360 && rect.width < room - 0.5) {
            problems.add(
              '$at: the dialog is ${rect.width.toStringAsFixed(0)}px, '
              'narrower than it can be (${room.toStringAsFixed(0)}px)',
            );
          }
          if (width >= 360) {
            // 広い画面では、ダイアログの左右の空きは今までどおり（40px）。
            if (rect.left < _usualMargin - 0.5 ||
                rect.right > width - _usualMargin + 0.5) {
              problems.add(
                '$at: the dialog lost its usual margins '
                '(${rect.left.toStringAsFixed(0)}–'
                '${rect.right.toStringAsFixed(0)}px)',
              );
            }
          }
          final missing = math.max(0.0, room - rect.width);
          for (final paragraph in textParagraphsIn(dialog)) {
            final fit = paragraph.constraints.maxWidth + missing;
            for (final broken in wordsBrokenThatFit(paragraph, fitWidth: fit)) {
              problems.add('$at: $broken');
            }
            // 1つの語がその幅より広い（どう並べても途中で折れる）ときは
            // 数えない。所有者の決まりを待っている件（DISC118・145・155）。
            for (final wide in wordsWiderThanLine(paragraph, fitWidth: fit)) {
              debugPrint('$at: wider than the line (DISC155): $wide');
            }
          }
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

  Future<void> cancel(HomeClipboardHarness home, Finder dialog) async {
    await home.tester.tap(
      find.descendant(of: dialog, matching: find.text(home.l10n.commonCancel)),
    );
    await home.settle();
    expect(dialog, findsNothing);
  }

  for (final language in ['fr', 'es', 'ko']) {
    testWidgets('the paste-to-trash and restore questions take the dialog '
        'width on a narrow screen ($language)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        size: const Size(360, _height),
        realFonts: true,
      );
      final korean = language == 'ko';
      final moved = korean ? '애니메이션 연습' : 'Storyboard practice';
      final work = await home.addWork(moved);
      final problems = <String>[];

      // ゴミ箱のタブへ貼り付ける確認。
      await home.copy([moved]);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final paste = find.byKey(const Key('homePasteToTrashDialog'));
      expect(paste, findsOneWidget);
      problems.addAll(await sweep(home, paste, 'paste to trash'));
      await cancel(home, paste);

      // ゴミ箱のカードの「復元」で戻す確認。
      await tester.runAsync(() => home.projects.deleteProject(work.id));
      await home.settleIo(3);
      await home.showTab(0);
      await home.showTab(3);
      final restoreButton = find.byKey(ValueKey('trash-restore-${work.id}'));
      await tester.ensureVisible(restoreButton);
      await home.settle();
      await tester.tap(restoreButton);
      await home.settle();
      final restore = find.byKey(const Key('homeTrashRestoreConfirmation'));
      expect(restore, findsOneWidget);
      problems.addAll(await sweep(home, restore, 'restore'));
      await cancel(home, restore);

      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  /// [theme]のアプリで、押すと[dialog]を開くボタンだけの画面を出す。
  Future<void> pumpHost(
    WidgetTester tester,
    ThemeData theme,
    WidgetBuilder dialog,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, _height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: dialog),
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
  }

  Future<void> resize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, _height);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// ダイアログが取れる幅いっぱいに広がる長さの本文。
  const longBody =
      'dialog body that is long enough to fill the whole width the dialog '
      'can take on every screen in this test';

  Widget plainDialog(BuildContext context) => AlertDialog(
    title: const Text('dialog title'),
    content: const Text(longBody),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('dialog action'),
      ),
    ],
  );

  testWidgets('a dialog without its own margins takes the minimum width on a '
      'narrow screen and keeps the usual margins on a wide one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    await pumpHost(tester, themes.themeData, plainDialog);
    // 360・412pxでは今までどおり（左右40px、上下24px）。
    for (final width in [360.0, 412.0]) {
      await resize(tester, width);
      final rect = _dialogRect(tester);
      expect(rect.left, closeTo(_usualMargin, 0.5), reason: '${width}px');
      expect(rect.right, closeTo(width - _usualMargin, 0.5));
    }
    // 320pxでは、最小の幅（280px）を取る（左右20px）。
    await resize(tester, 320);
    expect(_dialogRect(tester).width, closeTo(_minDialogWidth, 0.5));
    expect(_dialogRect(tester).left, closeTo(20, 0.5));
    // 300pxでは、左右に16pxを残す（268px）。
    await resize(tester, 300);
    expect(_dialogRect(tester).left, closeTo(_screenMargin, 0.5));
    expect(_dialogRect(tester).width, closeTo(300 - 2 * _screenMargin, 0.5));
  });

  testWidgets('a dialog on the menu surface keeps the menu text colour and '
      'takes the minimum width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    themes.previewCurrent(_darkMenu);
    addTearDown(themes.dispose);
    await pumpHost(tester, themes.themeData, plainDialog);
    await resize(tester, 320);
    expect(_dialogRect(tester).width, closeTo(_minDialogWidth, 0.5));
    for (final label in ['dialog title', longBody]) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      expect(
        paragraph.text.style?.color?.withAlpha(255),
        _darkMenu.menuTextColor.withAlpha(255),
        reason: '$label is written in the menu text colour',
      );
    }
    await resize(tester, 360);
    expect(_dialogRect(tester).left, closeTo(_usualMargin, 0.5));
  });

  testWidgets('a dialog that passes its own margins keeps them', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    await pumpHost(
      tester,
      themes.themeData,
      (context) => AlertDialog(
        insetPadding: const EdgeInsets.all(8),
        title: const Text('dialog title'),
        content: const Text(longBody),
      ),
    );
    for (final width in [320.0, 360.0]) {
      await resize(tester, width);
      expect(_dialogRect(tester).left, closeTo(8, 0.5), reason: '${width}px');
      expect(_dialogRect(tester).right, closeTo(width - 8, 0.5));
    }
  });

  testWidgets('an open dialog keeps its content when the screen crosses '
      '360px', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    final field = TextEditingController();
    addTearDown(field.dispose);
    var built = 0;
    await pumpHost(
      tester,
      themes.themeData,
      (context) => AlertDialog(
        title: const Text('dialog title'),
        content: StatefulBuilder(
          builder: (context, setState) {
            built++;
            return TextField(key: const ValueKey('field'), controller: field);
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.enterText(find.byKey(const ValueKey('field')), 'typed');
    await tester.pump();
    final state = tester.state(find.byType(StatefulBuilder));
    final editable = tester.state(find.byType(EditableText));
    for (final width in [320.0, 412.0, 300.0, 360.0]) {
      await resize(tester, width);
      expect(
        tester.state(find.byType(StatefulBuilder)),
        same(state),
        reason: '${width}px: the dialog content was built anew',
      );
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(field.text, 'typed');
    }
    expect(built, greaterThan(0));
  });
}
