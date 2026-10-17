import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/typing_aware_shortcuts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 入力欄に入力したままキャンバスへ描き始めたら、キーボードのフォーカスを
/// キャンバス画面へ戻す（戻さないと、画面のショートカットは入力中として
/// 無視され、Ctrl+Zは入力欄の文字の取り消しになる）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_focus_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('pressing the canvas ends text entry ($kind)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      ProjectService? ps;
      String? projectId;
      StateSetter? rebuild;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                ps ??= context.read<ProjectService>();
                rebuild = setState;
                return Column(
                  children: [
                    const Material(child: TextField()),
                    Expanded(
                      child: projectId == null
                          ? const SizedBox.expand()
                          : CanvasScreen(projectId: projectId),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final project = (await tester.runAsync(
        () => ps!.createProject(
          name: 'focus',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 320,
        ),
      ))!;
      projectId = project.id;
      rebuild!(() {});
      await tester.pump(const Duration(milliseconds: 1400));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(TypingAwareShortcuts.isTyping, isTrue);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CanvasArea)),
        kind: kind,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(TypingAwareShortcuts.isTyping, isFalse);
      // マウスで外を押すと入力欄は自分でフォーカスを手放すが、行き先は
      // 画面のスコープそのもので、画面のショートカットへは届かない。
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Canvas',
        reason: 'canvas shortcuts work again after drawing',
      );
    });
  }
}
