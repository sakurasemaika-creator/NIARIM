import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームの「新規フォルダ」のダイアログは、名前を打ってEnterを押せば作成
/// する（以前は「作成」を押したときだけで、Enterでは何も起きなかった）。
/// Enterを素早く2回押しても1つだけ作り、空白だけの名前では作らず、作れな
/// かったときは閉じずに理由を出し、打った名前を残す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_new_folder_enter_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProjectService> bootHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester
        .element(find.byType(SplashScreen))
        .read<ProjectService>();
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    return service;
  }

  Future<void> openNewFolderDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('追加').last);
    await settle(tester);
    await tester.tap(find.text('新規フォルダ').last);
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('Enter in the Home new-folder dialog creates the folder once', (
    tester,
  ) async {
    final service = await bootHome(tester);
    await openNewFolderDialog(tester);
    final field = find.byType(TextField);

    // 空白だけの名前では作らず、欄に打ち続けられる。
    await tester.enterText(field, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(service.folders, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
      reason: 'an Enter on a blank name must leave the typing in the field',
    );

    // Enterで作る。続けて2回押しても1つだけ。
    await tester.enterText(field, '  Enterで作る  ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await settle(tester);
    expect(service.folders.map((f) => f.name), ['Enterで作る']);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a folder that could not be created keeps the dialog, the name '
      'and the reason, and Enter tries again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    var attempts = 0;
    final names = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.themeData,
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateFolderNameDialog(context, (name) {
                attempts++;
                if (attempts == 1) {
                  return Future<void>.error(StateError('AUDIT save failure'));
                }
                names.add(name);
                return Future<void>.value();
              }),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    final l10n = AppLocalizations.of(tester.element(field))!;
    await tester.enterText(field, '旅行');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text(l10n.folderCreateFailed), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '旅行');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(names, ['旅行']);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter renames in the folder rename dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final names = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.themeData,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showRenameFolderNameDialog(context, 'Old', (name) async {
                    names.add(name);
                  }),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(names, ['New name']);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
