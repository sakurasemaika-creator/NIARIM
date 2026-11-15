// キャンバスの早替えツールの一覧の名前を、保存した名前ではなくツールの種類から
// 表示のたびに今の言語で作る（DISC229）。
//
// 一覧は保存した名前（`QuickToolEntry.label`）をそのまま出していたので、最初
// からある早替えツールはどの言語でも日本語（「消しゴム」「スポイト」
// 「Gペン 細」）、足したツールは足したときの言語のまま（簡体字で足した
// 「橡皮擦」が繁体字・英語の画面にも残る）だった。
//
// 消しゴム・スポイト・バケツは今の言語のツール名、ブラシのツールは今の
// ブラシの名前（利用者のデータなので訳さない。名前を変えれば新しい名前）と
// 太さ。ブラシが無くなっていれば保存した名前。保存の形（名前も）と引き継ぎ
// （.niatra）は変えない。7言語を切り替えて、一覧の名前・保存が変わらないことを
// 見る。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

const _zh = Locale('zh');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('quick tool names follow the language on screen', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    final quickTools = QuickToolService();
    await tester.runAsync(quickTools.init);
    // 利用者のブラシ（名前を後で変える）と、後で消すブラシ。
    final base = brushes.brushes.firstWhere((b) => b.id == 'Brush0002');
    brushes
      ..addBrush(base.copyWith(id: 'user_pen', name: 'My liner'))
      ..addBrush(base.copyWith(id: 'user_gone', name: 'Old brush'));
    // 簡体字の画面で足したツール（足したときの言語の名前で保存される）。
    final zh = lookupAppLocalizations(_zh);
    for (final entry in [
      QuickToolEntry(
        id: 'qt_zh_1',
        label: zh.quickToolEraser,
        toolKey: 'eraser',
      ),
      QuickToolEntry(
        id: 'qt_zh_2',
        label: zh.quickToolEyedropper,
        toolKey: 'eyedropper',
      ),
      QuickToolEntry(
        id: 'qt_zh_3',
        label: zh.quickToolBucket,
        toolKey: 'bucket',
      ),
      const QuickToolEntry(
        id: 'qt_zh_4',
        label: 'My liner 12px',
        toolKey: 'pen',
        brushId: 'user_pen',
        sizeOverride: 12,
      ),
      const QuickToolEntry(
        id: 'qt_zh_5',
        label: 'Old brush 5px',
        toolKey: 'pen',
        brushId: 'user_gone',
        sizeOverride: 5,
      ),
    ]) {
      quickTools.addEntry(entry);
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    brushes
      ..updateBrush(
        brushes.brushes
            .firstWhere((b) => b.id == 'user_pen')
            .copyWith(name: 'Inking pen'),
      )
      ..deleteBrush('user_gone');
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final savedBefore = prefs!.getStringList('quick_tool_entries');
    final labelsBefore = [for (final e in quickTools.entries) e.label];

    final language = ValueNotifier(_zh);
    addTearDown(language.dispose);
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<QuickToolService>.value(value: quickTools),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: RepaintBoundary(
          key: rootKey,
          child: ValueListenableBuilder<Locale>(
            valueListenable: language,
            builder: (context, locale, _) => MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    height: 860,
                    child: QuickToolPanel(
                      onClose: () {},
                      currentTool: DrawingTool.pen,
                      currentSize: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gPen = base.name;
    final airbrush = brushes.brushes
        .firstWhere((b) => b.id == 'Brush0003')
        .name;
    final problems = <String>[];
    final tooWide = <String>{};
    // パネルの見出しは、パネルの幅で折り返す（DISC233。以前は西語の見出しが
    // 行からはみ出したので、そのはみ出しだけは数えずに名前を出していた）。
    final errors = <String>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = onError);
    for (final locale in AppLocalizations.supportedLocales) {
      language.value = locale;
      await tester.pumpAndSettle();
      for (final error in errors) {
        problems.add('${locale.toLanguageTag()}: $error');
      }
      errors.clear();
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      // 一覧は見えている行だけを作るので、動かしながら行ごとの名前を集める。
      final names = <String, String?>{};
      final list = find
          .descendant(
            of: find.byType(QuickToolPanel),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(0);
      await tester.pump();
      while (true) {
        // 名前は、行の中の番号でない文（名前が番号と操作の間に入らない行は、
        // 番号と操作の行の下に名前を置く。DISC234）。
        for (final tile
            in find
                .descendant(
                  of: find.byType(QuickToolPanel),
                  matching: find.byType(ListTile),
                )
                .evaluate()) {
          final texts = tester
              .widgetList<Widget>(
                find.descendant(
                  of: find.byElementPredicate((e) => e == tile),
                  // KeepTogetherText（Textの子の型）も名前。
                  matching: find.byWidgetPredicate((w) => w is Text),
                ),
              )
              .map((t) => (t as Text).data)
              .where((d) => d != null && int.tryParse(d) == null);
          names[((tile.widget as ListTile).key! as ValueKey<String>).value] =
              texts.length == 1 ? texts.single : null;
        }
        // 行の名前の欄より広い1語（どう並べても途中で折れる語。DISC155と
        // 同じ種類）は、数えずに名前を出す。
        for (final paragraph in textParagraphsIn(
          find.descendant(
            of: find.byType(QuickToolPanel),
            matching: find.byType(ListTile),
          ),
        )) {
          for (final wide in wordsWiderThanLine(paragraph)) {
            tooWide.add('${locale.toLanguageTag()}: $wide');
          }
        }
        if (position.pixels >= position.maxScrollExtent) break;
        position.jumpTo(
          (position.pixels + position.viewportDimension * 0.6).clamp(
            0,
            position.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      position.jumpTo(0);
      await tester.pump();
      final shown = [for (final e in quickTools.entries) names[e.id]];
      final expected = [
        // 最初からある5つ（ブラシの名前は組み込みの名前のまま。DISC107）。
        '$gPen 3px',
        '$gPen 8px',
        airbrush,
        l10n.quickToolEraser,
        l10n.quickToolEyedropper,
        // 簡体字の画面で足した5つ。
        l10n.quickToolEraser,
        l10n.quickToolEyedropper,
        l10n.quickToolBucket,
        // 名前を変えたブラシは今の名前、消したブラシは保存した名前。
        'Inking pen 12px',
        'Old brush 5px',
      ];
      if (shown.join(' | ') != expected.join(' | ')) {
        problems.add('$tag: shows $shown, expected $expected');
      }
      if (shots != null && {'ja', 'en', 'zh'}.contains(tag)) {
        await tester.runAsync(() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$shots/DISC229-$tag.png',
          ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }
    }
    // 保存の形・中身（名前も）は変えない（前の版・引き継ぎで読める）。
    final savedAfter = (await tester.runAsync(
      SharedPreferences.getInstance,
    ))!.getStringList('quick_tool_entries');
    if (jsonEncode(savedAfter) != jsonEncode(savedBefore)) {
      problems.add('the saved quick tools changed: $savedAfter');
    }
    if ([for (final e in quickTools.entries) e.label].join('|') !=
        labelsBefore.join('|')) {
      problems.add('the stored names changed');
    }
    FlutterError.onError = onError;
    for (final word in tooWide) {
      debugPrint('wider than the name column (DISC155): $word');
    }
    for (final problem in problems) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
  });
}
