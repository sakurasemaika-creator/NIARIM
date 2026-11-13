import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// Controls use the header/preview-band and resize-handle edges as anchors.
/// They need not avoid artwork and must never reserve space around the image.
void main() {
  const projects = {
    'portrait': Size(1080, 1920),
    'landscape': Size(1920, 1080),
    'square': Size(1080, 1080),
  };
  const screens = [
    (size: Size(390, 844), pc: false),
    (size: Size(320, 640), pc: false),
    (size: Size(1280, 800), pc: true),
  ];
  const controls = [
    'timelinePreviewFrameCount',
    'timelinePreviewFullscreenButton',
  ];

  Future<String> openTimeline(
    WidgetTester tester, {
    required Size project,
    required Size screen,
    required bool pc,
    required double fraction,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': pc ? 1 : 0,
      'timeline_preview_height_fraction': fraction,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-controls-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final created = await tester.runAsync(
      () => ps.createProject(
        name: 'preview-controls',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: project.width.toInt(),
        exportHeight: project.height.toInt(),
      ),
    );
    appRouter.go('/timeline/${created!.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return created.id;
  }

  void expectBandAnchors(
    WidgetTester tester,
    String label,
    Size screen,
    List<String> keys,
  ) {
    expect(tester.takeException(), isNull, reason: label);
    final picture = tester.getRect(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    final band = tester.getRect(find.byKey(const Key('timelinePreviewArea')));
    expect(picture.width, greaterThan(0), reason: label);
    for (final key in keys) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(
        rect.left >= 0 && rect.right <= screen.width + 1,
        isTrue,
        reason: '$label $key $rect',
      );
      if (key == 'timelinePreviewFullscreenButton') {
        expect(
          (rect.top - band.top).abs(),
          lessThanOrEqualTo(12),
          reason: '$label header edge',
        );
        expect(
          (rect.right - band.right).abs(),
          lessThanOrEqualTo(12),
          reason: '$label right edge',
        );
      } else {
        expect(
          (rect.left - band.left).abs(),
          lessThanOrEqualTo(12),
          reason: '$label frame count left',
        );
        expect(
          (rect.bottom - band.bottom).abs(),
          lessThanOrEqualTo(12),
          reason: '$label resize handle edge',
        );
      }
    }
    expect(find.byKey(const Key('timelinePreviewLoopButton')), findsNothing);
  }

  testWidgets('preview controls anchor to the band, not the canvas image', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final MapEntry(key: shape, value: project) in projects.entries) {
      for (final screen in screens) {
        for (final fraction in const [0.18, 0.42, 0.7]) {
          final label =
              '$shape ${screen.size.width.toInt()}x'
              '${screen.size.height.toInt()} $fraction';
          await openTimeline(
            tester,
            project: project,
            screen: screen.size,
            pc: screen.pc,
            fraction: fraction,
          );
          expectBandAnchors(tester, label, screen.size, controls);
          final fullscreen = tester.getRect(
            find.byKey(const Key('timelinePreviewFullscreenButton')),
          );
          final count = tester.getRect(
            find.byKey(const Key('timelinePreviewFrameCount')),
          );
          final band = tester.getRect(
            find.byKey(const Key('timelinePreviewArea')),
          );
          expect(fullscreen.top, closeTo(band.top + 8, 12), reason: label);
          expect(count.left, closeTo(band.left + 8, 12), reason: label);
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'fullscreen frame count anchors to the band; entry button disappears',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final MapEntry(key: shape, value: project) in projects.entries) {
        const screen = Size(390, 844);
        await openTimeline(
          tester,
          project: project,
          screen: screen,
          pc: false,
          fraction: 0.42,
        );
        await tester.tap(
          find.byKey(const Key('timelinePreviewFullscreenButton')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
        // 全画面の中には「全画面にする」ボタンを出さない。
        expect(
          find.byKey(const Key('timelinePreviewFullscreenButton')),
          findsNothing,
        );
        expectBandAnchors(tester, 'fullscreen $shape', screen, const [
          'timelinePreviewFrameCount',
        ]);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // プレビュー欄を一番大きくすると、横長の絵は画面の横幅いっぱい（欄の
  // 端からの8pxを除く）まで大きくなる。欄の高さの上限には、絵の上下の
  // フレーム数・全画面の段を足してある（足さないと絵が4分の3の幅で止まる）。
  testWidgets('the largest band lets a landscape picture span the width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screen = Size(390, 844);
    await openTimeline(
      tester,
      project: projects['landscape']!,
      screen: screen,
      pc: false,
      fraction: 1.0,
    );
    expectBandAnchors(tester, 'largest band', screen, controls);
    final picture = tester.getRect(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    expect(
      picture.width,
      greaterThanOrEqualTo(screen.width - 1),
      reason: '$picture',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // PC/DeXの全画面表示は画面いっぱいまで絵を大きくする（通常の欄の、
  // 横に間延びしないための幅900pxの上限は掛けない）。
  testWidgets('the full-screen preview on PC is not capped at 900px', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in const [Size(1920, 1080), Size(1280, 800)]) {
      await openTimeline(
        tester,
        project: projects['landscape']!,
        screen: screen,
        pc: true,
        fraction: 0.42,
      );
      await tester.tap(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      final label = 'pc fullscreen ${screen.width.toInt()}';
      expectBandAnchors(tester, label, screen, const [
        'timelinePreviewFrameCount',
      ]);
      final picture = tester.getRect(
        find.byKey(const Key('timelinePreviewPicture')),
      );
      final area = tester.getRect(find.byKey(const Key('timelinePreviewArea')));
      expect(picture.width, greaterThan(900), reason: '$label $picture');
      // 欄の高さか幅のどちらかいっぱいまで使う。
      expect(
        picture.height >= area.height - 1 || picture.width >= area.width - 1,
        isTrue,
        reason: '$label $picture in $area',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 全画面表示で「戻る」を押すと全画面を閉じるだけで、タイムラインからは
  // 出ない（キャンバスからgo()で来た、履歴が1枚だけのタイムラインでも、
  // ホームから積んだタイムラインでも）。全画面でないときの「戻る」は
  // そのまま前の画面へ戻る。
  testWidgets('Back closes the full-screen preview and stays on the timeline', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screen = Size(390, 844);
    String location() => appRouter.routerDelegate.currentConfiguration.uri.path;
    // Android 16以降の予測型「戻る」：Flutterが「戻る操作を受ける」とOSへ
    // 伝えていないと、OSは戻る操作をアプリへ渡さずにアプリを裏へ回す。
    // handlePopRouteはこの判断を通らないので、OSへ伝えた値を見る。
    final handlesBack = <bool>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handlesBack.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    Future<void> backFromFullscreen(String label) async {
      await tester.tap(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(handlesBack, isNotEmpty, reason: label);
      expect(handlesBack.last, isTrue, reason: '$label: predictive back');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: label);
      expect(find.byType(TimelineScreen), findsOneWidget, reason: label);
      expect(find.byIcon(Icons.fullscreen_exit), findsNothing, reason: label);
      expect(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
        findsOneWidget,
        reason: label,
      );
      expect(
        ModalRoute.of(tester.element(find.byType(TimelineScreen)))!.isCurrent,
        isTrue,
        reason: label,
      );
    }

    // キャンバスからと同じgo()で開いた（履歴が1枚だけの）タイムライン。
    final id = await openTimeline(
      tester,
      project: projects['landscape']!,
      screen: screen,
      pc: false,
      fraction: 0.42,
    );
    await backFromFullscreen('go');
    expect(location(), '/timeline/$id');

    // 全画面の上にダイアログ等が開いているときは、「戻る」はそれを閉じる
    // （全画面はそのまま）。
    await tester.tap(find.byKey(const Key('timelinePreviewFullscreenButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    showDialog<void>(
      context: tester.element(find.byType(TimelineScreen)),
      builder: (_) => const AlertDialog(content: Text('probe')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('probe'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('probe'), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
    expect(find.byType(TimelineScreen), findsOneWidget);

    // ホームから積んだタイムライン：全画面を閉じた後の「戻る」はホームへ。
    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    appRouter.push('/timeline/$id');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await backFromFullscreen('push');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TimelineScreen), findsNothing);
    expect(location(), '/home');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
