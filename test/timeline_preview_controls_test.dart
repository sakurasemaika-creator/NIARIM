import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// タイムラインのプレビュー欄：フレーム数（左下）・ループ（右下）・全画面
/// （右上）は、キャンバスの絵に重ねず、プレビュー欄の隅の絵の外に置く
/// （ユーザー指定）。縦長・横長・正方形の作品、スマホ・PCの画面、プレビュー欄
/// の高さのどの組み合わせでも、絵と重ならず画面からはみ出さない。
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
    'timelinePreviewLoopButton',
    'timelinePreviewFullscreenButton',
  ];

  Future<void> openTimeline(
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
  }

  void expectOutsidePicture(
    WidgetTester tester,
    String label,
    Size screen,
    List<String> keys,
  ) {
    expect(tester.takeException(), isNull, reason: label);
    final picture = tester.getRect(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    expect(picture.width, greaterThan(0), reason: label);
    for (final key in keys) {
      final finder = find.byKey(Key(key));
      expect(finder, findsOneWidget, reason: '$label $key');
      final rect = tester.getRect(finder);
      expect(
        rect.overlaps(picture),
        isFalse,
        reason: '$label $key $rect picture $picture',
      );
      expect(
        rect.left >= 0 && rect.right <= screen.width,
        isTrue,
        reason: '$label $key $rect',
      );
    }
    final count = tester.getRect(
      find.byKey(const Key('timelinePreviewFrameCount')),
    );
    final loop = tester.getRect(
      find.byKey(const Key('timelinePreviewLoopButton')),
    );
    // フレーム数は左下、ループは右下。
    expect(count.center.dx, lessThan(picture.center.dx), reason: label);
    expect(loop.center.dx, greaterThan(picture.center.dx), reason: label);
  }

  testWidgets(
    'the controls sit in the corners of the preview, off the picture',
    (tester) async {
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
            expectOutsidePicture(tester, label, screen.size, controls);
            final picture = tester.getRect(
              find.byKey(const Key('timelinePreviewPicture')),
            );
            final fullscreen = tester.getRect(
              find.byKey(const Key('timelinePreviewFullscreenButton')),
            );
            final loop = tester.getRect(
              find.byKey(const Key('timelinePreviewLoopButton')),
            );
            // 全画面は右上（低い欄ではループの左の同じ段）。
            if (loop.top - fullscreen.top > 1) {
              expect(
                fullscreen.top,
                lessThan(picture.center.dy),
                reason: label,
              );
            } else {
              expect(fullscreen.right, lessThanOrEqualTo(loop.left + 1));
            }
            expect(fullscreen.center.dx, greaterThan(picture.center.dx));
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the full-screen preview keeps them off the picture too', (
    tester,
  ) async {
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
      expectOutsidePicture(tester, 'fullscreen $shape', screen, const [
        'timelinePreviewFrameCount',
        'timelinePreviewLoopButton',
      ]);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
