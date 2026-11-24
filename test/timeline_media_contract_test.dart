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

  test('timeline split mode applies to every material track type', () {
    final s = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    expect(s, contains("Key('timelineSplitModeButton')"));
    expect(s, contains("Key('timelineSplitApplyButton')"));
    expect(s, contains("Key('timelineSplitCancelButton')"));
    expect(s, contains('void _applySplitAtCurrentFrame()'));
    expect(s, contains('final targets = _allClips'));
    expect(s, contains('_clipsOfType(clip.trackType).add(clip)'));
    expect(s, contains('sourceStartFrame: rightSourceStart'));
    // A video's right half starts at the split's source position (or on the
    // held last frame); test/timeline_split_test.dart checks every frame.
    expect(s, contains('sourceTrimStart: isVideo ? videoRightStart : null'));
    expect(
      s,
      contains(
        'final videoRightStart = heldRight ? clip.useEnd : rightSourceStart;',
      ),
    );
    expect(s, contains('fadeIn: 0'));
    expect(s, contains('fadeOut: 0'));
  });

  test('video preview seek uses the shared source-time mapper', () {
    final s = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    expect(s, contains("import '../../engine/timeline_video_time.dart';"));
    expect(s, contains('TimelineVideoTimeMapper.sourcePositionAt('));
    expect(s, contains('sourceTrimStartFrame: clip.useStart'));
    expect(s, contains('sourceTrimEndFrame: clip.useEnd'));
  });
}
