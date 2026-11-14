import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// キャンバス（スマホの表示）のシートの項目に、どの画面の大きさでも
/// 指のドラッグ・マウスのホイール・キーボードのTabでたどり着けること。
///
/// * 「設定/編集」のシート：412x860（実操作の大きさ）では12項目が816pxで
///   ちょうど収まり、スクロールするものが無い（一番下の「資料ウィンドウ」が
///   最後の項目。「キャンバスプレビュー」はPC/DeXの表示だけ）。低い画面・
///   横向き・大きな文字ではスクロールして一番下まで届く。
/// * 図形のシート（OFF・線・四角形・円）：スクロールしない列で並べていた
///   ので、横向きのスマホ（640x360、シートは高さの9/16＝約202px）では列が
///   はみ出し、「円」を選べなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_menu_reach_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openCanvas(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester, 4);
    final projects = tester
        .element(find.byType(Navigator).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'menus',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    appRouter.push('/canvas/${project.id}');
    await settle(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    final sheet = find.byType(BottomSheet);
    if (sheet.evaluate().isNotEmpty) {
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
    }
    appRouter.go('/home');
    await settle(tester, 2);
  }

  /// 画面の中に全部見えているか。
  bool fullyOnScreen(WidgetTester tester, Finder target, Size size) {
    final rect = tester.getRect(target);
    final sheet = tester.getRect(find.byType(BottomSheet));
    return rect.top >= sheet.top - 0.5 &&
        rect.top >= -0.5 &&
        rect.bottom <= size.height + 0.5 &&
        rect.bottom <= sheet.bottom + 0.5;
  }

  ScrollPosition sheetScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  for (final (label, size, scale) in const [
    ('412x860', Size(412, 860), 1.0),
    ('360x640', Size(360, 640), 1.0),
    ('360x440', Size(360, 440), 1.0),
    ('640x360 landscape', Size(640, 360), 1.0),
    ('412x860 text x2', Size(412, 860), 2.0),
  ]) {
    testWidgets('$label: every entry of the settings/edit sheet can be '
        'reached by drag, wheel and Tab', (tester) async {
      await openCanvas(tester, size, scale);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CanvasScreen)),
      )!;
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      final last = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l10n.canvasEditMenuReferenceWindow),
      );
      // スマホの表示では「資料ウィンドウ」が最後の項目。
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.canvasEditMenuPreviewNavigator),
        ),
        findsNothing,
      );
      final lastTile = find.ancestor(of: last, matching: find.byType(ListTile));
      final problems = <String>[];

      // 指のドラッグ。
      for (var i = 0; i < 12 && !fullyOnScreen(tester, lastTile, size); i++) {
        await tester.drag(
          find.byType(BottomSheet),
          const Offset(0, -120),
          kind: PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
      }
      if (!fullyOnScreen(tester, lastTile, size)) {
        problems.add('drag: ${tester.getRect(lastTile)}');
      }
      if (last.hitTestable().evaluate().isEmpty) {
        problems.add('drag: the last entry cannot be tapped');
      }

      // マウスのホイール（先頭へ戻してから）。
      sheetScroll(tester).jumpTo(0);
      await tester.pump();
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(BottomSheet))),
      );
      for (var i = 0; i < 12 && !fullyOnScreen(tester, lastTile, size); i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
        await tester.pumpAndSettle();
      }
      if (!fullyOnScreen(tester, lastTile, size)) {
        problems.add('wheel: ${tester.getRect(lastTile)}');
      }

      // キーボード（Tabで最後の項目まで）。
      sheetScroll(tester).jumpTo(0);
      await tester.pump();
      var reached = false;
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) continue;
        var onLast = false;
        if (find
            .descendant(
              of: find.byElementPredicate((e) => e == focused),
              matching: last,
            )
            .evaluate()
            .isNotEmpty) {
          onLast = true;
        }
        focused.visitAncestorElements((a) {
          if (a.widget == tester.widget(lastTile)) onLast = true;
          return !onLast;
        });
        if (onLast) {
          reached = true;
          break;
        }
      }
      if (!reached) {
        problems.add('Tab: focus never reached the last entry');
      } else if (!fullyOnScreen(tester, lastTile, size)) {
        problems.add(
          'Tab: the focused last entry ${tester.getRect(lastTile)} '
          'is not scrolled into view',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
      await closeSheet(tester);
    });
  }

  for (final (label, size, scale) in const [
    ('640x360 landscape', Size(640, 360), 1.0),
    ('360x640 text x2', Size(360, 640), 2.0),
  ]) {
    testWidgets('$label: the shape sheet scrolls and its last entry can be '
        'chosen', (tester) async {
      await openCanvas(tester, size, scale);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CanvasScreen)),
      )!;
      final shape = find.byTooltip(l10n.toolbarShapeTooltip);
      await tester.ensureVisible(shape.first);
      await tester.pumpAndSettle();
      await tester.tap(shape.first);
      // ツールのボタンはダブルタップ（短い説明）も受けるので、1回のタップは
      // ダブルタップの待ち時間の後に届く。
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      final overflow = tester.takeException();
      expect(overflow, isNull, reason: 'the shape sheet overflowed: $overflow');
      final circle = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l10n.canvasShapeCircle),
      );
      await tester.ensureVisible(circle);
      await tester.pumpAndSettle();
      expect(fullyOnScreen(tester, circle, size), isTrue);
      await tester.tap(circle);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await closeSheet(tester);
    });
  }
}
