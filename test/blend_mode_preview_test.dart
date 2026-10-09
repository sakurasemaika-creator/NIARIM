import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/utils/blend_mode_label.dart';
import 'package:niarim/widgets/blend_mode_preview.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

/// The blend mode picker shows each mode's look: one fixture (colour
/// swatches over a dark-to-light backdrop, the lower third at half opacity)
/// drawn in each of the 25 modes with the compositor's own formulas. Every
/// mode looks different, and Addition and Linear Dodge, the same at full
/// opacity, part ways at half.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const w = kBlendPreviewWidth, h = kBlendPreviewHeight;

  test('every blend mode looks different', () {
    final pictures = {
      for (final mode in LayerBlendMode.values)
        mode: blendModePreviewPixels(mode),
    };
    final modes = LayerBlendMode.values;
    for (var a = 0; a < modes.length; a++) {
      for (var b = a + 1; b < modes.length; b++) {
        final pa = pictures[modes[a]]!, pb = pictures[modes[b]]!;
        var differing = 0;
        for (var i = 0; i < pa.length; i += 4) {
          if ((pa[i] - pb[i]).abs() +
                  (pa[i + 1] - pb[i + 1]).abs() +
                  (pa[i + 2] - pb[i + 2]).abs() >
              6) {
            differing++;
          }
        }
        expect(
          differing,
          greaterThan(40),
          reason: '${modes[a].name} and ${modes[b].name} look alike',
        );
      }
    }
  });

  test('Addition and Linear Dodge differ only at half opacity', () {
    final add = blendModePreviewPixels(LayerBlendMode.addition);
    final dodge = blendModePreviewPixels(LayerBlendMode.linearDodge);
    int luma(List<int> p, int x, int y) {
      final i = (y * w + x) * 4;
      return p[i] + p[i + 1] + p[i + 2];
    }

    // The red swatch over a mid backdrop: same at full opacity…
    const x = w ~/ 10;
    const full = h ~/ 5, half = h - h ~/ 5;
    expect(luma(add, x, full), luma(dodge, x, full));
    // …Addition brighter at half.
    expect(luma(add, x, half), greaterThan(luma(dodge, x, half) + 20));
  });

  test('Normal shows the swatches themselves', () {
    final normal = blendModePreviewPixels(LayerBlendMode.normal);
    final i = (h ~/ 5 * w + w ~/ 10) * 4;
    expect(normal.sublist(i, i + 3), [230, 51, 51]);
  });

  testWidgets('the picker: two columns, each name at the top of its tile '
      'above a large picture; a tapped mode shows on the canvas preview and '
      '適用 sets it; the title, preview, close and 適用 stay while the tiles '
      'scroll; drawn for review', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final boundary = GlobalKey();
    LayerBlendMode? chosen;
    var closed = false;
    final asked = <LayerBlendMode>[];
    // The canvas in a mode: a picture whose colour tells the mode.
    Future<ui.Image?> canvasIn(LayerBlendMode mode, int maxSize) async {
      asked.add(mode);
      expect(maxSize, greaterThan(100));
      final completer = Completer<ui.Image>();
      const w = 64, h = 36;
      final shade = 40 + mode.index * 8;
      final pixels = Uint8List(w * h * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels.setAll(i, [shade, 255 - shade, 120, 255]);
      }
      ui.decodeImageFromPixels(
        pixels,
        w,
        h,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'HakkouMincho',
          fontFamilyFallback: kBodyFontFallback,
        ),
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            RepaintBoundary(key: boundary, child: child),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    chosen = await showBlendModePicker(
                      context,
                      current: LayerBlendMode.multiply,
                      title: l10n.autofillPartBlendModeLabel,
                      label: (mode) => blendModeLabel(l10n, mode),
                      preview: canvasIn,
                      previewBackground: 0xFFFFFFFF,
                      previewAspectRatio: 16 / 9,
                    );
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    // The preview opens on the layer's own mode.
    expect(asked, [LayerBlendMode.multiply]);
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('blend-mode-tile-'),
    );
    expect(tiles, findsAtLeastNWidgets(6));
    final lefts = {
      for (final e in tiles.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dx.round(),
    };
    expect(lefts, hasLength(2), reason: 'two columns');
    // Each name sits at the very top of its tile (no space above it), the
    // picture below it, large; pictures in a row line up.
    final pictureTops = <int, Set<int>>{};
    for (final e in tiles.evaluate()) {
      final tile = find.byWidget(e.widget);
      final name = find.descendant(of: tile, matching: find.byType(Text));
      final picture = find.descendant(
        of: tile,
        matching: find.byType(BlendModePreview),
      );
      final top = tester.getTopLeft(tile).dy;
      expect(tester.getTopLeft(name).dy - top, lessThanOrEqualTo(8));
      expect(
        tester.getBottomLeft(name).dy,
        lessThanOrEqualTo(tester.getTopLeft(picture).dy),
      );
      expect(tester.getSize(picture).width, greaterThan(120));
      expect(tester.getSize(picture).height, greaterThan(70));
      pictureTops
          .putIfAbsent(top.round(), () => {})
          .add(tester.getTopLeft(picture).dy.round());
    }
    for (final tops in pictureTops.values) {
      expect(tops, hasLength(1), reason: 'pictures of a row line up');
    }
    final multiply = find.byKey(const ValueKey('blend-mode-tile-multiply'));
    Material material(Finder tile) => tester.widget<Material>(
      find.descendant(of: tile, matching: find.byType(Material)).first,
    );
    expect(
      (material(multiply).shape! as RoundedRectangleBorder).side.width,
      2,
      reason: 'the current mode is marked',
    );
    // The title, then the canvas preview, then the tiles; 適用 below.
    final preview = find.byKey(const ValueKey('blend-mode-canvas-preview'));
    final grid = find.byKey(const ValueKey('blend-mode-picker-grid'));
    final apply = find.byKey(const ValueKey('blend-mode-apply'));
    final title = find.text(l10n.autofillPartBlendModeLabel);
    expect(
      tester.getBottomLeft(title).dy,
      lessThanOrEqualTo(tester.getTopLeft(preview).dy),
    );
    expect(
      tester.getBottomLeft(preview).dy,
      lessThanOrEqualTo(tester.getTopLeft(grid).dy),
    );
    expect(
      tester.getBottomLeft(grid).dy,
      lessThanOrEqualTo(tester.getTopLeft(apply).dy),
    );
    expect(tester.getSize(preview).height, greaterThan(150));
    expect(
      find.descendant(of: preview, matching: find.byType(RawImage)),
      findsOneWidget,
    );

    // Tapping a tile picks it and shows it on the preview; the picker stays.
    await tester.tap(find.byKey(const ValueKey('blend-mode-tile-screen')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(closed, isFalse);
    expect(asked.last, LayerBlendMode.screen);
    expect(
      find.descendant(
        of: preview,
        matching: find.text(blendModeLabel(l10n, LayerBlendMode.screen)),
      ),
      findsOneWidget,
    );
    expect(
      (material(find.byKey(const ValueKey('blend-mode-tile-screen'))).shape!
              as RoundedRectangleBorder)
          .side
          .width,
      2,
    );
    expect((material(multiply).shape! as RoundedRectangleBorder).side.width, 1);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory('build/blend-preview').createSync(recursive: true);
      File(
        'build/blend-preview/picker.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });

    // Scrolling moves only the tiles.
    final fixed = [title, preview, apply].map(tester.getTopLeft).toList();
    final firstTile = tiles.evaluate().first.widget;
    final before = tester.getTopLeft(find.byWidget(firstTile)).dy;
    await tester.drag(grid, const Offset(0, -300));
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    expect([title, preview, apply].map(tester.getTopLeft).toList(), fixed);
    final moved = find.byWidget(firstTile);
    if (moved.evaluate().isNotEmpty) {
      expect(tester.getTopLeft(moved).dy, lessThan(before - 100));
    }

    // 適用 sets the picked mode.
    await tester.tap(apply);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(closed, isTrue);
    expect(chosen, LayerBlendMode.screen);

    // Closed without 適用, nothing is set.
    closed = false;
    await tester.tap(find.text('open'));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('blend-mode-tile-overlay')));
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.close));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(closed, isTrue);
    expect(chosen, isNull);
  });

  testWidgets('on a small phone with large text the picker still fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showBlendModePicker(
                  context,
                  current: LayerBlendMode.linearDodge,
                  title: AppLocalizations.of(
                    context,
                  )!.autofillPartBlendModeLabel,
                  label: (mode) =>
                      blendModeLabel(AppLocalizations.of(context)!, mode),
                  preview: (mode, size) async => null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final grid = find.byKey(const ValueKey('blend-mode-picker-grid'));
    expect(tester.getSize(grid).height, greaterThan(120));
    final apply = find.byKey(const ValueKey('blend-mode-apply'));
    expect(tester.getBottomLeft(apply).dy, lessThanOrEqualTo(640));
    // The current mode was scrolled into view.
    expect(
      find.byKey(const ValueKey('blend-mode-tile-linearDodge')),
      findsOneWidget,
    );
  });
}
