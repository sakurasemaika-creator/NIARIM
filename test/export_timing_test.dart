import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/models/scene.dart';

void main() {
  test('12 fps project keeps 91 seconds at 30 and 60 fps', () {
    final scenes = [
      Scene(
        id: 'one',
        index: 0,
        frames: List.generate(720, (i) => Frame(index: i)),
      ),
      Scene(
        id: 'two',
        index: 1,
        frames: List.generate(372, (i) => Frame(index: i)),
      ),
    ];
    for (final fps in [30, 60]) {
      final full = ExportTiming(sourceFps: 12, outputFps: fps);
      final free = ExportTiming(sourceFps: 12, outputFps: fps, maxSeconds: 90);
      expect(full.samples(scenes).length, 91 * fps);
      expect(free.samples(scenes).length, 90 * fps);
      expect(free.samples(scenes).last.scene.id, 'two');
      expect(free.samples(scenes).last.frame.index, 359);
      expect(full.samples(scenes).last.frame.index, 371);
      expect(ExportTiming.sourceFrames(scenes), 1092);
    }
  });

  test('GIF frame-delay rounding does not accumulate', () {
    const timing = ExportTiming(sourceFps: 12, outputFps: 30);
    expect(
      List.generate(
        2700,
        (i) => timing.gifDelayMs(i + 1),
      ).reduce((a, b) => a + b),
      90000,
    );
  });
}
