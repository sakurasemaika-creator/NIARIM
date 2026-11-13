import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

// 表示サイズを選んでいないホームは、窓の幅で大・中・小を決める（600px・
// 1000pxが境）。窓の幅を変えて境をまたいでも、作品の一覧は読んでいた所に
// 留まる（先頭へ戻らない）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProjectService> openHome(
    WidgetTester tester, {
    required Size size,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    final directory = Directory.systemTemp.createTempSync('home-resize-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final service = tester
        .element(find.byType(ProjectListWidget))
        .read<ProjectService>();
    await tester.runAsync(() async {
      for (var index = 1; index <= 60; index++) {
        await service.createProject(
          name: 'カット${index.toString().padLeft(2, '0')}',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 32,
          exportHeight: 32,
        );
      }
    });
    await tester.pumpAndSettle();
    return service;
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  Future<void> resize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    await tester.pumpAndSettle();
  }

  testWidgets('the project list keeps its place when the window crosses a '
      'size class with no view size chosen', (tester) async {
    await openHome(tester, size: const Size(560, 844));
    for (final (from, to) in const [
      (560.0, 590.0), // 同じ区分の中
      (560.0, 640.0), // 600pxをまたいで広げる
      (640.0, 560.0), // 600pxをまたいで狭める
      (980.0, 1020.0), // 1000pxをまたいで広げる
      (1020.0, 980.0), // 1000pxをまたいで狭める
    ]) {
      await resize(tester, from);
      position(tester).jumpTo(0);
      await tester.pumpAndSettle();
      position(tester).jumpTo(300);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, 300, reason: '$from: scrolled');
      await resize(tester, to);
      // 列の数が変わって一覧が短くなったときは、その端まで。
      final kept = math.min(300.0, position(tester).maxScrollExtent);
      expect(kept, greaterThan(100), reason: '$from -> $to: list too short');
      expect(
        position(tester).pixels,
        closeTo(kept, 1),
        reason: '$from -> $to: the list jumped',
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 窓の幅で表示サイズが変わった後に、いま出ている表示サイズを選んでも、
  // 並びは変わらないので一覧はその場に留まる（先頭へ戻っていた）。
  for (final (open, now, chosen) in const [
    (560.0, 640.0, ProjectViewMode.medium), // 開いた後に600pxをまたいで広げた
    (1020.0, 560.0, ProjectViewMode.small), // 開いた後に1000pxと600pxをまたいだ
  ]) {
    testWidgets('choosing the view size already shown after the window '
        'crossed a size class keeps the place ($open -> $now)', (tester) async {
      await openHome(tester, size: Size(open, 844));
      await resize(tester, now);
      position(tester).jumpTo(300);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, 300);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectListWidget)),
      )!;
      await tester.tap(find.byTooltip(l10n.homeViewModeTooltip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(switch (chosen) {
          ProjectViewMode.large => l10n.homeViewModeLarge,
          ProjectViewMode.medium => l10n.homeViewModeMedium,
          ProjectViewMode.small => l10n.homeViewModeSmall,
          ProjectViewMode.detail => l10n.homeViewModeDetail,
        }).last,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProjectListWidget>(find.byType(ProjectListWidget))
            .viewMode,
        chosen,
        reason: 'the list shows the size that was already shown',
      );
      expect(
        position(tester).pixels,
        closeTo(300, 1),
        reason: 'choosing the size already shown moved the list',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  Future<void> pick(WidgetTester tester, ProjectViewMode chosen) async {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectListWidget)),
    )!;
    await tester.tap(find.byTooltip(l10n.homeViewModeTooltip));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(switch (chosen) {
        ProjectViewMode.large => l10n.homeViewModeLarge,
        ProjectViewMode.medium => l10n.homeViewModeMedium,
        ProjectViewMode.small => l10n.homeViewModeSmall,
        ProjectViewMode.detail => l10n.homeViewModeDetail,
      }).last,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProjectListWidget>(find.byType(ProjectListWidget)).viewMode,
      chosen,
    );
  }

  Future<void> scrollTo(WidgetTester tester, double pixels) async {
    position(tester).jumpTo(pixels);
    await tester.pumpAndSettle();
    expect(position(tester).pixels, pixels);
  }

  // いま出ている表示サイズを選んだ後は、その表示サイズの位置として覚える。
  // 別の表示サイズへ移って戻ると、その表示サイズで読んでいた所に戻る
  // （開いたときの表示サイズの位置として覚えていたので、先頭へ戻っていた）。
  for (final (open, now, shown) in const [
    (560.0, 640.0, ProjectViewMode.medium),
    (1020.0, 560.0, ProjectViewMode.small),
  ]) {
    testWidgets('the view size already shown remembers its own place after '
        'another size ($open -> $now)', (tester) async {
      await openHome(tester, size: Size(open, 844));
      await resize(tester, now);
      await pick(tester, shown);
      await scrollTo(tester, 500);
      await pick(tester, ProjectViewMode.detail);
      expect(position(tester).pixels, 0, reason: 'detail starts at the top');
      await scrollTo(tester, 120);
      await pick(tester, shown);
      expect(
        position(tester).pixels,
        closeTo(500, 1),
        reason: 'coming back to $shown lost its place',
      );
      await pick(tester, ProjectViewMode.detail);
      expect(position(tester).pixels, closeTo(120, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 開いたときの表示サイズは、窓の幅が変わる前に読んでいた所を覚えている。
  // いま出ている表示サイズを選んで読み進めた後でも、その表示サイズへ移ると
  // 自分の位置に戻り、元の表示サイズへ戻ると読み進めた所に戻る。
  for (final (open, now, shown, atOpen) in const [
    (560.0, 640.0, ProjectViewMode.medium, ProjectViewMode.small),
    (1020.0, 560.0, ProjectViewMode.small, ProjectViewMode.large),
  ]) {
    testWidgets('the size shown at opening keeps its own place after the '
        'size now shown was chosen ($open -> $now)', (tester) async {
      await openHome(tester, size: Size(open, 844));
      await scrollTo(tester, 300);
      await resize(tester, now);
      expect(position(tester).pixels, closeTo(300, 1));
      await pick(tester, shown);
      expect(
        position(tester).pixels,
        closeTo(300, 1),
        reason: 'choosing the size already shown moved the list',
      );
      // 選んだ後にまだ動かしていなくても、その位置を覚えている。
      await pick(tester, ProjectViewMode.detail);
      await pick(tester, shown);
      expect(
        position(tester).pixels,
        closeTo(300, 1),
        reason: '$shown forgot the place it was chosen at',
      );
      await scrollTo(tester, 500);
      await pick(tester, atOpen);
      expect(
        position(tester).pixels,
        closeTo(math.min(300.0, position(tester).maxScrollExtent), 1),
        reason: '$atOpen did not come back to its own place',
      );
      await pick(tester, shown);
      expect(
        position(tester).pixels,
        closeTo(500, 1),
        reason: 'coming back to $shown lost its place',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 表示サイズを自分で選んだときは、これまでどおりサイズごとに別の位置を
  // 覚える（窓の幅では変わらない）。
  testWidgets('a chosen view size keeps its place across the same widths', (
    tester,
  ) async {
    await openHome(
      tester,
      size: const Size(560, 844),
      prefs: {'home.projectViewMode.v1': 'small'},
    );
    position(tester).jumpTo(300);
    await tester.pumpAndSettle();
    await resize(tester, 640);
    expect(position(tester).pixels, closeTo(300, 1));
    await resize(tester, 1020);
    expect(
      position(tester).pixels,
      closeTo(math.min(300.0, position(tester).maxScrollExtent), 1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
