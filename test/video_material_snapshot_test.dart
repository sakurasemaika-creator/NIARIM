import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/material_asset.dart';

MaterialAsset asset({
  required String id,
  MaterialType type = MaterialType.video,
  Duration? duration,
}) => MaterialAsset(
  id: id,
  originalFileName: '$id.mp4',
  type: type,
  sizeBytes: 128,
  addedAt: DateTime.utc(2026),
  duration: duration,
);

void main() {
  group('VideoMaterialSnapshot', () {
    test('keeps only video assets and captures resolved paths and duration', () {
      final snapshot = VideoMaterialSnapshot.fromAssets(
        [
          asset(id: 'video-a', duration: const Duration(seconds: 12)),
          asset(id: 'image-a', type: MaterialType.image),
          asset(id: 'video-b'),
        ],
        {
          'video-a': '/project/Materials/video-a.mp4',
          'video-b': null,
        },
      );

      expect(snapshot.sources.keys, ['video-a', 'video-b']);
      expect(snapshot['video-a']!.path, '/project/Materials/video-a.mp4');
      expect(snapshot['video-a']!.duration, const Duration(seconds: 12));
      expect(snapshot['video-a']!.isMissing, isFalse);
      expect(snapshot['video-b']!.path, isNull);
      expect(snapshot['video-b']!.isMissing, isTrue);
      expect(snapshot.contains('image-a'), isFalse);
    });

    test('does not expose a mutable source map', () {
      final snapshot = VideoMaterialSnapshot.fromAssets(
        [asset(id: 'video-a')],
        {'video-a': '/video-a.mp4'},
      );

      expect(
        () => snapshot.sources['video-b'] = const VideoMaterialSource(
          materialId: 'video-b',
          path: '/video-b.mp4',
          duration: null,
        ),
        throwsUnsupportedError,
      );
    });

    test('does not invent a path for an unprovided material', () {
      final snapshot = VideoMaterialSnapshot.fromAssets(
        [asset(id: 'video-a')],
        const {},
      );

      expect(snapshot['video-a']!.path, isNull);
      expect(snapshot['video-a']!.isMissing, isTrue);
    });
  });
}
