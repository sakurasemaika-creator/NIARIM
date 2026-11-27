// 作品詳細の「総フレーム数」は実際のコマの数（全シーン）。
//
// 実際に使ってみたとき（2026-11-27）、25コマの作品で36と出ていた（fps×秒で、
// 秒はコマの数から切り上げていた）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_total_frames_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
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

  Future<({ProjectService service, String id})> open(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'コマ数',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
    });
    return (service: service, id: id);
  }

  testWidgets('the details show the real number of frames', (tester) async {
    final (service: projects, :id) = await open(tester);
    final scene = projects.scenesOf(id).first.id;
    projects.addFrame(id, scene);
    expect(projects.frameCount(id, scene), 13);
    expect(
      projects.projects.singleWhere((p) => p.id == id).totalFrames,
      24,
      reason: 'fps×seconds, with the seconds rounded up',
    );
    appRouter.go('/project/$id');
    await settleIo(tester, 4);
    final label = find.text(l10n.projectDetailInfoTotalFrames);
    await tester.ensureVisible(label);
    await tester.pump();
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.text('13')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
