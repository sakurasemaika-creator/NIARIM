import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'export-verification';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'expiry retains every body frame and appends only the five-second logo',
    () async {
      final premium = PremiumService();
      addTearDown(premium.dispose);
      final auth = _Auth();
      addTearDown(auth.dispose);
      premium.bindGoogleAuth(auth);

      void setBenefits(DateTime expiresAt) {
        premium.applyServerCoinBenefitEntitlements([
          for (final feature in [
            PremiumFeature.unlimitedDuration,
            PremiumFeature.endCardEdit,
          ])
            {
              'feature': feature.name,
              'status': 'active',
              'expiresAtEpochMs': expiresAt.millisecondsSinceEpoch,
            },
        ], accountId: auth.account.id);
      }

      setBenefits(DateTime.now().add(const Duration(minutes: 1)));
      expect(premium.isPremium, isFalse);
      expect(premium.maxProjectDurationSeconds, 7200);
      final before = premium.shouldAppendOfficialEndCard(
        projectHidden: true,
        defaultHidden: false,
      );
      expect(before, isFalse);
      expect(
        premium.shouldAppendOfficialEndCard(
          projectHidden: false,
          defaultHidden: true,
        ),
        isTrue,
      );

      setBenefits(DateTime.now().subtract(const Duration(seconds: 1)));
      expect(premium.maxProjectDurationSeconds, 90);
      final after = premium.shouldAppendOfficialEndCard(
        projectHidden: true,
        defaultHidden: true,
      );
      expect(after, isTrue);

      final evidence = Platform.environment['NIARIM_EXPIRY_VIDEO_OUTPUT'];
      if (evidence == null) return;

      final root = await Directory.systemTemp.createTemp('expiry-video-');
      addTearDown(() => root.delete(recursive: true));
      addTearDown(ExportStorage.invalidate);
      ExportStorage.invalidate();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const encoder = MethodChannel('com.niarim.niarim/hw_video_encoder');
      messenger.setMockMethodCallHandler(paths, (_) async => root.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(paths, null);
        messenger.setMockMethodCallHandler(encoder, null);
      });

      messenger.setMockMethodCallHandler(encoder, (call) async {
        final args = call.arguments as Map<Object?, Object?>;
        final files = List<String>.from(args['framePaths']! as List);
        final input = Directory('${root.path}/sequence')..createSync();
        try {
          for (final (index, path) in files.indexed) {
            File(
              path,
            ).copySync('${input.path}/${index.toString().padLeft(5, '0')}.png');
          }
          final status = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-y',
            '-framerate',
            '${args['fps']}',
            '-i',
            '${input.path}/%05d.png',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            args['outputPath']! as String,
          ]);
          expect(status.exitCode, 0, reason: status.stderr.toString());
        } finally {
          input.deleteSync(recursive: true);
        }
        return null;
      });

      final scenes = [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: List.generate(91, (i) => Frame(index: i, layers: const [])),
        ),
      ];
      final tiles = TileManager(canvasWidth: 96, canvasHeight: 96);
      addTearDown(tiles.dispose);
      final destination = Directory(evidence)..createSync(recursive: true);
      for (final (name, endMark, seconds) in [
        ('before_expiry.mp4', before, 91),
        ('after_expiry.mp4', after, 96),
      ]) {
        final output = await ExportEngine().exportMp4(
          scenes: scenes,
          tileManager: tiles,
          fps: 1,
          drawingWidth: 96,
          drawingHeight: 96,
          width: 96,
          height: 96,
          backgroundColor: 0xFF1466A1,
          appendEndCard: endMark,
        );
        final copy = await File(output).copy('${destination.path}/$name');
        final probe = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'json',
          copy.path,
        ]);
        expect(probe.exitCode, 0, reason: probe.stderr.toString());
        final metadata = jsonDecode(probe.stdout as String) as Map;
        expect(
          double.parse((metadata['format'] as Map)['duration'] as String),
          seconds.toDouble(),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
