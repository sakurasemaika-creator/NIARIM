// メニューの背景色の上に描く部品（塗った入力欄の浮いた名前・ドロップダウンの
// 選んだ値・ポップアップメニューの項目のアイコン・上部バーのタブ）が、本文の
// 文字色ではなくメニューの文字色で描かれることの見張り。
//
// メニューを暗く・本文の文字を暗くした自作テーマ（customdark）では、本文の
// 文字色で描くと暗い下地に暗い字になり読めなかった（DISC194〜197）。
// 組み込みのテーマは本文とメニューの文字色が同じなので見た目は変わらない。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:niarim/widgets/menu_card.dart';
import 'package:niarim/widgets/menu_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<ThemeService> _themes(AppThemePreset preset) async {
  SharedPreferences.setMockInitialValues({});
  final service = ThemeService();
  await service.init();
  service.previewCurrent(preset);
  return service;
}

Future<void> _pump(
  WidgetTester tester,
  ThemeService themes,
  Widget home,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: themes.themeData,
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('塗った入力欄の浮いた名前はメニューの文字色（自分で書式を渡す欄はその書式）', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    final first = TextEditingController(text: 'typed');
    final second = TextEditingController(text: 'typed');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: Column(
          children: [
            TextField(
              controller: first,
              decoration: const InputDecoration(labelText: 'floating'),
            ),
            TextField(
              controller: second,
              decoration: const InputDecoration(
                labelText: 'own style',
                labelStyle: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
    expect(
      _painted(tester, find.text('floating')),
      isNotNull,
      reason: 'label is drawn',
    );
    expect(
      _sameInk(
        _painted(tester, find.text('floating')),
        _darkMenu.menuTextColor,
      ),
      isTrue,
      reason: 'floating label ${_painted(tester, find.text('floating'))}',
    );
    // 自分で名前の書式を渡す欄も、浮いた名前はメニューの文字色。
    expect(
      _sameInk(
        _painted(tester, find.text('own style')),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
  });

  test('lib配下の入力欄でlabelStyleを渡すときはfloatingLabelStyleも渡す', () {
    // テーマのfloatingLabelStyleは欄のlabelStyleより先に使われるので、
    // 欄ごとに名前の書式を変えるときは浮いた名前の書式も渡す。
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final m in RegExp(r'InputDecoration\(').allMatches(source)) {
        var depth = 0;
        var end = m.end - 1;
        for (; end < source.length; end++) {
          final c = source[end];
          if (c == '(') depth++;
          if (c == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final call = source.substring(m.start, end);
        if (RegExp(r'\blabelStyle:').hasMatch(call) &&
            !call.contains('floatingLabelStyle:')) {
          offenders.add(
            '${entity.path}:${'\n'.allMatches(source.substring(0, m.start)).length + 1}',
          );
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('画面のドロップダウンの欄の選んだ値と、開いた一覧はメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: MenuSurface(
          child: DropdownButtonFormField<int>(
            initialValue: 1,
            items: const [
              DropdownMenuItem(value: 1, child: Text('one')),
              DropdownMenuItem(value: 2, child: Text('two')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      _sameInk(_painted(tester, find.text('one')), _darkMenu.menuTextColor),
      isTrue,
    );
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    expect(
      _sameInk(
        _painted(tester, find.text('two').last),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
  });

  test('lib配下のDropdownButtonFormFieldはどれもMenuSurfaceで包む', () async {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('DropdownButtonFormField<')) continue;
        if (lines[i].trimLeft().startsWith('//')) continue;
        final from = i - 3 < 0 ? 0 : i - 3;
        final before = lines.sublist(from, i + 1).join('\n');
        // 塗らない欄（キャンバスの上に縁取りの字で書く）は印を付けて外す。
        if (!before.contains('MenuSurface(') &&
            !before.contains('menu-surface: n/a')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('lib配下の下地の色を決めないカードはMenuCard（中身をメニューの面のテーマで描く）', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('menu_card.dart') ||
          entity.path.endsWith('docked_panel_scope.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final m in RegExp(r'(?<![A-Za-z_])Card\(').allMatches(source)) {
        var depth = 0;
        var end = m.end - 1;
        var hasColor = false;
        for (; end < source.length; end++) {
          final c = source[end];
          if (c == '(' || c == '[' || c == '{') depth++;
          if (c == ')' || c == ']' || c == '}') {
            depth--;
            if (depth == 0) break;
          }
          if (depth == 1 &&
              RegExp(r'^[,(\s]+color:').hasMatch(
                source.substring(
                  end,
                  end + 40 > source.length ? source.length : end + 40,
                ),
              )) {
            hasColor = true;
          }
        }
        // 絵（用紙の色）の上に印を描くカード（ホームの作品・フォルダ）は
        // 印を付けて外す。名前はカードが自分でメニューの文字色を読む。
        final before = source.substring(
          m.start - 200 < 0 ? 0 : m.start - 200,
          m.start,
        );
        if (!hasColor && !before.contains('menu-surface: n/a')) {
          offenders.add(
            '${entity.path}:${'\n'.allMatches(source.substring(0, m.start)).length + 1}',
          );
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('MenuCardの中の文・アイコンはメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      const Scaffold(
        body: MenuCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('card body'),
              Icon(Icons.info_outline, key: ValueKey('cardIcon')),
            ],
          ),
        ),
      ),
    );
    expect(
      _sameInk(
        _painted(tester, find.text('card body')),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
    expect(
      _sameInk(
        _painted(tester, find.byKey(const ValueKey('cardIcon'))),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
  });

  testWidgets('ポップアップメニューの項目の中のアイコンはメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      Scaffold(
        body: PopupMenuButton<int>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(
                    Icons.audiotrack,
                    key: const ValueKey('itemIcon'),
                    color: PopupMenuTheme.of(context).iconColor,
                  ),
                  const Text('menu item'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(
      _sameInk(
        _painted(tester, find.byKey(const ValueKey('itemIcon'))),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
  });

  test('lib配下のポップアップメニューの項目の中のアイコンは色を渡す', () {
    // PopupMenuItemの子に直に置いたIconは画面の本文の色を受け継ぐ。
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'PopupMenuItem(<[^>]*>)?\(').hasMatch(lines[i])) continue;
        // 項目の終わり（字下げが項目の行と同じ閉じ括弧）までを見る。
        final indent = lines[i].length - lines[i].trimLeft().length;
        for (var j = i + 1; j < lines.length; j++) {
          final line = lines[j];
          final lineIndent = line.length - line.trimLeft().length;
          if (lineIndent <= indent && line.trim().startsWith(')')) break;
          final m = RegExp(r'\bIcon\(').firstMatch(line);
          if (m == null) continue;
          // ListTileの先頭・末尾のアイコンは一覧の行の色（テーマ）で描く。
          if (line.contains('leading:') || line.contains('trailing:')) {
            continue;
          }
          // 色を渡しているか（同じ呼び出しの5行以内）。
          final window = lines
              .sublist(j, j + 6 > lines.length ? lines.length : j + 6)
              .join('\n');
          final close = window.indexOf(')');
          final call = close < 0 ? window : window.substring(0, close + 1);
          if (!call.contains('color:') && !window.contains('color:')) {
            offenders.add('${entity.path}:${j + 1}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('上部バーのタブの選んでいない名前はメニューの文字色から作る', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('title'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'selected'),
                Tab(text: 'other'),
              ],
            ),
          ),
        ),
      ),
    );
    final other = _painted(tester, find.text('other'));
    expect(_sameInk(other, _darkMenu.menuTextColor), isTrue, reason: '$other');
    final menu = _darkMenu.menuBgColor;
    expect(
      isEssentialTextNearlyInvisible(opaqueOver(other!, menu), menu),
      isFalse,
    );
  });

  testWidgets('ドックの中（用紙の色の面）のタブの選んでいない名前は本文の文字色から作る', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      DockedPanelScope(
        child: Scaffold(
          body: PanelSurface(
            width: 280,
            height: 300,
            child: DefaultTabController(
              length: 2,
              child: const TabBar(
                tabs: [
                  Tab(text: 'selected'),
                  Tab(text: 'other'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final other = _painted(tester, find.text('other'));
    expect(_sameInk(other, _darkMenu.textColor), isTrue, reason: '$other');
  });

  testWidgets('浮かぶパネル（メニューの色のカード）の中の文はメニューの文字色', (tester) async {
    final themes = await _themes(_darkMenu);
    addTearDown(themes.dispose);
    await _pump(
      tester,
      themes,
      const Scaffold(
        body: PanelSurface(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('panel body'),
              Icon(Icons.info_outline, key: ValueKey('panelIcon')),
            ],
          ),
        ),
      ),
    );
    expect(
      _sameInk(
        _painted(tester, find.text('panel body')),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
    expect(
      _sameInk(
        _painted(tester, find.byKey(const ValueKey('panelIcon'))),
        _darkMenu.menuTextColor,
      ),
      isTrue,
    );
  });
}
