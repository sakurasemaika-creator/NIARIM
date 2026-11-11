import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/widgets/project_thumbnail_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  testWidgets('Project thumbnail radio dialog has a functional frame player '
      'and persists the selected frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('niarim_project_thumb_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = ProjectService();
    await tester.runAsync(service.init);
    addTearDown(service.dispose);
    final project = await tester.runAsync(() => service.createProject(
      name: 'Thumbnail picker test', fps: 12, durationSeconds: 2,
      backgroundColor: 0xFFFFFFFF, exportWidth: 64, exportHeight: 64,
    ));
    expect(project, isNotNull);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      home: Scaffold(body: Builder(builder: (ctx) => TextButton(
        onPressed: () => showProjectThumbnailDialog(
          ctx, project: project!, service: service,
        ),
        child: const Text('Open picker'),
      ))),
    ));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('projectThumbnailLatest')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailFrame')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailCustom')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailNone')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailFramePanel')), findsNothing);

    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('projectThumbnailFramePanel')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailFramePreview')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailSeek')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailPreviousFrame')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailNextFrame')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailFirstFrame')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailLastFrame')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailPlayPause')), findsOneWidget);
    expect(find.byKey(const Key('projectThumbnailFrameCount')), findsOneWidget);

    final last = find.byKey(const Key('projectThumbnailLastFrame'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pump();
    final total = service.scenesOf(project!.id).first.frames.length;
    expect(find.text('現在のフレーム: $total / $total'), findsOneWidget);
    await tester.tap(find.byKey(const Key('projectThumbnailFirstFrame')));
    await tester.pump();
    expect(find.text('現在のフレーム: 1 / $total'), findsOneWidget);

    await tester.tap(find.byKey(const Key('projectThumbnailNone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('projectThumbnailFramePanel')), findsNothing);
    await tester.tap(find.byKey(const Key('projectThumbnailApply')));
    await tester.pumpAndSettle();
    expect(service.projects.single.thumbnailMode, 'none');
    expect(service.projects.single.thumbnailPath, isNull);

    final saved = await tester.runAsync(() => NiaproSerializer.load(
      '${dir.path}/niarim/projects/${project.id}/${project.id}.niapro',
    ));
    expect(saved!.project.thumbnailMode, 'none');
    expect(saved.project.thumbnailPath, isNull);
  });
}
