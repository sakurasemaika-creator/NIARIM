// キャンバスのペンのパネル（ブラシ・トーン・スタンプのタブ）、ブラシ・トーン・
// スタンプのパネルの「フォルダ・新規・読込」の行、設定のフォント管理の画面が、
// 狭い幅・大きな文字で名前を切らず、はみ出さないことを見張る（DISC133）。
//
// 以前は、PCのドック200px・スマホ360pxでタブの名前が切れ（英「Screen…」、
// 仏・文字2倍「Pin/Tra/Tam」）、「フォルダ・新規・読込」は横にスクロールする
// 行のままパネルの端で切れていた。フォント管理の画面もタブが「Téléc / Reche /
// Impor」と切れ、仏語360px×文字2倍では「Sélectionner un fichier」の文字が
// ボタンからはみ出し、空の表示の段落が画面の左端に接していた。
// 所有者の判断3：文字は縮めない。入らない幅ではアイコンだけにし、名前は長押し・
// ホバーの吹き出しと読み上げで伝える（測った幅で決める）。判断4：入らない画面名は
// 出さない（省略記号で切らない）。
//
// 中国語の本文の書体を字の広いNoto Serif SCにした（DISC132）後、フォント管理の
// 検索欄のヒント（「以字型名稱搜尋...」「按字体名称搜索...（共2021种字体）」）が
// 文字1.0でも「…」で切れ、「探してDL」の分類のチップが文字2倍で36pxの行より
// 高くなって上下が切れていた。表示言語のテーマで描いて見る。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/screens/settings/font_settings_screen.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';
import 'helpers/text_fit_problems.dart';

typedef _Layout = (String, double, Widget Function());

final List<_Layout> _panels = [
  for (final width in const [320.0, 360.0]) ...[
    (
      'phone${width.round()}-pen',
      width,
      () => PenSubToolPanel(
        currentTool: DrawingTool.pen,
        currentSubTool: PenSubTool.brush,
        onSubToolSelected: (_) {},
        onClose: () {},
      ),
    ),
    ('phone${width.round()}-tone', width, () => TonePanel(onClose: () {})),
  ],
  // ドックを窓の幅に合わせて縮めたとき（アイコンも1行に入らない幅）。
  (
    'dock120-brush',
    120.0,
    () => DockedPanelScope(child: BrushPanel(dockedMode: true, onClose: () {})),
  ),
  for (final width in const [200.0, 280.0]) ...[
    (
      'dock${width.round()}-pen',
      width,
      () => DockedPanelScope(
        child: PenSubToolPanel(
          currentTool: DrawingTool.pen,
          currentSubTool: PenSubTool.brush,
          onSubToolSelected: (_) {},
          onClose: () {},
        ),
      ),
    ),
    (
      'dock${width.round()}-brush',
      width,
      () =>
          DockedPanelScope(child: BrushPanel(dockedMode: true, onClose: () {})),
    ),
    (
      'dock${width.round()}-stamp',
      width,
      () => DockedPanelScope(child: StampPanel(onClose: () {})),
    ),
  ],
];

/// [finder]の部品の名前が、画面の文か吹き出し（長押し・ホバー）と読み上げで
/// 伝わるか。
bool _named(WidgetTester tester, Finder control, String name) {
  bool any(Finder f) => f.evaluate().isNotEmpty;
  final inside = find.descendant(of: control, matching: find.text(name));
  final tooltip = find.ancestor(
    of: control,
    matching: find.byWidgetPredicate((w) => w is Tooltip && w.message == name),
  );
  final innerTooltip = find.descendant(
    of: control,
    matching: find.byWidgetPredicate((w) => w is Tooltip && w.message == name),
  );
  final button = tester.widgetList(control).first;
  return any(inside) ||
      any(tooltip) ||
      any(innerTooltip) ||
      (button is IconButton && button.tooltip == name);
}

Future<List<SingleChildWidget>> _providers(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  return (await tester.runAsync(buildAppProviders))!;
}

