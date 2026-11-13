// ブラシ・トーン・スタンプの一覧の見出しの行（一覧の名前・「お気に入りのみ」・
// 検索）が、どの言語・幅・文字の大きさでも幅からはみ出さないことを見張る
// （DISC112）。
//
// 以前は日本語以外で「お気に入りのみ」のチップが長くなり、行が幅を越えて
// （英語で120px）、スマホでは検索のボタンがパネルの外へ押し出されていた。
// 所有者の判断3：文字は縮めない。入らない幅では星のアイコンだけにし、名前は
// 長押し（タッチ）・ホバー（マウス）の吹き出しと読み上げで伝える。どちらに
// するかは端末の種類ではなく、測った幅で決める。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 見る置き方：（名前, 画面の幅, パネルを作る関数）。
typedef _Layout = (String, double, Widget Function());

final List<_Layout> _layouts = [
  // スマホ：浮かぶパネル（幅280）とペンのサブツールの中（タブの中）。
  ('phone360-brush', 360, () => BrushPanel(onClose: () {})),
  ('phone360-tone', 360, () => TonePanel(onClose: () {})),
  ('phone360-stamp', 360, () => StampPanel(onClose: () {})),
  (
    'phone360-pen-sub-tool',
    360,
    () => PenSubToolPanel(
      currentTool: DrawingTool.pen,
      currentSubTool: PenSubTool.brush,
      onSubToolSelected: (_) {},
      onClose: () {},
    ),
  ),
  // PC/DeX：ドックの窓の幅（下限200・既定280・広い460）。
  for (final width in const [200.0, 280.0, 460.0]) ...[
    (
      'dock${width.round()}-brush',
      width,
      () =>
          DockedPanelScope(child: BrushPanel(dockedMode: true, onClose: () {})),
    ),
    (
      'dock${width.round()}-tone',
      width,
      () => DockedPanelScope(child: TonePanel(onClose: () {})),
    ),
    (
      'dock${width.round()}-stamp',
      width,
      () => DockedPanelScope(child: StampPanel(onClose: () {})),
    ),
  ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('7言語×スマホ360・ドック200/280/460×文字1.0/2.0で、見出しの行が'
      'はみ出さず、検索とお気に入りの切り替えがパネルの中にある（文字は縮めない）', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    var iconOnly = 0;
    var labelled = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final (name, width, build) in _layouts) {
        for (final scale in const [1.0, 2.0]) {
          final where = '${locale.toLanguageTag()} $name ×$scale';
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          final providers = (await tester.runAsync(buildAppProviders))!;
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: Builder(
                builder: (themeContext) => MaterialApp(
                  theme: themeContext.watch<ThemeService>().themeData,
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        height: 860,
                        child: build(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          final error = tester.takeException();
          if (error != null) {
            problems.add('$where: $error');
            continue;
          }
          // お気に入りの切り替えは1つだけ見えている。
          final chip = find.byKey(const ValueKey('asset-favorites-only'));
          if (chip.evaluate().length != 1) {
            problems.add('$where: お気に入りの切り替えが${chip.evaluate().length}個');
            continue;
          }
          final panelRight = width;
          final chipRect = tester.getRect(chip);
          final search = find.byTooltip(l10n.creativePanelSearchTooltip);
          if (search.evaluate().isEmpty) {
            problems.add('$where: 検索のボタンが無い');
            continue;
          }
          final searchRect = tester.getRect(search.first);
          if (searchRect.right > panelRight + 0.5 ||
              chipRect.right > panelRight + 0.5) {
            problems.add(
              '$where: 検索 ${searchRect.right} / お気に入り '
              '${chipRect.right} がパネルの右端 $panelRight の外',
            );
          }
          final label = find.descendant(
            of: chip,
            matching: find.text(l10n.customAutomationFavoritesOnly),
          );
          if (label.evaluate().isNotEmpty) {
            labelled++;
            // 文字は縮めない：画面の文字の倍率のまま描く。
            final paragraph = tester.renderObject<RenderParagraph>(label);
            if (paragraph.textScaler != TextScaler.linear(scale)) {
              problems.add('$where: 名前の文字の倍率が ${paragraph.textScaler}');
            }
            if (tester.getRect(label).right > chipRect.right + 0.5) {
              problems.add('$where: 名前がチップの外へはみ出す');
            }
          } else {
            iconOnly++;
            // 星だけのとき：名前は吹き出し（長押し・ホバー）と読み上げで。
            final filter = tester.widget<FilterChip>(chip);
            if (filter.tooltip != l10n.customAutomationFavoritesOnly) {
              problems.add('$where: 星だけのときの吹き出しが「${filter.tooltip}」');
            }
            final semantics = tester.getSemantics(chip);
            final announced =
                '${semantics.label} ${semantics.tooltip} '
                '${semantics.value}';
            if (!announced.contains(l10n.customAutomationFavoritesOnly)) {
              problems.add('$where: 読み上げに名前が無い（$announced）');
            }
          }
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 広い所では名前が出て、狭い所では星だけになる（両方の場合を通っている）。
    expect(labelled, greaterThan(0));
    expect(iconOnly, greaterThan(0));
  });

  testWidgets('星だけのときも押せば「お気に入りのみ」に切り替わる', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DockedPanelScope(
                child: BrushPanel(dockedMode: true, onClose: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final chip = find.byKey(const ValueKey('asset-favorites-only'));
    expect(chip, findsOneWidget);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    await tester.tap(chip);
    await tester.pump();
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
  });

  /// ドックの窓の幅を変えられるペンのサブツールのパネル（仏語・文字2倍）。
  Future<ValueNotifier<double>> pumpResizableDock(WidgetTester tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(460, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final width = ValueNotifier<double>(460);
    addTearDown(width.dispose);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ValueListenableBuilder<double>(
                  valueListenable: width,
                  builder: (_, w, child) =>
                      SizedBox(width: w, height: 860, child: child),
                  child: DockedPanelScope(
                    child: PenSubToolPanel(
                      currentTool: DrawingTool.pen,
                      currentSubTool: PenSubTool.brush,
                      onSubToolSelected: (_) {},
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return width;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final chip = find.byKey(const ValueKey('asset-favorites-only'));
  final label = find.descendant(
    of: chip,
    matching: find.text(
      lookupAppLocalizations(const Locale('fr')).customAutomationFavoritesOnly,
    ),
  );

  bool chipFocused() {
    var hit = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
      hit = e.widget.key == const ValueKey('asset-favorites-only');
      return !hit;
    });
    return hit;
  }

  testWidgets('ドックの窓を狭めて星を押し、広げてから名前つきのチップを押しても'
      '（何度でも）、並べ方の例外も壊れた部品も出ない', (tester) async {
    final width = await pumpResizableDock(tester);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) =>
        errors.add(details.exceptionAsString().split('\n').first);
    final selections = <bool>[];
    try {
      for (var round = 0; round < 2; round++) {
        width.value = 200; // ドックの下限：星だけ
        await settle(tester);
        expect(label, findsNothing);
        await tester.tap(chip);
        await settle(tester);
        selections.add(tester.widget<FilterChip>(chip).selected);
        width.value = 460; // 名前つき
        await settle(tester);
        expect(label, findsOneWidget);
        await tester.tap(chip);
        await settle(tester);
        selections.add(tester.widget<FilterChip>(chip).selected);
      }
    } finally {
      FlutterError.onError = previous;
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(selections, [true, false, true, false]);
  });

  testWidgets('星にキーボードのフォーカスがあるまま窓を広げても、フォーカスは'
      'お気に入りの切り替えに残り、Space で切り替わる（読み込みは動かない）', (tester) async {
    final width = await pumpResizableDock(tester);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) =>
        errors.add(details.exceptionAsString().split('\n').first);
    try {
      width.value = 200;
      await settle(tester);
      expect(label, findsNothing);
      for (var i = 0; i < 40 && !chipFocused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(chipFocused(), isTrue, reason: '星にフォーカスが来ない');
      width.value = 460;
      await settle(tester);
      expect(label, findsOneWidget);
      expect(
        chipFocused(),
        isTrue,
        reason: '${FocusManager.instance.primaryFocus}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(tester.widget<FilterChip>(chip).selected, isTrue);
      // 狭めても同じ（名前つき→星）。
      width.value = 200;
      await settle(tester);
      expect(label, findsNothing);
      expect(
        chipFocused(),
        isTrue,
        reason: '${FocusManager.instance.primaryFocus}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(tester.widget<FilterChip>(chip).selected, isFalse);
    } finally {
      FlutterError.onError = previous;
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
