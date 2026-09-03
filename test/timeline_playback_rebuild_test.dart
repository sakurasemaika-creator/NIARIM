// タイムライン再生が「プレビューだけを更新し、画面全体を作り直さない」ことを
// 検証する。
//
// 再生タイマーはfps間隔（24fpsなら約41ms）で再生位置を進める。以前はこれを
// setStateで行っていたため、8,000行規模のタイムライン画面のウィジェット
// ツリー全体（フレーム一覧・各トラック・シーンタブ・ツールバー）を毎秒24〜60回
// 作り直していた。再生位置をValueNotifierにし、追従が要るプレビューと
// シークバーだけをValueListenableBuilderで購読する形へ変えた。
//
// 「作り直していない」ことは、外側のbuildで作られるウィジェットの
// **インスタンス同一性**で判定できる。buildが再実行されればそのウィジェットは
// 新しいインスタンスに差し替わるため、identicalが偽になる。
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('niarim_playback');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  /// プライベートクラスなので型名の文字列で探す。
  Finder byTypeName(String name) =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

  /// プレビューが今表示しているフレーム番号。
  int previewFrameOf(WidgetTester tester) {
    final w = tester.widget(byTypeName('_TimelinePreview'));
    // ignore: avoid_dynamic_calls
    return (w as dynamic).frameIndex as int;
  }

  testWidgets('再生でプレビューは進むが、画面全体は作り直されない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final ctx = tester.element(find.byType(Navigator).first);
    final ps = ctx.read<ProjectService>();
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'playback',
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    final pid = project!.id;

    appRouter.go('/timeline/$pid');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      byTypeName('_TimelinePreview'),
      findsOneWidget,
      reason: 'タイムラインのプレビューが出ていない',
    );
    expect(previewFrameOf(tester), 0);

    // 再生開始。play_arrowのタップ自体は setState(_isPlaying = true) を伴う
    // ため、外側ツリーの同一性はここで一度切れる。計測はその後で行う。
    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsWidgets, reason: '再生が始まっていない');

    // 外側のbuildで作られるウィジェットを1つ押さえておく。フレーム一覧の
    // リストは再生位置に依存しないので、再生タイマーが進むだけで作り直されて
    // はいけない。
    final frameListBefore = tester.widget(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(ListView),
          )
          .first,
    );
    final frameBefore = previewFrameOf(tester);

    // fps=12なので約83msごとに1フレーム進む。3フレームぶん進める。
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      previewFrameOf(tester),
      greaterThan(frameBefore),
      reason:
          '再生してもプレビューのフレームが進んでいない'
          '（ValueListenableBuilderで購読できていない）',
    );

    final frameListAfter = tester.widget(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(ListView),
          )
          .first,
    );
    expect(
      identical(frameListBefore, frameListAfter),
      isTrue,
      reason:
          '再生中に画面全体が作り直されている'
          '（再生タイマーがsetStateを呼ぶ実装に戻っている）',
    );

    // 止めて後始末（テスト終了時にタイマーが生き残らないようにする）。
    await tester.tap(find.byIcon(Icons.pause).first);
    await tester.pump();
  });

  testWidgets('コマ送り・シーク操作では従来どおり画面が更新される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final ctx = tester.element(find.byType(Navigator).first);
    final ps = ctx.read<ProjectService>();
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'step',
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    appRouter.go('/timeline/${project!.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(previewFrameOf(tester), 0);

    // 次のコマへ送る（setState経路。getter/setter化で壊れていないことの確認）。
    await tester.tap(find.byIcon(Icons.fast_forward).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(previewFrameOf(tester), 1, reason: 'コマ送りでフレームが進んでいない');

    await tester.tap(find.byIcon(Icons.fast_rewind).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(previewFrameOf(tester), 0, reason: 'コマ戻しでフレームが戻っていない');
  });
}
