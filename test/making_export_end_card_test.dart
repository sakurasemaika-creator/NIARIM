// メイキング動画の書き出しも、作品の書き出しと同じ決まりで公式エンドマーク
// （NIARIMのロゴ、5秒）を最後に付ける。無料会員には付き、プレミアム会員と
// エンドマーク編集・削除の特典を使っている間は（作品・既定の設定が非表示なら）
// 付かない。GIFには付けない（作品の書き出しと同じ）。
//
// エンコーダーはテストの環境に無いので、本物と同じ通り道（MP4は
// `com.niarim.niarim/hw_video_encoder`、WebM・AVIはFFmpegのチャンネル）で
// 受け、渡されたコマを読む。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/making_export.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/project/making_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/clock_duration_label.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_real_async.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _hwEncoderChannel = MethodChannel('com.niarim.niarim/hw_video_encoder');
const _ffmpegChannel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

const _projectId = 'making_project';
const _width = 160;
const _height = 120;
const _snapshotCount = 3;
const _endCardFrames = MakingExport.fps * ExportEngine.officialEndCardSeconds;

/// The official end mark: black paper with the pink badge in the middle.
bool _looksLikeEndCard(img.Image frame) {
  final logoSize =
      (frame.width < frame.height ? frame.width : frame.height) * 0.4;
  final logoLeft = (frame.width - logoSize) / 2;
  final logoTop = frame.height / 2 - logoSize * 0.65;
  final corner = frame.getPixel(2, 2);
  final badge = frame.getPixel(
    (logoLeft + logoSize * 0.04).round(),
    (logoTop + logoSize * 0.5).round(),
  );
  bool near(num value, int expected) => (value - expected).abs() <= 24;
  return near(corner.r, 0) &&
      near(corner.g, 0) &&
      near(corner.b, 0) &&
      near(badge.r, 0xFF) &&
      near(badge.g, 0x5C) &&
      near(badge.b, 0x7A);
}

/// A snapshot: white paper with a blue square.
List<int> _snapshotJpeg(int index) {
  final image = img.Image(width: _width, height: _height)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.fillRect(
    image,
    x1: 10 + index * 20,
    y1: 20,
    x2: 50 + index * 20,
    y2: 60,
    color: img.ColorRgb8(30, 60, 220),
  );
  return img.encodeJpg(image, quality: 95);
}

/// A snapshot that tells its index by its colour (red = index).
List<int> _numberedJpeg(int index) {
  final image = img.Image(width: _width, height: _height)
    ..clear(img.ColorRgb8(index, 255 - index, 128));
  return img.encodeJpg(image, quality: 95);
}

class _Premium extends PremiumService {
  @override
  bool get hasVerifiedPlayPremium => true;
}

/// Not a member, with the end mark editing perk exchanged with opals.
class _EndMarkPerk extends PremiumService {
  @override
  bool isServerCoinBenefitActive(String benefit) => benefit == 'endCardEdit';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory documents;
  late List<String> snapshotPaths;

