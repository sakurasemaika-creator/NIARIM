import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shared-paste-flow-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'home_view_mode': 'medium',
    });
    appRouter.go('/');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpIo(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 35)));
      await tester.pump(const Duration(milliseconds: 75));
    }
  }

  testWidgets('received folder clipboard moves to Trash and restores with confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester.element(find.byType(SplashScreen))
        .read<ProjectService>();
    late String folderId;
    await tester.runAsync(() async {
      final folder = await service.createSharedFolder('受信箱');
      folderId = folder.id;
      final work = await service.importSharedProject(NiaproData(
        project: Project(
          id: 'source', name: '元の作品', fps: 1, durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64, exportHeight: 64,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          totalWorkSeconds: 0,
        ),
        scenes: const [], tileData: const {},
      ));
      await service.saveProject(work.id);
      await service.moveToSharedFolder(work.id, folderId);
    });

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await pumpIo(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await pumpIo(tester);

    await tester.longPress(find.text('受信箱').first);
    await tester.pump();
    await tester.tap(find.widgetWithIcon(ListTile, Icons.content_copy));
    await pumpIo(tester);
    expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await pumpIo(tester);
    await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
    await tester.pump();
    expect(find.byKey(const Key('homePasteToTrashDialog')), findsOneWidget);
    expect(service.sharedFolders.single.id, folderId);
    await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
    await pumpIo(tester);
    expect(service.sharedFolders, isEmpty);
    expect(service.trashedFolders.single.isShared, isTrue);
    expect(service.trashedFolders.single.projectIds, hasLength(1));

    await tester.tap(find.byKey(ValueKey('trashCopyFolder_$folderId')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await pumpIo(tester);
    await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
    await tester.pump();
    expect(find.byKey(const Key('homePasteRestoreDialog')), findsOneWidget);
    expect(service.shared, isEmpty);
    await tester.tap(find.byKey(const Key('homePasteRestoreConfirmButton')));
    await pumpIo(tester);
    expect(service.trashedFolders, isEmpty);
    expect(service.sharedFolders.single.id, folderId);
    expect(service.shared.single.sharedFolderId, folderId);
    expect(service.shared.single.name, '元の作品');
    expect(service.trash, isEmpty);
  });
}