Widget _host(
  List<SingleChildWidget> providers,
  Locale locale,
  double scale,
  Widget home,
) => MultiProvider(
  providers: providers,
  child: Builder(
    builder: (context) => MaterialApp(
      // 本物のアプリと同じ、表示言語のテーマ（中国語は本文の書体が違う）。
      theme: context.watch<ThemeService>().themeDataFor(locale),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×スマホ320/360・ドック120/200/280×文字1.0/2.0で、ペンのパネルの'
      'タブと「フォルダ・新規・読込」が切れず（入らなければアイコンだけ）、'
      'どれも名前が伝わる', (tester) async {
    await loadAppFonts(tester);
    final providers = await _providers(tester);
    final problems = <String>[];
    var iconTabs = 0;
    var labelTabs = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final (name, width, build) in _panels) {
        for (final scale in const [1.0, 2.0]) {
          final where = '${locale.toLanguageTag()} $name ×$scale';
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (d) =>
              errors.add(d.exceptionAsString().split('\n').first);
          await tester.pumpWidget(
            _host(
              providers,
              locale,
              scale,
              Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: const Key('panelArea'),
                    width: width,
                    height: 860,
                    child: build(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          FlutterError.onError = previous;
          for (final e in errors.toSet()) {
            problems.add('$where: $e');
          }
          final area = tester.getRect(find.byKey(const Key('panelArea')));
          // ペンのパネルのタブ。
          final tabBar = find.byType(TabBar);
          if (name.endsWith('-pen')) {
            final tabs = find.descendant(
              of: tabBar,
              matching: find.byType(Tab),
            );
            final names = [
              l.penSubToolTabBrush,
              l.penSubToolTabTone,
              l.penSubToolTabStamp,
            ];
            for (var i = 0; i < 3; i++) {
              final tab = tabs.at(i);
              if (!_named(tester, tab, names[i])) {
                problems.add('$where: タブ「${names[i]}」の名前が伝わらない');
              }
              final label = find.descendant(
                of: tab,
                matching: find.text(names[i]),
              );
              if (label.evaluate().isEmpty) {
                iconTabs++;
              } else {
                labelTabs++;
              }
            }
            for (final p in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: tabBar, matching: find.byType(RichText)),
            )) {
              for (final problem in textFitProblems(p)) {
                problems.add('$where: タブ«${p.text.toPlainText()}» $problem');
              }
            }
          }
          // 「フォルダ・新規・読込」（ペンのパネルは最初のタブのブラシの中）。
          for (final (icon, label) in [
            (Icons.folder_outlined, l.creativePanelFolderButton),
            (Icons.add_photo_alternate_outlined, l.creativePanelCreateButton),
            (Icons.file_upload_outlined, l.creativePanelImportButton),
          ]) {
            final iconFinder = find.byIcon(icon);
            if (iconFinder.evaluate().isEmpty) {
              problems.add('$where: 「$label」が無い');
              continue;
            }
            final button = find.ancestor(
              of: iconFinder.first,
              matching: find.byWidgetPredicate(
                (w) => w is ButtonStyleButton || w is IconButton,
              ),
            );
            final rect = tester.getRect(button.first);
            if (rect.left < area.left - 0.5 || rect.right > area.right + 0.5) {
              problems.add(
                '$where: 「$label」がパネルの外（${rect.left.round()}〜'
                '${rect.right.round()} / 幅${area.width.round()}）',
              );
            }
            if (!_named(tester, button.first, label)) {
              problems.add('$where: 「$label」の名前が伝わらない');
            }
            for (final p in tester.renderObjectList<RenderParagraph>(
              find.descendant(
                of: button.first,
                matching: find.byType(RichText),
              ),
            )) {
              for (final problem in textFitProblems(p)) {
                problems.add('$where: «${p.text.toPlainText()}» $problem');
              }
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    expect(
      problems.toSet().toList(),
      isEmpty,
      reason: problems.toSet().join('\n'),
    );
    expect(iconTabs, greaterThan(0), reason: 'アイコンだけのタブを通っていない');
    expect(labelTabs, greaterThan(0), reason: '名前のタブを通っていない');
  });

  testWidgets('7言語×320/360px×文字1.0/2.0で、フォント管理の画面の画面名・タブ・'
      '空の表示・検索欄のヒント・分類のチップ・「ファイルを選ぶ」が切れず、'
      'はみ出さず、端に接しない', (tester) async {
    await loadAppFonts(tester);
    final providers = await _providers(tester);
    const seedLocale = Locale('en');
    await tester.pumpWidget(
      _host(providers, seedLocale, 1, const FontSettingsScreen()),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(lookupAppLocalizations(seedLocale).fontEmptyTitle),
      findsOneWidget,
    );
    expect(find.byType(FilterChip), findsNothing);
    final fonts = tester
        .element(find.byType(FontSettingsScreen))
        .read<FontService>();
    final sample = await tester.runAsync(
      () => fonts.addFont('assets/fonts/HakkouMincho.ttf', 'Sample'),
    );
    expect(sample, isNotNull);
    await tester.pumpWidget(const SizedBox());
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 2.0]) {
          final where = '${locale.toLanguageTag()} ${width.round()}px ×$scale';
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1;
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (d) =>
              errors.add(d.exceptionAsString().split('\n').first);
          await tester.pumpWidget(
            _host(providers, locale, scale, const FontSettingsScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          final tabNames = [
            l.fontSettingsTabDownloaded,
            l.fontSettingsTabSearch,
            l.fontSettingsTabImport,
          ];
          for (final tabIndex in const [0, 1, 2]) {
            final tabs = find.descendant(
              of: find.byType(TabBar),
              matching: find.byType(Tab),
            );
            await tester.tap(tabs.at(tabIndex));
            await tester.pumpAndSettle();
            for (var i = 0; i < 3; i++) {
              if (!_named(tester, tabs.at(i), tabNames[i])) {
                problems.add('$where: タブ「${tabNames[i]}」の名前が伝わらない');
              }
            }
            // 横にスクロールする分類のチップの行（端で切れて見えるのは
            // スクロールの途中）。
            final inRow = tester
                .renderObjectList<RenderParagraph>(
                  find.descendant(
                    of: find.byWidgetPredicate(
                      (w) =>
                          w is Scrollable &&
                          axisDirectionToAxis(w.axisDirection) ==
                              Axis.horizontal,
                    ),
                    matching: find.byType(RichText),
                  ),
                )
                .toSet();
            for (final p
                in tester
                    .renderObjectList<RenderParagraph>(find.byType(RichText))
                    .where((p) => p.attached && p.hasSize)) {
              for (final problem in textFitProblems(p)) {
                problems.add(
                  '$where tab$tabIndex: «${p.text.toPlainText()}» $problem',
                );
              }
              if (inRow.contains(p)) continue;
              // 本文（空の表示・説明）は画面の端に接しない。
              final box = MatrixUtils.transformRect(
                p.getTransformTo(null),
                Offset.zero & p.size,
              );
              if (box.left < 12 || box.right > width - 12) {
                problems.add(
                  '$where tab$tabIndex: «${p.text.toPlainText()}» が画面の端に'
                  '接する（${box.left.round()}〜${box.right.round()}）',
                );
              }
            }
            if (tabIndex == 0) {
              // 「お気に入りのみ」は、星だけの形でも名前が伝わる。
              final favorites = find.byType(FilterChip);
              if (favorites.evaluate().isEmpty ||
                  !_named(tester, favorites, l.homeFavoritesOnly)) {
                problems.add('$where: 「${l.homeFavoritesOnly}」の名前が伝わらない');
              }
            }
            if (tabIndex == 1) {
              // 分類のチップの文はチップの中に収まる（行の高さで上下を
              // 切らない）。
              for (final chip in find.byType(ChoiceChip).evaluate()) {
                final outer = tester.getRect(find.byWidget(chip.widget));
                final label = find.descendant(
                  of: find.byWidget(chip.widget),
                  matching: find.byType(RichText),
                );
                if (label.evaluate().isEmpty) continue;
                final text = tester.getRect(label.first);
                final row = tester.getRect(
                  find
                      .ancestor(
                        of: find.byWidget(chip.widget),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                if (text.top < outer.top - 0.5 ||
                    text.bottom > outer.bottom + 0.5 ||
                    outer.top < row.top - 0.5 ||
                    outer.bottom > row.bottom + 0.5) {
                  problems.add(
                    '$where: 分類のチップ「${tester.widget<RichText>(label.first).text.toPlainText()}」'
                    'が切れる（文${text.top.round()}〜${text.bottom.round()}・'
                    'チップ${outer.top.round()}〜${outer.bottom.round()}・'
                    '行${row.top.round()}〜${row.bottom.round()}）',
                  );
                }
              }
            }
            if (tabIndex == 2) {
              final button = find.ancestor(
                of: find.text(l.fontSelectFileButton),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              );
              if (button.evaluate().isEmpty) {
                problems.add('$where: 「${l.fontSelectFileButton}」のボタンが無い');
              } else {
                final outer = tester.getRect(button.first);
                final label = tester.getRect(find.text(l.fontSelectFileButton));
                if (label.top < outer.top + 4 ||
                    label.bottom > outer.bottom - 4) {
                  problems.add(
                    '$where: 「${l.fontSelectFileButton}」の文字がボタンの縁に'
                    '届く（文字${label.top.round()}〜${label.bottom.round()}・'
                    'ボタン${outer.top.round()}〜${outer.bottom.round()}）',
                  );
                }
              }
            }
          }
          FlutterError.onError = previous;
          for (final e in errors.toSet()) {
            problems.add('$where: $e');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    expect(
      problems.toSet().toList(),
      isEmpty,
      reason: problems.toSet().join('\n'),
    );
  });
}
