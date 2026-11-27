// 演出フィルターの帯（所有者の判断、2026-11-27、全部入りの作品づくりの判断カード
// J18）：帯をドラッグで動かす・端で長さを変える・帯に名前。以前は帯を押すと
// シートが開くだけで、範囲はシートの数字でしか変えられず、帯に名前も無かった。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  for (final (layout, size, pc) in const [
    ('PC', Size(1280, 800), 1),
    ('phone', Size(390, 844), 0),
  ]) {
    testWidgets('$layout: an effect bar is named, moved and resized', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': pc,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final directory = Directory.systemTemp.createTempSync('effect-bar-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      tester.view.physicalSize = size;
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
          name: 'bars',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 90,
        ),
      ))!;
      final sceneId = ps.scenesOf(project.id).first.id;
      ps.addEffectFilter(
        project.id,
        sceneId,
        const EffectFilterInstance(
          id: 'fade',
          type: EffectFilterType.fade,
          startFrame: 1,
          endFrame: 3,
          name: 'Title fade',
        ),
      );
      appRouter.go('/timeline/${project.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      final undo = tester
          .element(find.byType(TimelineScreen))
          .read<UndoManager>();
      ({int start, int end}) range() {
        final e = ps
            .effectFiltersOf(project.id, sceneId)
            .singleWhere((f) => f.id == 'fade');
        return (start: e.startFrame, end: e.endFrame);
      }

      final bar = find.byKey(const ValueKey('timelineEffectBar-fade'));
      await tester.ensureVisible(bar);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('timelineEffectBarName-fade')),
            )
            .data,
        'Title fade',
      );
      // Three frames wide.
      final cellW = tester.getSize(bar).width / 3;

      // A long press, then a drag of two frames to the right, moves it.
      final move = await tester.startGesture(tester.getCenter(bar));
      await tester.pump(const Duration(milliseconds: 700));
      await move.moveBy(Offset(cellW, 0));
      await tester.pump();
      await move.moveBy(Offset(cellW, 0));
      await tester.pump();
      expect(range(), (start: 1, end: 3), reason: 'saved when it ends');
      await move.up();
      await tester.pumpAndSettle();
      expect(range(), (start: 3, end: 5));
      // One undo step puts it back.
      undo.undo();
      await tester.pumpAndSettle();
      expect(range(), (start: 1, end: 3));

      // The handles change the range: the end one shortens it, the start
      // one lengthens it to the left, and it can't pass the end. (Leftward,
      // away from the edge where the timeline scrolls along.)
      Future<void> dragEdge(String side, double dx) async {
        await tester.timedDrag(
          find.byKey(ValueKey('timelineEffectBarEdge-$side-fade')),
          Offset(dx, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
      }

      await dragEdge('end', -cellW);
      expect(range(), (start: 1, end: 2));
      await dragEdge('start', -cellW);
      expect(range(), (start: 0, end: 2));
      await dragEdge('start', cellW * 6);
      expect(range(), (start: 2, end: 2));
      // Each drag was one undo step.
      undo.undo();
      await tester.pumpAndSettle();
      expect(range(), (start: 0, end: 2));

      // A tap still opens the effect sheet.
      await tester.tap(bar);
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
