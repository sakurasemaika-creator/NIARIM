// キャンバスの早替えツールのパネルの並べ方。
//
// - 題の行（DISC233）：題を`Text`＋`Spacer`の行に置いていたので、題は行の
//   幅で折り返さず、パネルの幅（スマホ260px、中身236px）に入らない題
//   （西語「Ajustes de herramientas rápidas」258px）が行からはみ出していた。
//   7言語×文字1.0/1.3/2.0×スマホの浮かぶパネル・PCのドック（200/280px）で、
//   題が行からはみ出さず、題の中の行に入る語を途中で折らないことを見る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/docked_panel_close_scope.dart';
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

/// パネルを置く所（null：スマホの浮かぶパネル、数：PCのドックの幅）。
const _hosts = <double?>[null, 200, 280];

const _scales = [1.0, 1.3, 2.0];

String _plain(String text) => text
    .replaceAll('⁠', '')
    .replaceAll('​', '')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  /// [locale]の画面でパネルを置く。[dock]が数ならPCのドックのその幅の
  /// ペイン、nullならスマホの浮かぶパネル。
  Future<({GlobalKey root, QuickToolService quickTools, BrushService brushes})>
  pumpPanel(
    WidgetTester tester, {
    required Locale locale,
    double? dock,
    List<String> errors = const [],
  }) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    SharedPreferences.setMockInitialValues({});
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    final quickTools = QuickToolService();
    await tester.runAsync(quickTools.init);
    final root = GlobalKey();
    final panel = QuickToolPanel(
      onClose: () {},
      currentTool: DrawingTool.pen,
      currentSize: 4,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<QuickToolService>.value(value: quickTools),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: RepaintBoundary(
          key: root,
          child: MaterialApp(
            locale: locale,
            theme: ThemeService().themeDataFor(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: dock == null
                    ? panel
                    : SizedBox(
                        width: dock,
                        height: 520,
                        child: DockedPanelScope(
                          child: DockedPanelCloseScope(child: panel),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (root: root, quickTools: quickTools, brushes: brushes);
  }

  Future<void> shoot(WidgetTester tester, GlobalKey root, String name) async {
    if (shots == null) return;
    await tester.runAsync(() async {
      final boundary =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$shots/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
      image.dispose();
    });
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('quick tool panel title fits its row ($tag)', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      final problems = <String>[];
      final tooWide = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final dock in _hosts) {
          final host = dock == null ? 'phone' : 'dock${dock.toInt()}';
          final pumped = await pumpPanel(tester, locale: locale, dock: dock);
          for (final scale in _scales) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            final at = '$host x$scale';
            final panelRect = tester.getRect(find.byType(QuickToolPanel));
            final titles = textParagraphsIn(find.byType(QuickToolPanel))
                .where(
                  (p) =>
                      _plain(
                        p.text.toPlainText(includeSemanticsLabels: false),
                      ).trim() ==
                      l10n.quickToolPanelTitle,
                )
                .toList();
            if (titles.length != 1) {
              problems.add('$at: ${titles.length} titles');
              continue;
            }
            final title = titles.single;
            final broken = brokenWordUnits(title);
            for (final word in broken.fits) {
              problems.add('$at title breaks a word: $word');
            }
            tooWide.addAll([for (final w in broken.tooWide) '$at $w']);
            for (final char in ParagraphLines(title).charsOutsideWidth()) {
              problems.add('$at title runs past its line: $char');
            }
            final rect = MatrixUtils.transformRect(
              title.getTransformTo(null),
              Offset.zero & title.size,
            );
            if (rect.left < panelRect.left - 0.5 ||
                rect.right > panelRect.right + 0.5) {
              problems.add(
                '$at title $rect leaves the panel $panelRect: '
                '${ParagraphLines(title).lines.join(' / ')}',
              );
            }
            if (scale == 2.0 || (scale == 1.0 && dock == null)) {
              await shoot(
                tester,
                pumped.root,
                'DISC233-$tag-$host-x${scale.toString().replaceAll('.', '')}',
              );
            }
            for (final error in errors) {
              problems.add('$at ${error.split('\n').first}');
            }
            errors.clear();
          }
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final word in tooWide) {
        debugPrint('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
