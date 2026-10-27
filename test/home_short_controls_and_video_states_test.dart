import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/exported_work_preview_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as platform;

import 'helpers/exported_work_name.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

class _VideoBackend extends platform.VideoPlayerPlatform {
  final events = StreamController<platform.VideoEvent>.broadcast();
  final calls = <String>[];
  String? createdUri;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(platform.VideoCreationOptions options) async {
    createdUri = options.dataSource.uri;
    return 1;
  }

  @override
  Stream<platform.VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('loop:$looping');
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  // Artwork stand-in with hit testing, not a real codec or a product UI color.
  @override
  Widget buildViewWithOptions(platform.VideoViewOptions options) =>
      const ColoredBox(key: Key('mock-video-view'), color: Color(0xFF236B45));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppLocalizations> open(
    WidgetTester tester, {
    bool short = false,
    bool video = false,
    bool pc = false,
    double? height,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('home-short-video-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    final exports = Directory('${dir.path}/exports')..createSync();
    if (video) {
      File('${exports.path}/AUDIT_video.mp4').writeAsBytesSync([0]);
    } else {
      for (var i = 0; i < 3; i++) {
        final file = File('${exports.path}/AUDIT_${i}_animation.gif');
        file.writeAsBytesSync(
          base64Decode(
            'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
          ),
        );
        file.setLastModifiedSync(DateTime.utc(2026, 10, 27, 0, i));
      }
    }
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    await loadAppFonts(tester);
    tester.view.physicalSize = Size(320, height ?? (short ? 220 : 844));
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('home_tab_1'));
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(ExportedWorkCard).first),
    )!;
  }

  testWidgets(
    'last export delete reaches its confirmation above Home floating actions at 220px',
    (tester) async {
      final l10n = await open(tester, short: true);
      final scroll = find
          .ancestor(
            of: find.byType(ExportedWorkCard).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        findExportedWorkName('AUDIT_0_animation.gif'),
        150,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: findExportedWorkName('AUDIT_0_animation.gif'),
        matching: find.byType(ExportedWorkCard),
      );
      final button = find.descendant(
        of: card,
        matching: find.byIcon(Icons.delete_outline),
      );
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final hitTarget = find.ancestor(
        of: button,
        matching: find.byType(IconButton),
      );
      final hitRect = tester.getRect(hitTarget);
      final viewport = tester.getRect(scroll);
      final folderFab = find.byWidgetPredicate(
        (widget) =>
            widget is FloatingActionButton &&
            widget.heroTag == 'home-add-work-folder',
      );
      expect(hitRect.top, greaterThanOrEqualTo(viewport.top - 1e-9));
      expect(hitRect.bottom, lessThanOrEqualTo(tester.getRect(folderFab).top));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.homeWorkDeleteConfirmTitle('AUDIT_0_animation.gif')),
        findsOneWidget,
        reason: 'The same position must not open the new-folder FAB',
      );
      expect(find.text(l10n.projectListNewFolderTitle), findsNothing);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      for (final fab in tester.widgetList<FloatingActionButton>(
        find.byType(FloatingActionButton),
      )) {
        expect(fab.mini, isTrue);
        final size = tester.getSize(find.byWidget(fab));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved video loading stays square and error keeps Close reachable',
    (tester) async {
      final original = platform.VideoPlayerPlatform.instance;
      final fake = _VideoBackend();
      platform.VideoPlayerPlatform.instance = fake;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        platform.VideoPlayerPlatform.instance = original;
        await fake.events.close();
      });
      final l10n = await open(tester, video: true);
      await tester.tap(findExportedWorkName('AUDIT_video.mp4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(fake.createdUri, contains('AUDIT_video.mp4'));
      final progress = find.descendant(
        of: find.byType(ExportedWorkPreviewLayout),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(
        tester.getSize(progress),
        const Size(32, 32),
        reason: 'A bounded preview must not stretch the loading indicator',
      );
      fake.events.addError(
        PlatformException(
          code: 'AUDIT_invalid_video',
          message: 'AUDIT invalid video',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.homePreviewFailed), findsOneWidget);
      final close = find.text(l10n.commonClose);
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('portrait saved video preserves aspect and playback actions', (
    tester,
  ) async {
    final original = platform.VideoPlayerPlatform.instance;
    final fake = _VideoBackend();
    platform.VideoPlayerPlatform.instance = fake;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      platform.VideoPlayerPlatform.instance = original;
      await fake.events.close();
    });
    final l10n = await open(tester, video: true);
    await tester.tap(findExportedWorkName('AUDIT_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    fake.events.add(
      platform.VideoEvent(
        eventType: platform.VideoEventType.initialized,
        duration: const Duration(seconds: 2),
        size: const Size(90, 160),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final video = find.byType(VideoPlayer);
    final size = tester.getSize(video);
    expect(size.width / size.height, closeTo(9 / 16, .001));
    expect(
      size.width,
      closeTo(264, .001),
      reason: 'Portrait artwork should use the available width on a tall phone',
    );
    expect(fake.calls, contains('play'));
    expect(fake.calls, contains('loop:true'));
    await tester.tap(video);
    await tester.pump();
    expect(fake.calls.last, 'pause');
    final close = find.text(l10n.commonClose);
    await tester.ensureVisible(close);
    await tester.pump();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'primary Home controls stay large and usable across compact height transitions',
    (tester) async {
      for (final pc in [false, true]) {
        for (final height in [220.0, 399.0, 400.0, 844.0]) {
          final l10n = await open(tester, pc: pc, height: height);
          for (final element in find.byType(FloatingActionButton).evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            final size = tester.getSize(find.byWidget(element.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(height));
          }
          final folder = find.byWidgetPredicate(
            (widget) =>
                widget is FloatingActionButton &&
                widget.heroTag == 'home-add-work-folder',
          );
          await tester.tap(folder);
          await tester.pumpAndSettle();
          expect(find.text(l10n.projectListNewFolderTitle), findsOneWidget);
          final cancel = find.text(l10n.commonCancel);
          await tester.ensureVisible(cancel);
          await tester.pumpAndSettle();
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: 'pc=$pc height=$height',
          );
        }
      }
    },
  );

  testWidgets('cached portrait GIF uses its dimensions on open and reopen', (
    tester,
  ) async {
    final l10n = await open(tester);
    final context = tester.element(find.byType(ExportedWorkCard).first);
    await tester.runAsync(() async {
      final dir = await ExportEngine.exportsDir();
      final file = File('${dir.path}/AUDIT_0_animation.gif');
      final image = img.Image(width: 90, height: 160);
      img.fill(image, color: img.ColorRgb8(35, 107, 69));
      await file.writeAsBytes(img.encodeGif(image));
      final provider = FileImage(file);
      await provider.evict();
      await precacheImage(provider, context);
    });
    await tester.pump();
    for (var attempt = 0; attempt < 2; attempt++) {
      final name = findExportedWorkName('AUDIT_0_animation.gif');
      await tester.ensureVisible(name);
      await tester.tap(name);
      await tester.pumpAndSettle();
      final image = find.descendant(
        of: find.byType(ExportedWorkPreviewLayout),
        matching: find.byType(Image),
      );
      final size = tester.getSize(image);
      expect(size.width, closeTo(264, .001));
      expect(size.height, closeTo(469.3333333333333, .001));
      expect(tester.takeException(), isNull);
      final close = find.text(l10n.commonClose);
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(ExportedWorkPreviewLayout), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
