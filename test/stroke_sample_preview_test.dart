import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/widgets/stroke_sample_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('brush, tone and stamp show rendered two-row wave samples', (
    tester,
  ) async {
    const brush = Brush(
      id: 'wave-brush',
      name: 'Wave brush',
      size: 10,
      opacity: 90,
      spacing: 2,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      fadeMode: FadeMode.off,
      strokeDecay: false,
    );
    const tone = Tone(id: 'wave-tone', name: '網点 50%');
    const stamp = Stamp(id: 'wave-stamp', name: '星');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StrokeSamplePreview(brush: brush, color: Colors.deepPurple),
                  StrokeSamplePreview(tone: tone, color: Colors.deepPurple),
                  StrokeSamplePreview(stamp: stamp, color: Colors.deepPurple),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The actual raster engines and image decoder complete asynchronously.
    for (
      var i = 0;
      i < 40 && find.byType(RawImage).evaluate().length < 3;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 75)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.byType(RawImage),
      findsNWidgets(3),
      reason: 'All three tool types should show actual rasterized waves',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'New and edited user brush, tone and stamp refresh their pixels',
    (tester) async {
      const brush = Brush(
        id: 'user-custom-brush',
        name: 'My brush',
        size: 12,
        opacity: 100,
        spacing: 2,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
      );
      const tone = Tone(id: 'custom-tone', name: '網点 50%');
      const stamp = Stamp(id: 'custom-stamp', name: '星');

      Widget make(Brush b, Tone t, Stamp a) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StrokeSamplePreview(
                key: const ValueKey('custom-brush'),
                brush: b,
                color: Colors.black,
              ),
              StrokeSamplePreview(
                key: const ValueKey('custom-tone'),
                tone: t,
                color: Colors.black,
              ),
              StrokeSamplePreview(
                key: const ValueKey('custom-stamp'),
                stamp: a,
                color: Colors.black,
              ),
            ],
          ),
        ),
      );
      Future<List<ui.Image>> sample({List<ui.Image>? previous}) async {
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 30));
          final frames = tester
              .widgetList<RawImage>(find.byType(RawImage))
              .map((w) => w.image)
              .whereType<ui.Image>()
              .toList();
          if (frames.length == 3 &&
              (previous == null ||
                  List.generate(
                    3,
                    (i) => !identical(frames[i], previous[i]),
                  ).every((changed) => changed))) {
            return frames;
          }
        }
        throw StateError('Raster images were not regenerated after editing');
      }

      Future<List<List<int>>> pixels(List<ui.Image> images) async =>
          (await tester.runAsync(() async {
            final result = <List<int>>[];
            for (final image in images) {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              result.add(data!.buffer.asUint8List().toList());
            }
            return result;
          }))!;

      await tester.pumpWidget(make(brush, tone, stamp));
      final oldImages = await sample();
      final before = await pixels(oldImages);
      await tester.pumpWidget(
        make(
          brush.copyWith(opacity: 18, size: 18),
          tone.copyWith(name: '横ライン'),
          stamp.copyWith(opacity: 22, scatter: 0.7, density: 2.0),
        ),
      );
      final afterImages = await sample(previous: oldImages);
      final after = await pixels(afterImages);
      for (var i = 0; i < 3; i++) {
        expect(
          listEquals(before[i], after[i]),
          isFalse,
          reason: 'Edited user preset #$i must change the actual wave pixels',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Airbrush and blur presets actually contain soft alpha halos', (
    tester,
  ) async {
    final presets = BrushService.builtInBrushes;
    final pen = presets.firstWhere((p) => p.name == 'ペン');
    final airbrush = presets.firstWhere((p) => p.name == 'エアブラシ');
    final softBlur = presets.firstWhere((p) => p.name == 'ぼかし');
    expect(airbrush.pressureOff.blur.enabled, isTrue);
    expect(airbrush.pressureOff.blur.value, greaterThan(0));
    expect(
      softBlur.pressureOff.blur.value,
      greaterThan(airbrush.pressureOff.blur.value),
    );
    expect(pen.pressureOff.blur.enabled, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StrokeSamplePreview(brush: pen, color: Colors.black),
              StrokeSamplePreview(brush: airbrush, color: Colors.black),
              StrokeSamplePreview(brush: softBlur, color: Colors.black),
            ],
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 80 && find.byType(RawImage).evaluate().length < 3;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 70)),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    final images = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .map((widget) => widget.image)
        .whereType<ui.Image>()
        .toList();
    expect(images, hasLength(3));
    final pixels = (await tester.runAsync(() async {
      final output = <List<int>>[];
      for (final image in images) {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        output.add(data!.buffer.asUint8List());
      }
      return output;
    }))!;
    int softPixels(List<int> data) {
      var count = 0;
      for (var i = 3; i < data.length; i += 4) {
        if (data[i] > 0 && data[i] < 80) count++;
      }
      return count;
    }

    expect(
      softPixels(pixels[1]),
      greaterThan(softPixels(pixels[0])),
      reason: 'Airbrush must visibly soften more pixels than a pen',
    );
    expect(
      softPixels(pixels[2]),
      greaterThan(softPixels(pixels[0])),
      reason: 'Blur preset must visibly soften more pixels than a pen',
    );
    expect(tester.takeException(), isNull);
  });
}
