import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// タイムラインの︙→「フレームを画像で書き出す」で保存したら、保存した
/// ファイル名の知らせが出て、作品一覧を開く操作がある（DISC353：保存は
/// できるのに画面には何も出なかった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

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

  for (final (name, size, pc) in [
    ('PC 1280x800', const Size(1280, 800), true),
    ('phone 390x844', const Size(390, 844), false),
  ]) {
    testWidgets('$name: フレームを画像で書き出すと保存したファイル名の知らせが出る', (tester) async {
      tempDir = Directory.systemTemp.createTempSync('niarim_frame_notice_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
      appRouter.go('/home');
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': pc ? 1 : 0,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await settle(tester, 4);
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      late String id;
      await tester.runAsync(() async {
        final project = await service.createProject(
          name: 'コマの書き出し',
          fps: 4,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 90,
        );
        id = project.id;
      });
      appRouter.push('/timeline/$id');
      await settle(tester, 12);

      await tester.tap(find.byKey(const ValueKey('timelineMoreMenu')));
      await settle(tester, 3);
      // メニューの最後の項目。メニューが画面より長いと隠れている。
      final item = find.text('フレームを画像で書き出す').last;
      await tester.ensureVisible(item);
      await settle(tester, 2);
      await tester.tap(item);
      await settle(tester, 3);
      await tester.tap(find.text('PNGで保存'));
      // 書き出し（合成・PNGの書き込み）は本物の非同期処理。
      for (var i = 0; i < 30; i++) {
        await settle(tester, 1);
        if (find.byType(SnackBar).evaluate().isNotEmpty) break;
      }
      final exports = Directory('${tempDir.path}/niarim/exports');
      final written = exports.existsSync()
          ? exports
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.png'))
                .toList()
          : const <File>[];
      expect(written, hasLength(1), reason: 'the frame PNG is written');
      final fileName = written.single.uri.pathSegments.last;
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining(fileName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
