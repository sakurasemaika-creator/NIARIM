import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/scrollable_sheet_body.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

/// ボトムシートの中身が、シートの上の角の丸みの外へ描かれないこと。
///
/// シートの面は上の角が丸い（半径28）が、中身はシートの形で切り抜かれて
/// いなかった（`BottomSheet`の既定は切り抜かない）。中身をスクロールすると、
/// 上の縁まで来た中身の角（バケツの長押しのシートのトーンの四角い枠等）が、
/// 丸みの外（後ろの画面の上）に描かれた。
void main() {
  useTemporaryProjectStorage();

  const shot = ValueKey('sheet-shape-shot');
  late List<SingleChildWidget> providers;

  Future<void> boot(WidgetTester tester, Size view) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'language': 'ja',
    });
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    providers = (await tester.runAsync(buildAppProviders))!;
  }

  Widget app(Widget home) => MultiProvider(
    providers: providers,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: context.watch<ThemeService>().themeData,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => RepaintBoundary(key: shot, child: child),
        home: home,
      ),
    ),
  );

  Future<({Uint8List pixels, int width})> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final out = (pixels: data!.buffer.asUint8List(), width: image.width);
      image.dispose();
      return out;
    }))!;
  }

  /// シートの上の2つの角で、丸み（半径[radius]）の外の画素のうち、[a]と[b]で
  /// 違うものの数（丸みの縁のぼかしの1pxは数えない）。
  int changedOutsideCorners(
    ({Uint8List pixels, int width}) a,
    ({Uint8List pixels, int width}) b,
    Rect sheet,
    double radius,
  ) {
    var changed = 0;
    for (final (cx, xs) in [
      (sheet.left + radius, (sheet.left.ceil(), (sheet.left + radius).floor())),
      (
        sheet.right - radius,
        ((sheet.right - radius).ceil(), sheet.right.floor()),
      ),
    ]) {
      final cy = sheet.top + radius;
      for (var y = sheet.top.ceil(); y < (sheet.top + radius).floor(); y++) {
        for (var x = xs.$1; x < xs.$2; x++) {
          final d = (Offset(x + 0.5, y + 0.5) - Offset(cx, cy)).distance;
          if (d < radius + 1.5) continue;
          final i = (y * a.width + x) * 4;
          if (a.pixels[i] != b.pixels[i] ||
              a.pixels[i + 1] != b.pixels[i + 1] ||
              a.pixels[i + 2] != b.pixels[i + 2]) {
            changed++;
          }
        }
      }
    }
    return changed;
  }

  /// 開いたシートを少しずつスクロールし、上の角の丸みの外が開いたときと
  /// 変わった画素の数の最大を返す。
  Future<int> scrollAndCompare(WidgetTester tester) async {
    final sheet = find.byType(BottomSheet);
    final sheetRect = tester.getRect(sheet);
    final shape =
        tester.widget<BottomSheet>(sheet).shape ??
        Theme.of(tester.element(sheet)).bottomSheetTheme.shape;
    final radius =
        ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: sheet, matching: find.byType(Scrollable)).first,
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(40), reason: 'scrolls');
    final idle = await capture(tester);
    var worst = 0;
    for (var offset = 4.0; offset < position.maxScrollExtent; offset += 6) {
      position.jumpTo(offset);
      await tester.pump();
      final scrolled = await capture(tester);
      final changed = changedOutsideCorners(idle, scrolled, sheetRect, radius);
      if (changed > worst) worst = changed;
    }
    return worst;
  }

  testWidgets('bucket long-press sheet: the scrolled tone tiles stay inside '
      'the sheet\'s rounded top corners', (tester) async {
    await boot(tester, const Size(360, 440));
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ToolbarWidget(
              currentTool: DrawingTool.bucket,
              currentColor: const Color(0xFF000000),
              onToolSelected: (_) {},
              onColorTap: () {},
              onBrushTap: () {},
              onLayerTap: () {},
              onPenLongPress: () {},
              onFingerLongPress: () {},
              onTextTap: () {},
              onShapeTap: () {},
              onQuickToolTap: () {},
              onQuickToolLongPress: () {},
              onSaveTap: () {},
              onLassoFillSelected: () {},
              onRulerTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bucket = find.byIcon(Icons.format_color_fill).first;
    await tester.ensureVisible(bucket);
    await tester.longPress(bucket);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final changed = await scrollAndCompare(tester);
    expect(
      changed,
      0,
      reason:
          '$changed px outside the rounded top corners changed while the '
          'sheet content scrolled',
    );
  });

  testWidgets('ScrollableSheetBody: coloured rows scrolled to the top stay '
      'inside the sheet\'s rounded top corners', (tester) async {
    await boot(tester, const Size(360, 440));
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ScrollableSheetBody(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 12; i++)
                        ListTile(
                          tileColor: i.isEven
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.tertiary,
                          title: Text('項目$i'),
                          onTap: () {},
                        ),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final changed = await scrollAndCompare(tester);
    expect(
      changed,
      0,
      reason:
          '$changed px outside the rounded top corners changed while the '
          'sheet content scrolled',
    );
  });
}
