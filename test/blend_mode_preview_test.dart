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
    const full = 12, half = h - 12;
    expect(luma(add, x, full), luma(dodge, x, full));
    // …Addition brighter at half.
    expect(luma(add, x, half), greaterThan(luma(dodge, x, half) + 20));
  });

  test('Normal shows the swatches themselves', () {
    final normal = blendModePreviewPixels(LayerBlendMode.normal);
    final i = (12 * w + w ~/ 10) * 4;
    expect(normal.sublist(i, i + 3), [230, 51, 51]);
  });

  testWidgets('the picker rows, drawn for review', (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'HakkouMincho',
          fontFamilyFallback: kBodyFontFallback,
        ),
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: boundary,
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 3.6,
                  children: [
                    for (final mode in LayerBlendMode.values)
                      ListTile(
                        dense: true,
                        leading: BlendModePreview(mode),
                        title: Text(
                          blendModeLabel(l10n, mode),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(find.byType(BlendModePreview), findsNWidgets(25));
    expect(find.byType(RawImage), findsNWidgets(25));
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
  });
}
