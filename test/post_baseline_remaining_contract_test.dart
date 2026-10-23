import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/layer.dart';

void main() {
  test(
    'timeline video volume is independent from opacity and survives copyWith',
    () {
      const layer = Layer(
        id: 'video',
        name: 'video',
        type: LayerType.timelineVideo,
        opacity: 25,
        videoVolume: 0.72,
      );
      expect(layer.opacity, 25);
      expect(layer.videoVolume, closeTo(0.72, 1e-9));
      final changed = layer.copyWith(opacity: 80, videoVolume: 0.18);
      expect(changed.opacity, 80);
      expect(changed.videoVolume, closeTo(0.18, 1e-9));
    },
  );

  test('timeline UI and playback use clip.volume for video audio', () {
    final source = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('controller.setVolume(clip.volume.clamp(0.0, 1.0))'),
    );
    expect(source, isNot(contains('controller.setVolume(clip.videoOpacity')));
    // A video is edited in the material edit panel (with the preview in
    // view): its volume slider writes the layer's videoVolume, and the
    // track's clip mirrors it for playback.
    final panel = File(
      'lib/screens/timeline/widgets/material_edit_panel.dart',
    ).readAsStringSync();
    final videoSection = panel.substring(
      panel.indexOf('Widget _videoSection(Layer layer)'),
    );
    expect(videoSection, contains('l10n.timelineClipVolumeLabel'));
    expect(videoSection, contains('videoVolume: v.round() / 100'));
    expect(source, contains('clip.volume = layer.videoVolume.clamp(0.0, 1.0)'));
    expect(source, contains('volume: layer.type == LayerType.timelineVideo'));
  });

  test(
    'text body and outline expose current-color chips and canvas eyedropper',
    () {
      final source = File(
        'lib/screens/canvas/canvas_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_TextColorEyedropperTarget.body'));
      expect(source, contains('_TextColorEyedropperTarget.outline'));
      expect(source, contains('startTextCanvasEyedropper'));
      expect(source, contains('pickTextColor'));
      expect(source, contains('_pendingTextColorEyedropper'));
      expect(source, contains('existing: next'));
      expect(source, contains('_textColorEyedropperTarget != null'));
    },
  );

  test(
    'project serialization stores videoVolume with backward-compatible default',
    () {
      final source = File(
        'lib/engine/niapro_serializer.dart',
      ).readAsStringSync();
      expect(source, contains("'videoVolume': l.videoVolume"));
      expect(source, contains("(j['videoVolume'] as num?)?.toDouble() ?? 1.0"));
    },
  );
}
