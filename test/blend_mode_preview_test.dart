import 'dart:io';
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

  testWidgets('the picker: two columns, each name above a large picture, '
      'the current mode marked; drawn for review', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final boundary = GlobalKey();
    LayerBlendMode? chosen;
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
                    );
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
    // The picture is far larger than the old 60 x 36 and sits below the
    // name.
    final multiply = find.byKey(const ValueKey('blend-mode-tile-multiply'));
    final picture = find.descendant(
      of: multiply,
      matching: find.byType(BlendModePreview),
    );
    final size = tester.getSize(picture);
    expect(size.width, greaterThan(120));
    expect(size.height, greaterThan(70));
    final name = find.descendant(of: multiply, matching: find.byType(Text));
    expect(
      tester.getBottomLeft(name).dy,
      lessThanOrEqualTo(tester.getTopLeft(picture).dy),
    );
    final shape =
        tester.widget<Material>(multiply).shape! as RoundedRectangleBorder;
    expect(shape.side.width, 2, reason: 'the current mode is marked');
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
    await tester.tap(find.byKey(const ValueKey('blend-mode-tile-screen')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(chosen, LayerBlendMode.screen);
  });
}
