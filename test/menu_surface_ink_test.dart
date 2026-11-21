// メニューの色の面（ダイアログ・ボトムシート・知らせ・入力欄の下地）に書く
// 文字・アイコンが、本文の文字色ではなくメニューの文字色で書かれることの見張り。
//
// テーマ・外観では本文の文字色とメニューの背景色・文字色を別々に選べる。
// メニューを暗く・本文の文字を暗くしたテーマで、ダイアログ・シート・知らせ・
// 入力欄の文字が暗い下地に暗い字で書かれ、読めなかった（A003の3周目）。
// 組み込みのテーマは本文とメニューの文字色が同じなので見た目は変わらない。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/help/help_screen.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用紙は明るく、メニューは暗い。本文の文字は暗く、メニューの文字は明るい。
/// 差し色の文字・アイコンの色は別に選んである（A003の3周目の customdark）。
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

bool _sameInk(Color? color, Color ink) =>
    color != null && color.withAlpha(255) == ink.withAlpha(255);

/// [finder]（Text・Icon）の描いた色。
Color? _painted(WidgetTester tester, Finder finder) {
  final paragraph = find.descendant(
    of: finder,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  return tester
      .renderObject<RenderParagraph>(paragraph.first)
      .text
      .style
      ?.color;
}

/// [finder]（TextField）に打った文字の色。
Color? _fieldInk(WidgetTester tester, Finder finder) => tester
    .widget<EditableText>(
      find.descendant(of: finder, matching: find.byType(EditableText)),
    )
    .style
    .color;

Future<ThemeService> _themes(AppThemePreset preset) async {
  SharedPreferences.setMockInitialValues({});
  final service = ThemeService();
  await service.init();
  service.previewCurrent(preset);
  return service;
}

/// 画面（[home]）を、[preset]のテーマの本物のアプリと同じ形で出す。
Future<void> _pump(
  WidgetTester tester,
  ThemeService themes,
  Widget home, {
  TargetPlatform? platform,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final theme = themes.themeData;
  await tester.pumpWidget(
    MaterialApp(
      theme: platform == null ? theme : theme.copyWith(platform: platform),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// シート・ダイアログの中身：一覧の行・本文の書式を名前で指定した文・
/// 色を指定しないアイコン・入力欄・ドロップダウン。
Widget _menuBody(BuildContext context) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const ListTile(
      leading: Icon(Icons.folder_outlined),
      title: Text('row title'),
      subtitle: Text('row subtitle'),
    ),
    Text('styled body', style: Theme.of(context).textTheme.bodySmall),
    const Icon(Icons.info_outline, key: ValueKey('plainIcon')),
    const TextField(
      key: ValueKey('sheetField'),
      decoration: InputDecoration(hintText: 'hint'),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ボトムシートの中身（一覧の行・文・アイコン・入力欄）はメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: _menuBody,
            ),
            child: const Text('open sheet'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sheetField')), 'typed');
    await tester.pump();
    final ink = _darkMenu.menuTextColor;
    final wrong = <String>[
      for (final (label, finder) in [
        ('row title', find.text('row title')),
        ('row subtitle', find.text('row subtitle')),
        ('styled body', find.text('styled body')),
        ('plain icon', find.byKey(const ValueKey('plainIcon'))),
      ])
        if (!_sameInk(_painted(tester, finder), ink))
          '$label ${_painted(tester, finder)}',
      if (!_sameInk(
        _fieldInk(tester, find.byKey(const ValueKey('sheetField'))),
        ink,
      ))
        'field ${_fieldInk(tester, find.byKey(const ValueKey('sheetField')))}',
    ];
    expect(wrong, isEmpty, reason: 'sheet content not in menuTextColor $ink');
    // 一覧の行の先頭のアイコンは差し色の文字・アイコン色のまま（自動で
    // 差し替えない）。
    expect(
      _painted(tester, find.byIcon(Icons.folder_outlined)),
      _darkMenu.accentTextColor,
    );
  });

  testWidgets('ダイアログの題・本文・一覧の行・アイコン・入力欄はメニューの文字色、ボタンは差し色の文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('dialog title'),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Text('dialog body'), _menuBody(context)],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('dialog action'),
                  ),
                ],
              ),
            ),
            child: const Text('open dialog'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sheetField')), 'typed');
    await tester.pump();
    final ink = _darkMenu.menuTextColor;
    final wrong = <String>[
      for (final label in [
        'dialog title',
        'dialog body',
        'row title',
        'styled body',
      ])
        if (!_sameInk(_painted(tester, find.text(label)), ink))
          '$label ${_painted(tester, find.text(label))}',
      if (!_sameInk(
        _painted(tester, find.byKey(const ValueKey('plainIcon'))),
        ink,
      ))
        'plain icon',
      if (!_sameInk(
        _fieldInk(tester, find.byKey(const ValueKey('sheetField'))),
        ink,
      ))
        'field',
    ];
    expect(wrong, isEmpty, reason: 'dialog content not in menuTextColor $ink');
    expect(
      _painted(tester, find.text('dialog action')),
      _darkMenu.accentTextColor,
      reason: 'dialog buttons keep the accent text colour',
    );
  });

  testWidgets('知らせの文と閉じるボタンはメニューの文字色、操作ボタンは差し色の文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('notice body'),
                showCloseIcon: true,
                persist: false,
                action: SnackBarAction(label: 'undo', onPressed: () {}),
              ),
            ),
            child: const Text('notify'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('notify'));
    await tester.pumpAndSettle();
    final ink = _darkMenu.menuTextColor;
    expect(_painted(tester, find.text('notice body')), ink);
    expect(
      _painted(
        tester,
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byIcon(Icons.close),
        ),
      ),
      ink,
    );
    expect(_painted(tester, find.text('undo')), _darkMenu.accentTextColor);
  });

  testWidgets('画面の入力欄（メニューの色で塗る）の文字・ヒント・アイコンはメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      const Scaffold(
        body: Column(
          children: [
            TextField(
              key: ValueKey('pageField'),
              decoration: InputDecoration(
                hintText: 'page hint',
                prefixIcon: Icon(Icons.search, key: ValueKey('prefix')),
                suffixIcon: Icon(Icons.clear, key: ValueKey('suffix')),
              ),
            ),
            TextField(
              key: ValueKey('labelled'),
              decoration: InputDecoration(labelText: 'page label'),
            ),
          ],
        ),
      ),
    );
    final ink = _darkMenu.menuTextColor;
    final wrong = <String>[
      for (final (label, finder) in [
        ('hint', find.text('page hint')),
        ('label', find.text('page label')),
        ('prefix icon', find.byKey(const ValueKey('prefix'))),
        ('suffix icon', find.byKey(const ValueKey('suffix'))),
      ])
        if (!_sameInk(_painted(tester, finder), ink))
          '$label ${_painted(tester, finder)}',
    ];
    await tester.enterText(find.byKey(const ValueKey('pageField')), 'typed');
    await tester.pump();
    final typed = _fieldInk(tester, find.byKey(const ValueKey('pageField')));
    if (typed != ink) wrong.add('typed $typed');
    expect(wrong, isEmpty, reason: 'filled field not in menuTextColor $ink');
  });

  testWidgets('画面の色で塗った検索欄（ヘルプ・活用Tips）は本文の文字色のまま', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    for (final screen in const [HelpScreen(), TipsScreen()]) {
      await _pump(tester, themes, screen);
      final field = find.byType(TextField).first;
      final decoration = tester.widget<TextField>(field).decoration!;
      final hint = decoration.labelText ?? decoration.hintText!;
      final wrong = <String>[
        if (!_sameInk(_painted(tester, find.text(hint)), _darkMenu.textColor))
          'hint ${_painted(tester, find.text(hint))}',
        if (!_sameInk(
          _painted(
            tester,
            find.descendant(of: field, matching: find.byIcon(Icons.search)),
          ),
          _darkMenu.textColor,
        ))
          'search icon',
      ];
      await tester.enterText(field, 'abc');
      await tester.pump();
      if (decoration.labelText != null &&
          !_sameInk(_painted(tester, find.text(hint)), _darkMenu.textColor)) {
        wrong.add('floating label ${_painted(tester, find.text(hint))}');
      }
      if (_fieldInk(tester, field) != _darkMenu.textColor) {
        wrong.add('typed ${_fieldInk(tester, field)}');
      }
      expect(
        wrong,
        isEmpty,
        reason: '${screen.runtimeType}: panel-filled search field',
      );
    }
  });

  testWidgets('画面のドロップダウン・ポップアップメニューは今までどおり', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: Column(
          children: [
            DropdownButton<int>(
              value: 1,
              items: const [
                DropdownMenuItem(value: 1, child: Text('one')),
                DropdownMenuItem(value: 2, child: Text('two')),
              ],
              onChanged: (_) {},
            ),
            PopupMenuButton<int>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('menu item')),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    // 画面のドロップダウンは用紙の色の上に本文の文字色（シートと違い、
    // 画面の書式で並べるので、下地だけメニューの面にはしない）。
    expect(_painted(tester, find.text('two').last), _darkMenu.textColor);
    await tester.tapAt(const Offset(780, 1180));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(_painted(tester, find.text('menu item')), _darkMenu.menuTextColor);
  });

  testWidgets('組み込みのテーマは、ダイアログ・シート・入力欄の文字色が変わらない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    for (final preset in themes.presets) {
      expect(preset.textColor, preset.menuTextColor, reason: preset.name);
      themes.previewCurrent(preset);
      await _pump(
        tester,
        themes,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: _menuBody,
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(_painted(tester, find.text('row title')), preset.textColor);
      expect(
        _painted(tester, find.text('styled body')),
        themes.themeData.textTheme.bodySmall!.color,
      );
      expect(
        _painted(tester, find.byKey(const ValueKey('plainIcon'))),
        preset.textColor,
      );
      expect(
        _painted(tester, find.text('hint'))!.withAlpha(255),
        preset.textColor,
      );
      final input = tester.element(find.byType(TextField));
      final border = InputDecorationTheme.of(input).border!;
      final outline = WidgetStateProperty.resolveAs<InputBorder>(border, {});
      expect(outline.borderSide.width, 1, reason: preset.name);
      expect(outline.borderSide.color.a, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  test('画面の移り変わりはFlutterの既定のまま（予測型「戻る」を含む）', () async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    for (final preset in [AppThemePreset.defaultLight, _darkMenu]) {
      themes.previewCurrent(preset);
      final builders = themes.themeData.pageTransitionsTheme.builders;
      const defaults = PageTransitionsTheme();
      for (final platform in TargetPlatform.values) {
        final expected =
            defaults.builders[platform] ?? const ZoomPageTransitionsBuilder();
        // 一覧に無い端末はFlutterと同じくズーム。
        final actual = builders[platform] ?? const ZoomPageTransitionsBuilder();
        expect(
          actual.transitionDuration,
          expected.transitionDuration,
          reason: '$platform',
        );
        expect(
          actual.reverseTransitionDuration,
          expected.reverseTransitionDuration,
          reason: '$platform',
        );
        // 前の画面の動き（Androidの予測型「戻る」・ズーム）を渡すかどうか。
        // 関数は取り出すたびに作られるので、有る・無いを比べる。
        expect(
          actual.delegatedTransition != null,
          expected.delegatedTransition != null,
          reason: '$platform',
        );
      }
    }
    themes.dispose();
  });
}
