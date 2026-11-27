// 判断カードJ14の案内（所有者の判断、2026-11-27）。
//
// * U61 クリップを動かすには長押しが要るのに案内が無かった：初めてクリップを
//   押したときに吹き出しで知らせる。
// * U24 キャンバスを透過で表示している間は背景色が効かないのに、説明が無かった：
//   背景色の項目にそう書く（書き出しでは使う）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  Future<({ProjectService ps, String projectId, String sceneId})> openApp(
    WidgetTester tester, {
    List<String> seenTips = kAllFirstUseTooltipKeys,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: seenTips,
    });
    final directory = Directory.systemTemp.createTempSync('guidance-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'guidance',
        fps: 10,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    return (
      ps: ps,
      projectId: project.id,
      sceneId: ps.scenesOf(project.id).first.id,
    );
  }

  testWidgets('the first tap on a clip tells that a long press moves it', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId) = await openApp(
      tester,
      seenTips: [
        for (final key in kAllFirstUseTooltipKeys)
          if (key != 'timeline_clip_move') key,
      ],
    );
    ps.addAudioClip(
      projectId,
      sceneId,
      const AudioClip(id: 'a', label: 'a', startFrame: 0, lengthFrames: 10),
    );
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const ValueKey('timelineClip-a'))),
    )!;
    final clip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(clip);
    // The clip is wider than the screen: press near its start.
    final rect = tester.getRect(clip);
    await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text(l10n.timelineClipMoveTip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a transparent canvas says the background color is not shown', (
    tester,
  ) async {
    final (ps: _, :projectId, sceneId: _) = await openApp(tester);
    appRouter.go('/canvas/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;
    Future<void> openMenu() async {
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pumpAndSettle();
    }

    await openMenu();
    final toggle = find.text(l10n.canvasEditMenuBackgroundToggle);
    await tester.ensureVisible(toggle);
    expect(
      find.text(l10n.canvasBackgroundColorHiddenWhileTransparent),
      findsNothing,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await openMenu();
    final note = find.text(l10n.canvasBackgroundColorHiddenWhileTransparent);
    await tester.ensureVisible(note);
    expect(note, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
