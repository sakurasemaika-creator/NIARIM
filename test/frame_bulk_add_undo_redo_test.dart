import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

/// フレームの一括追加→取り消し→やり直し→取り消しの後も、今のコマは
/// ある範囲の中にあり、描いた線は今あるコマに入る（新しいコマは増えない）。
///
/// 以前は、やり直しで足したコマの1枚目へ移った今のコマが、その後の取り消しで
/// 範囲の外（帯の末尾の＋の上）に残り、描くと末尾の後ろに新しいコマができて
/// 線がそこに入った。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  testWidgets('bulk add, undo, redo, undo keeps the current frame in range', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final open = ValueNotifier<String?>(null);
    addTearDown(open.dispose);
    late ProjectService projects;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              projects = context.read<ProjectService>();
              return ValueListenableBuilder(
                valueListenable: open,
                builder: (_, id, _) => id == null
                    ? const SizedBox.expand()
                    : CanvasScreen(projectId: id),
              );
            },
          ),
        ),
      ),
    );
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'bulk add',
        exportWidth: 128,
        exportHeight: 96,
        fps: 12,
        durationSeconds: 10,
        backgroundColor: 0xFFFFFFFF,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    final before = projects.frameCount(project.id, sceneId);
    open.value = project.id;
    await pumpRealAsync(tester, const Duration(milliseconds: 500));

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();
    }

    int current() => tester
        .widget<FrameStripWidget>(find.byType(FrameStripWidget))
        .currentFrame;

    // Work on the last frame, as at the end of a cut.
    tester
        .widget<FrameStripWidget>(find.byType(FrameStripWidget))
        .onFrameSelected(before - 1);
    await tester.pump();
    await tester.pump();
    expect(current(), before - 1);

    // The bulk add of the frame strip (same command as its dialog).
    projects.editTimeline(project.id, 'bulk add', () {
      for (var i = 0; i < 2; i++) {
        projects.addFrame(project.id, sceneId);
      }
    }, changesTiles: false);
    await tester.pump();
    expect(projects.frameCount(project.id, sceneId), before + 2);

    await ctrl(LogicalKeyboardKey.keyZ);
    expect(projects.frameCount(project.id, sceneId), before);
    expect(current(), lessThan(before));
    await ctrl(LogicalKeyboardKey.keyY);
    expect(projects.frameCount(project.id, sceneId), before + 2);
    expect(current(), lessThan(before + 2));
    await ctrl(LogicalKeyboardKey.keyZ);
    expect(projects.frameCount(project.id, sceneId), before);
    expect(current(), lessThan(before), reason: 'the + cell is not a frame');
    // The "+" cell sits after the last frame, not under the current-frame
    // outline (it was left at its old place when the strip shrank).
    final outline = tester.getRect(
      find.byKey(const Key('canvasCurrentFrameOutline')),
    );
    final plus = tester.getRect(
      find.byKey(const ValueKey('frameStripAddCell')),
    );
    expect(plus.left, greaterThanOrEqualTo(outline.right - 1));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));

    // Drawing now goes into an existing frame.
    final area = tester.getRect(find.byType(CanvasArea));
    final gesture = await tester.startGesture(
      area.center,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(area.center + Offset(i * 8.0, i * 4.0));
      await pumpRealAsync(tester, const Duration(milliseconds: 30));
    }
    await gesture.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(projects.frameCount(project.id, sceneId), before);
    expect(current(), lessThan(before));
    expect(tester.takeException(), isNull);
    open.value = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
  });
}
