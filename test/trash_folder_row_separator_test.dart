import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// DISC100：ゴミ箱のフォルダの行は、中の作品名をその言語の区切りでつなぐ
/// （以前は「、」固定で、英語でも「Sea、Flower、Mountain」と出ていた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_trash_separator_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'en',
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

  Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a trash folder row joins the work names the way each language '
      'writes a list', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final splash = tester.element(find.byType(SplashScreen));
    final service = splash.read<ProjectService>();
    final settings = splash.read<SettingsService>();
    late final String folderId;
    await tester.runAsync(() async {
      final folder = await service.createFolder('Trip');
      folderId = folder.id;
      for (final name in ['Sea', 'Flower', 'Mountain']) {
        final work = await service.createProject(
          name: name,
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await service.moveToFolder(work.id, folder.id);
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      await service.moveFolderToTrash(folder.id);
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await settle(tester, rounds: 6);
    final row = find.byKey(ValueKey('trashedFolder_$folderId'));
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      await settle(tester, rounds: 2);
      // 日本語・中国語は「、」、ほかの言語は「, 」で並べる。
      final joined = [
        'Sea',
        'Flower',
        'Mountain',
      ].join(const {'ja': '、', 'zh': '、', 'zh_Hant': '、'}[code] ?? ', ');
      expect(
        find.descendant(of: row, matching: find.text(joined)),
        findsOneWidget,
        reason: code,
      );
      if (!const ['ja', 'zh', 'zh_Hant'].contains(code)) {
        expect(
          find.descendant(of: row, matching: find.textContaining('、')),
          findsNothing,
          reason: code,
        );
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
