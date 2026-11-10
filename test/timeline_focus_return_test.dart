import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/typing_aware_shortcuts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// タイムラインの画面のショートカット（再生・コマ送り・取り消し等）は、
/// 入力欄に入力している間は動かず、入力を終えたら（Enter・欄の外の押下で
/// フォーカスが画面のスコープそのものへ落ちても）画面へ戻って効く。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'language': 'ja',
    });
    tempDir = Directory.systemTemp.createTempSync('niarim_timeline_focus_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('leaving a text field gives the keys back to the timeline', (
    tester,
  ) async {
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
                        : TimelineScreen(projectId: projectId),
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
        exportHeight: 180,
      ),
    ))!;
    projectId = project.id;
    rebuild!(() {});
    await tester.pump(const Duration(milliseconds: 1400));

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(TypingAwareShortcuts.isTyping, isTrue);

    // 欄から抜けると、Flutterはフォーカスを画面のスコープそのもの（画面の
    // ショートカットより上）へ落とす。画面のフォーカスへ戻す。
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await tester.pump();
    expect(TypingAwareShortcuts.isTyping, isFalse);
    expect(
      FocusManager.instance.primaryFocus,
      isNot(isA<FocusScopeNode>()),
      reason: 'focus must not stay on the page scope above the shortcuts',
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Timeline',
      reason: 'timeline shortcuts work again after typing',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
