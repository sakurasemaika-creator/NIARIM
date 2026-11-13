import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// キャンバス下部のフレーム一覧（[FrameStripWidget]）の独自ジェスチャーを
/// 検証する。
///
/// 28章では長く「タップで現在地が移動するか」「スワイプ後に中央の現在
/// フレーム枠へ自動吸着するか」を**実機でしか確認できない項目**として
/// 挙げていたが、どちらもウィジェットテストで駆動・検証できる：
/// - タップ →`onFrameSelected`へ渡るindex
/// - ドラッグして離す →`ScrollEndNotification`を受けた
///   `_handleScrollEnd`が最寄りのコマへ吸着し、そのindexを通知する
/// - `currentFrame`が変わったとき →`_scrollToCurrent`がそのコマを
///   ビューポート中央へ寄せる
///
/// 実機でしか分からないのは「指の感触」だけで、上記の配線・計算は
/// ここで機械的に守れる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// フレーム一覧のコマ幅。
  ///
  /// **実装のソースから読む**。ここへ数値を直書きすると、コマ幅を変えた
  /// ときにテストだけが古い値のまま落ちる（実際に上流の
  /// 「ui: standardize canvas frame cells at 50x50」で48→50へ変わり、
  /// 192を期待して200が返る形で落ちた）。吸着の計算はコマ幅に比例するので、
  /// 値そのものではなく「コマ幅の整数倍に吸着すること」を検証したい。
  final itemExtent = double.parse(
    RegExp(r'static const double _itemExtent = ([0-9.]+)')
        .firstMatch(
          File(
            'lib/screens/canvas/widgets/frame_strip_widget.dart',
          ).readAsStringSync(),
        )!
        .group(1)!,
  );

  /// path_providerのモック（ProjectServiceが保存でディスクを触るため）。
  void mockPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('niarim_frame_strip_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
  }

  /// フレーム一覧だけを載せた最小の画面を組み立てる。
  /// [selected]には`onFrameSelected`で通知されたindexが積まれる。
  ///
  /// 画面幅を広く取っているのは、`SliverMultiBoxAdaptorElement`が
  /// **描画範囲内の子だけ**をonstage扱いにするため（キャッシュ範囲に
  /// あるだけのコマは`find.byKey`から見えない）。全コマと末尾の
  /// 「＋」セルが同時に描画される幅にしておく。
  Future<({String projectId, String sceneId, List<int> selected})> pumpStrip(
    WidgetTester tester, {
    int frameCount = 10,
    int currentFrame = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    tester.view.physicalSize = const Size(1400, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    final selected = <int>[];

    // まずProviderだけを立ち上げ、そのcontextからProjectServiceを取って
    // テスト用プロジェクト（＝フレーム）を作る。フレーム一覧はフレーム数を
    // Serviceから読むため、先に用意しておく必要がある。
    // なお`MultiProvider`自身のElementは、それが差し込むProviderより
    // **上**にいるため`context.read`が失敗する。必ず子孫のcontextを使う。
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const SizedBox.shrink()),
    );
    final ps = tester.element(find.byType(SizedBox)).read<ProjectService>();
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'frame-strip-test',
        // fps×秒数がフレーム数になる。
        fps: frameCount,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    final projectId = project!.id;
    final sceneId = ps.scenesOf(projectId).first.id;

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: _StripHost(
                projectId: projectId,
                sceneId: sceneId,
                initialFrame: currentFrame,
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    return (projectId: projectId, sceneId: sceneId, selected: selected);
  }

  /// フレーム一覧のスクロール位置（`_scrollController.offset`相当）。
  double stripOffset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('コマをタップすると、そのコマのindexが現在フレームとして通知される', (tester) async {
    final ctx = await pumpStrip(tester, frameCount: 10);

    // 先頭が中央に来ている状態から、右隣（index 1）をタップする。
    final cell1 = find.byKey(const ValueKey('frameStripCell1'));
    expect(cell1, findsOneWidget);
    await tester.tap(cell1);
    await tester.pump();

    expect(ctx.selected, [1]);
  });

  testWidgets('現在フレームが変わると、そのコマがビューポート中央へ寄る（吸着表示）', (tester) async {
    await pumpStrip(tester, frameCount: 10);
    expect(stripOffset(tester), 0.0, reason: '先頭フレームでは左端（＝中央寄せ）');

    // index 4 をタップ → _StripHostがcurrentFrameを更新 →
    // didUpdateWidget経由で_scrollToCurrent(animate: true)が走る。
    await tester.tap(find.byKey(const ValueKey('frameStripCell4')));
    // `animateTo`はポストフレームコールバックで始まるため、最初のpumpは
    // Tickerの開始時刻を決めるだけで値が動かない。pumpAndSettleで
    // アニメーションを終端まで進める。
    await tester.pumpAndSettle();

    expect(stripOffset(tester), closeTo(4 * itemExtent, 0.5));
  });

  testWidgets('スワイプして離すと、最寄りのコマへ吸着してそのindexが通知される', (tester) async {
    final ctx = await pumpStrip(tester, frameCount: 10);
    expect(stripOffset(tester), 0.0);

    // 指を離す位置をコマ境界からわざと外す。実際にどれだけ動いたかは
    // タッチスロップの扱いで変わるので、「離した時点の位置」を読んでから
    // 期待値を組み立てる（＝吸着の計算そのものを検証する）。
    // 最初の1回はタッチスロップの消化に使われ、スクロールへは効かない
    // （`DragStartBehavior.start`が受理時点を起点に取り直すため）ので、
    // スロップ用と本番用の2回に分けて動かす。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FrameStripWidget)),
    );
    await gesture.moveBy(const Offset(-kDragSlopDefault, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-125, 0));
    await tester.pump();
    final released = stripOffset(tester);
    expect(
      released % itemExtent,
      isNot(closeTo(0, 1)),
      reason: '中途半端な位置で離さないと吸着を検証できない',
    );
    final expectedIndex = (released / itemExtent).round();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ctx.selected, isNotEmpty, reason: 'ドラッグ後に離した時点で最寄りのコマが通知されるはず');
    expect(ctx.selected.last, expectedIndex);
    // 通知を受けた側がcurrentFrameを更新した結果、位置もそのコマへ揃う。
    expect(stripOffset(tester), closeTo(expectedIndex * itemExtent, 0.5));
  });

  testWidgets('末尾の「＋」セルをタップするとフレームが1コマ増える', (tester) async {
    final ctx = await pumpStrip(tester, frameCount: 6);
    final ps = tester
        .element(find.byType(FrameStripWidget))
        .read<ProjectService>();
    final before = ps.frameCount(ctx.projectId, ctx.sceneId);

    final addCell = find.byKey(const ValueKey('frameStripAddCell'));
    expect(addCell, findsOneWidget);
    await tester.tap(addCell);
    await tester.pump();

    expect(ps.frameCount(ctx.projectId, ctx.sceneId), before + 1);
  });
}

/// `currentFrame`を保持して[FrameStripWidget]へ渡すだけのホスト。
/// 実際のキャンバス画面と同じく「通知を受けたら現在フレームを更新する」
/// 側の振る舞いを再現する（これが無いと吸着後の位置合わせが起きない）。
class _StripHost extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int initialFrame;
  final ValueChanged<int> onSelected;
  const _StripHost({
    required this.projectId,
    required this.sceneId,
    required this.initialFrame,
    required this.onSelected,
  });

  @override
  State<_StripHost> createState() => _StripHostState();
}

class _StripHostState extends State<_StripHost> {
  late int _current = widget.initialFrame;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1400,
      child: FrameStripWidget(
        currentFrame: _current,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        onFrameSelected: (index) {
          widget.onSelected(index);
          setState(() => _current = index);
        },
        onTimelineTap: () {},
      ),
    );
  }
}
