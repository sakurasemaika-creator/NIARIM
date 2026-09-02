// 「保存した後」のセーブ画面が正しく描画できるかを検証する。
//
// ユーザー報告条件（プリセットサイズ1920x1080・レイヤー1枚・描画領域を
// 広げない・スロット1個目）で、実際のサムネイル生成を含む保存を完了させ、
// その後にセーブ画面を描画してレイアウト例外が出ないことを確かめる。
// 保存前（スロット空）と保存後（サムネイル・日時・操作ボタンが増える）で
// 行の構成が変わるため、保存後だけ描画が壊れる可能性を潰す狙い。
//
// 文字サイズは1.3倍のみを対象にしている。1.0倍・2.0倍でも単独実行では
// 数秒で通ることを確認済みだが、同一ファイル内でrunAsyncによる実際の
// ラスタライズ（サムネイル生成）を繰り返すとテスト環境側が詰まって
// タイムアウトするため、代表値1件に絞っている。全画面のレイアウト検証は
// text_scale_layout_test.dartが1.3倍・2.0倍で別途行っている。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('niarim_after_save');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  /// 画面側の_generateThumbnailと同じ手順でサムネイルPNGを作る。
  Future<Uint8List?> makeThumbnail(ProjectService ps, String projectId) async {
    final scenes = ps.scenesOf(projectId);
    final scene = scenes.first;
    final frame = scene.frames.first;
    final tm = ps.tileManagerOf(projectId);
    final w = tm.canvasWidth;
    final h = tm.canvasHeight;
    const thumbMax = 200;
    final scale = thumbMax / math.max(w, h);
    final tw = (w * scale).round().clamp(1, thumbMax);
    final th = (h * scale).round().clamp(1, thumbMax);
    final full = await LayerCompositor.composite(
      tm,
      ps.layersOf(projectId, scene.id, frame.index),
      (l) => ps.tileKeyFor(projectId, scene.id, frame.index, l.id),
      w,
      h,
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      full,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      ui.Paint(),
    );
    full.dispose();
    final thumb = await recorder.endRecording().toImage(tw, th);
    final bytes = await thumb.toByteData(format: ui.ImageByteFormat.png);
    thumb.dispose();
    return bytes?.buffer.asUint8List();
  }

  for (final scale in [1.3]) {
    testWidgets('保存後のセーブ画面が描画できる（文字$scale倍）',
        (WidgetTester tester) async {
      final problems = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        final s = d.toString();
        final loc =
            RegExp(r'file:///[^\s:]*/(lib/[^\s:]+:\d+:\d+)').firstMatch(s);
        final what = RegExp(r'(overflowed by [\d.]+ pixels on the \w+)')
                .firstMatch(s)?.group(1) ??
            s.split('\n').firstWhere((l) => l.contains('thrown'),
                orElse: () => '?');
        problems.add('${loc?.group(1) ?? "?"}: $what');
      };

      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MultiProvider(providers: providers!, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      final start = find.text('はじめる');
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start);
        await tester.pump(const Duration(milliseconds: 400));
      }

      final ctx = tester.element(find.byType(Navigator).first);
      final ps = ctx.read<ProjectService>();
      final sts = ctx.read<SaveTreeService>();
      final project = await tester.runAsync(() => ps.createProject(
            name: '動作確認',
            fps: 12,
            durationSeconds: 10,
            backgroundColor: 0xFFFFFFFF,
          ));
      await tester.pump(const Duration(milliseconds: 300));
      final pid = project!.id;

      // 保存ボタンが実行するのと同じ処理（サムネイル生成＋スロット保存）を
      // 本物の非同期として完了させる。
      final saved = await tester.runAsync(() async {
        final thumb = await makeThumbnail(ps, pid);
        await sts.saveToSlot(
          projectId: pid,
          slotIndex: 0,
          project: project,
          scenes: ps.scenesOf(pid),
          tileManager: ps.tileManagerOf(pid),
          comment: '動作確認',
          thumbnailPngBytes: thumb,
        );
        return sts.getNodes(pid);
      });
      expect(saved!.length, 1, reason: '保存できていない');
      final thumbPath = saved.first.thumbnailPath;
      expect(thumbPath, isNotNull, reason: 'サムネイルが作られていない');
      expect(File(thumbPath!).lengthSync(), greaterThan(0),
          reason: 'サムネイルが空ファイル');

      // 保存済みの状態でセーブ画面を描画する。
      problems.clear();
      appRouter.go('/save-tree/$pid');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // 「保存ボタンを押した瞬間、画面に何の要素も表示されなくなり、
      // アプリの再起動が必要になった」という報告に対応する確認。
      // ダイアログを閉じる際にNavigator.popが余分に呼ばれていると、
      // 画面そのものまで剥がれてナビゲーションスタックが空になり、
      // 「何も表示されない・戻る手段も無い」状態になる。開く前と閉じた後で
      // スタックの深さが一致することを確かめる。
      // 実際に描画されているScaffold・ダイアログの数で画面の重なりを測る。
      int screenCount() =>
          find.byType(Scaffold).evaluate().length +
          find.byType(AlertDialog).evaluate().length;

      final countBefore = screenCount();
      // 保存済みスロットをタップした先（操作シート）も開いてみる。
      final slots = find.byType(InkWell);
      if (slots.evaluate().isNotEmpty) {
        await tester.tap(slots.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
      }
      // 開いたシート／ダイアログを閉じる。
      if (find.text('キャンセル').evaluate().isNotEmpty) {
        await tester.tap(find.text('キャンセル').last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
      }
      final countAfter = screenCount();
      FlutterError.onError = original;

      expect(problems, isEmpty,
          reason: '保存後の描画で問題:\n${problems.join("\n")}');
      expect(countAfter, countBefore,
          reason: 'ダイアログを閉じた後に画面の数が変化している'
              '（Navigator.popが余分に呼ばれ、画面自体が剥がれた可能性）');
      expect(find.byType(Scaffold), findsWidgets,
          reason: '画面が1つも残っていない（何も表示されない状態）');
    }, timeout: const Timeout(Duration(seconds: 120)));
  }
}