  /// The frames each encoder received, decoded while they still exist.
  late List<List<img.Image>> encodedFrames;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-making-end-card-');
    documents = Directory('${root.path}/documents')..createSync();
    final temporary = Directory('${root.path}/temporary')..createSync();
    final making = Directory(
      '${documents.path}/niarim/projects/$_projectId/Making',
    )..createSync(recursive: true);
    snapshotPaths = [
      for (var i = 0; i < _snapshotCount; i++)
        (File(
          '${making.path}/making_${(i + 1).toString().padLeft(6, '0')}.jpg',
        )..writeAsBytesSync(_snapshotJpeg(i))).path,
    ];
    encodedFrames = [];
    ExportStorage.invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      return call.method == 'getTemporaryDirectory'
          ? temporary.path
          : documents.path;
    });
    messenger.setMockMethodCallHandler(_hwEncoderChannel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      final cache = <String, img.Image>{};
      encodedFrames.add([
        for (final path in List<String>.from(args['framePaths']! as List))
          cache[path] ??= img.decodeImage(File(path).readAsBytesSync())!,
      ]);
      File(args['outputPath']! as String).writeAsBytesSync([1, 2, 3]);
      return null;
    });
    var arguments = const <String>[];
    messenger.setMockMethodCallHandler(_ffmpegChannel, (call) async {
      switch (call.method) {
        case 'ffmpegSession':
          arguments = List<String>.from(
            (call.arguments as Map<Object?, Object?>)['arguments']!
                as List<Object?>,
          );
          return <String, Object?>{
            'sessionId': 1,
            'createTime': DateTime.now().millisecondsSinceEpoch,
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'command': arguments.join(' '),
          };
        case 'ffmpegSessionExecute':
          final pattern = arguments[arguments.indexOf('-i') + 1];
          final staging = Directory(File(pattern).parent.path);
          final files =
              staging
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.png'))
                  .toList()
                ..sort((a, b) => a.path.compareTo(b.path));
          encodedFrames.add([
            for (final file in files) img.decodeImage(file.readAsBytesSync())!,
          ]);
          File(arguments.last).writeAsBytesSync([1, 2, 3]);
          return null;
        case 'abstractSessionGetReturnCode':
          return 0;
        case 'getArch':
          return 'arm64-v8a';
        case 'getPlatform':
          return 'android';
        case 'getPackageName':
          return 'video';
        case 'isLTSBuild':
          return false;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _ffmpegEventChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    messenger.setMockMethodCallHandler(_hwEncoderChannel, null);
    messenger.setMockMethodCallHandler(_ffmpegChannel, null);
    messenger.setMockStreamHandler(_ffmpegEventChannel, null);
    ExportStorage.invalidate();
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('MakingExport', () {
    for (final format in const [
      MakingExportFormat.mp4,
      MakingExportFormat.webm,
      MakingExportFormat.avi,
    ]) {
      test('${format.name}: the end mark follows the snapshots for '
          '${ExportEngine.officialEndCardSeconds} seconds', () async {
        await MakingExport.export(
          snapshotPaths: snapshotPaths,
          format: format,
          outputPath: '${root.path}/with.${format.name}',
          officialMark: true,
        );
        final frames = encodedFrames.single;
        expect(frames, hasLength(_snapshotCount + _endCardFrames));
        for (final (index, frame) in frames.indexed) {
          expect(frame.width, _width);
          expect(frame.height, _height);
          expect(
            _looksLikeEndCard(frame),
            index >= _snapshotCount,
            reason: 'frame $index',
          );
        }
      });

      test('${format.name}: no end mark when it is not due', () async {
        await MakingExport.export(
          snapshotPaths: snapshotPaths,
          format: format,
          outputPath: '${root.path}/without.${format.name}',
          officialMark: false,
        );
        final frames = encodedFrames.single;
        expect(frames, hasLength(_snapshotCount));
        expect(frames.where(_looksLikeEndCard), isEmpty);
      });
    }

    test('GIF never carries the end mark, like the work export: it gets the '
        'corner logo instead', () async {
      expect(
        MakingExport.carriesOfficialEndCard(MakingExportFormat.gif),
        isFalse,
      );
      final output = '${root.path}/making.gif';
      await MakingExport.export(
        snapshotPaths: snapshotPaths,
        format: MakingExportFormat.gif,
        outputPath: output,
        officialMark: true,
      );
      final gif = img.decodeGif(File(output).readAsBytesSync())!;
      expect(gif.numFrames, _snapshotCount);
      for (final frame in gif.frames) {
        expect(_looksLikeEndCard(frame), isFalse);
      }
    });

    test('the length can be any whole second from 1 up to the original, and '
        'never longer', () {
      const mp4 = MakingExportFormat.mp4;
      // 1000 operations are 125 seconds.
      expect(MakingExport.lengthLimitSeconds(1000, mp4), 125);
      expect(MakingExport.exportedCount(1000, mp4, null), 1000);
      expect(MakingExport.exportedCount(1000, mp4, 37), 37 * MakingExport.fps);
      expect(MakingExport.exportedCount(1000, mp4, 1), MakingExport.fps);
      expect(MakingExport.exportedCount(1000, mp4, 0), MakingExport.fps);
      // The original length or more keeps every frame (not longer).
      expect(MakingExport.exportedCount(1000, mp4, 125), 1000);
      expect(MakingExport.exportedCount(1000, mp4, 600), 1000);
      // Nothing to choose for a GIF or a making of a second or less.
      expect(
        MakingExport.lengthLimitSeconds(1000, MakingExportFormat.gif),
        isNull,
      );
      expect(
        MakingExport.exportedCount(1000, MakingExportFormat.gif, 10),
        1000,
      );
      expect(MakingExport.lengthLimitSeconds(15, mp4), isNull);
      expect(MakingExport.lengthLimitSeconds(16, mp4), 2);
    });
  });

  group('MakingScreen', () {
    Future<void> pumpScreen(WidgetTester tester, PremiumService premium) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await tester.runAsync(themes.init);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themes),
            ChangeNotifierProvider(create: (_) => ProjectService()),
            ChangeNotifierProvider<PremiumService>.value(value: premium),
          ],
          child: MaterialApp(
            theme: themes.themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MakingScreen(projectId: _projectId),
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      // Reading the history is real file work; under load it takes longer.
      final line = find.byKey(const Key('makingExportOutputSummary'));
      for (var i = 0; i < 100 && line.evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 50));
      }
    }

    Future<List<img.Image>> exportMp4(WidgetTester tester) async {
      final l10n = lookupAppLocalizations(const Locale('ja'));
      await tester.tap(find.text(l10n.makingExportLabel));
      for (var i = 0; i < 200 && encodedFrames.isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 40));
      }
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(find.text(l10n.makingExportComplete), findsOneWidget);
      return encodedFrames.single;
    }

    String summary(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('makingExportOutputSummary')))
        .data!;

    String duration(WidgetTester tester) => clockDurationLabel(
      MaterialLocalizations.of(tester.element(find.byType(MakingScreen))),
      0,
    );

    testWidgets('a free member\'s making video ends with the end mark', (
      tester,
    ) async {
      final premium = PremiumService();
      addTearDown(premium.dispose);
      await pumpScreen(tester, premium);
      final l10n = lookupAppLocalizations(const Locale('ja'));
      expect(summary(tester), l10n.exportOutputWithEndCard(duration(tester)));

      final frames = await exportMp4(tester);
      expect(frames, hasLength(_snapshotCount + _endCardFrames));
      expect(frames.take(_snapshotCount).where(_looksLikeEndCard), isEmpty);
      expect(frames.skip(_snapshotCount).every(_looksLikeEndCard), isTrue);
    });

    testWidgets('a free member\'s GIF says it gets the corner logo', (
      tester,
    ) async {
      final premium = PremiumService();
      addTearDown(premium.dispose);
      await pumpScreen(tester, premium);
      final l10n = lookupAppLocalizations(const Locale('ja'));
      await tester.tap(find.text(l10n.exportFormatMp4));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.exportFormatGif).last);
      await tester.pumpAndSettle();
      expect(
        summary(tester),
        l10n.exportOutputWithCornerLogo(duration(tester)),
      );
    });

    for (final (name, premium) in [
      ('a Premium member', _Premium()),
      ('a member with the end mark perk', _EndMarkPerk()),
    ]) {
      testWidgets('$name exports the making video without the end mark', (
        tester,
      ) async {
        addTearDown(premium.dispose);
        await pumpScreen(tester, premium);
        final l10n = lookupAppLocalizations(const Locale('ja'));
        expect(
          summary(tester),
          l10n.exportOutputWithoutEndCard(duration(tester)),
        );

        final frames = await exportMp4(tester);
        expect(frames, hasLength(_snapshotCount));
        expect(frames.where(_looksLikeEndCard), isEmpty);

        // The GIF has no corner logo either.
        await tester.tap(find.text(l10n.exportFormatMp4));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.exportFormatGif).last);
        await tester.pumpAndSettle();
        expect(
          summary(tester),
          l10n.exportOutputWithoutEndCard(duration(tester)),
        );
      });
    }

    testWidgets('a short making has no length to choose', (tester) async {
      final premium = PremiumService();
      addTearDown(premium.dispose);
      await pumpScreen(tester, premium);
      expect(find.byKey(const Key('makingExportLength')), findsNothing);
    });

    testWidgets('the making video can be made shorter (never longer): the '
        'frames are spread evenly over the making, the first and the last '
        'one included, and the end mark follows', (tester) async {
      // 130 operations: 16 seconds at 8 frames a second.
      final making = Directory(
        '${documents.path}/niarim/projects/$_projectId/Making',
      );
      for (final file in making.listSync().whereType<File>()) {
        file.deleteSync();
      }
      const count = 130;
      for (var i = 0; i < count; i++) {
        File(
          '${making.path}/making_${(i + 1).toString().padLeft(6, '0')}.jpg',
        ).writeAsBytesSync(_numberedJpeg(i));
      }
      final premium = PremiumService();
      addTearDown(premium.dispose);
      await pumpScreen(tester, premium);
      final l10n = lookupAppLocalizations(const Locale('ja'));
      final time = MaterialLocalizations.of(
        tester.element(find.byType(MakingScreen)),
      );
      expect(
        summary(tester),
        l10n.exportOutputWithEndCard(clockDurationLabel(time, 16)),
      );

      // The slider ends at the original length: it can only be made shorter.
      expect(
        MakingExport.lengthLimitSeconds(count, MakingExportFormat.mp4),
        16,
      );
      final lengthSlider = find.byKey(const Key('makingExportLength'));
      final original = l10n.makingExportLengthOriginal(
        clockDurationLabel(time, 16),
      );
      expect(
        find.descendant(of: lengthSlider, matching: find.text(original)),
        findsOneWidget,
      );
      final slider = tester.widget<Slider>(
        find.descendant(of: lengthSlider, matching: find.byType(Slider)),
      );
      expect((slider.min, slider.max), (1.0, 16.0));
      IconButton stepper(IconData icon) => tester.widget<IconButton>(
        find.ancestor(
          of: find.descendant(of: lengthSlider, matching: find.byIcon(icon)),
          matching: find.byType(IconButton),
        ),
      );
      expect(stepper(Icons.add_circle_outline).onPressed, isNull);

      // A longer number typed in is refused and the dialog stays open.
      await tester.tap(
        find.descendant(of: lengthSlider, matching: find.text(original)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '40');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(l10n.numberInputRangeError('1', '16')), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '14');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        summary(tester),
        l10n.exportOutputWithEndCard(clockDurationLabel(time, 14)),
      );

      // ＋ goes back towards the original; one second short of it is 15.
      await tester.tap(
        find.descendant(
          of: lengthSlider,
          matching: find.byIcon(Icons.add_circle_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: lengthSlider,
          matching: find.text(clockDurationLabel(time, 15)),
        ),
        findsOneWidget,
      );
      expect(
        summary(tester),
        l10n.exportOutputWithEndCard(clockDurationLabel(time, 15)),
      );

      // 120 pictures are written before the encoder is called.
      await tester.tap(find.text(l10n.makingExportLabel));
      for (
        var i = 0;
        i < 600 &&
            find.text(l10n.makingExportComplete).evaluate().isEmpty &&
            find.text(l10n.makingExportFailed).evaluate().isEmpty;
        i++
      ) {
        await pumpRealAsync(tester, const Duration(milliseconds: 50));
      }
      expect(find.text(l10n.makingExportComplete), findsOneWidget);
      final frames = encodedFrames.single;
      const body = 15 * MakingExport.fps;
      expect(frames, hasLength(body + _endCardFrames));
      int recordOf(img.Image frame) =>
          frame.getPixel(frame.width ~/ 2, frame.height ~/ 2).r.round();
      for (final k in [0, 1, 60, body - 1]) {
        expect(
          (recordOf(frames[k]) - (k * (count - 1) / (body - 1)).round()).abs(),
          lessThanOrEqualTo(3),
          reason: 'frame $k',
        );
      }
      expect(recordOf(frames.first), lessThanOrEqualTo(3));
      expect(recordOf(frames[body - 1]), closeTo(count - 1, 3));
      expect(frames.skip(body).every(_looksLikeEndCard), isTrue);
    });
  });
}
