import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// キャンバスの画面全体のショートカットは、入力欄で打っている間は効かず
/// （色のコード欄でCtrl+Zを押してもキャンバスの線を取り消さない）、
/// Enterで入力を終えたら画面へ戻って効く。画面全体を素の
/// CallbackShortcutsで包むと入力欄より先にキーを取ってしまう。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_keys_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      // 色のパネルがドックに開いたままの作業画面で確かめる。
      'force_pc_mode': 1,
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pressCtrlZ(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleIo(tester, 2);
  }

  testWidgets('Ctrl+Z while typing in the colour code is not canvas undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final undo = home.read<app_undo.UndoManager>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'キー',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    appRouter.push('/canvas/$id');
    await settleIo(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(find.byType(ColorPickerPanel), findsOneWidget);

    // 1本の線を描く（取り消せるものを作る）。
    final area = tester.getRect(find.byType(CanvasArea));
    final stroke = await tester.startGesture(
      area.center - const Offset(40, 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    for (var dx = -30.0; dx <= 40; dx += 10) {
      await stroke.moveTo(area.center + Offset(dx, 0));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await stroke.up();
    await settleIo(tester, 4);
    expect(undo.canUndo, isTrue, reason: 'a stroke was drawn');

    // ドックの色のパネルの色のコード欄で打つ。
    final field = find
        .descendant(
          of: find.byType(ColorPickerPanel),
          matching: find.byType(TextField),
        )
        .first;
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'ff0000');
    await tester.pump();

    await pressCtrlZ(tester);
    expect(
      undo.canUndo,
      isTrue,
      reason: 'Ctrl+Z while typing must not undo the stroke on the canvas',
    );

    // Enterで入力を終えたら、フォーカスは画面へ戻り、Ctrl+Zはキャンバスの
    // 取り消しになる。
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleIo(tester, 2);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Canvas');
    await pressCtrlZ(tester);
    expect(undo.canUndo, isFalse, reason: 'after Enter, Ctrl+Z is canvas undo');
    expect(tester.takeException(), isNull);
  });
}
