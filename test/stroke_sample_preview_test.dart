import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
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
    for (var i = 0; i < 40 && find.byType(RawImage).evaluate().length < 3; i++) {
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
}
