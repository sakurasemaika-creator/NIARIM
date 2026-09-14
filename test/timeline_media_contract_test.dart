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
    expect(s, contains('videoVolume: clip.trackType == _ClipTrackType.video'));
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
