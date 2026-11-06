import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'audio import accepts audio and video containers but stays audio-only',
    () {
      final s = File(
        'lib/screens/timeline/timeline_screen.dart',
      ).readAsStringSync();
      expect(s, contains('_ClipTrackType.audio => FileType.custom'));
      expect(s, contains("'mp3'"));
      expect(s, contains("'mp4'"));
      expect(s, contains("'mov'"));
      expect(s, contains('allowedExtensions: allowedExtensions'));
    },
  );
  test('video path keeps embedded audio enabled', () {
    final s = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    expect(s, contains('_ClipTrackType.video => FileType.video'));
    expect(
      s,
      contains('await controller.setVolume(clip.volume.clamp(0.0, 1.0));'),
    );
    // The video's own sound is set in the material edit panel, straight on
    // its layer, and a duplicate copies the whole layer (its sound with it).
    final panel = File(
      'lib/screens/timeline/widgets/material_edit_panel.dart',
    ).readAsStringSync();
    expect(panel, contains('videoVolume: v.round() / 100'));
    expect(s, contains('layer: sourceLayer.copyWith('));
  });
  test('audio and video clip editor exposes play pause', () {
    final s = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    expect(s, contains('final ValueGetter<bool> isPlaying;'));
    expect(s, contains('final VoidCallback onTogglePlay;'));
    expect(s, contains('isPlaying: () => _isPlaying'));
    expect(s, contains('onTogglePlay: _togglePlay'));
    expect(s, contains('widget.onTogglePlay();'));
  });
}
