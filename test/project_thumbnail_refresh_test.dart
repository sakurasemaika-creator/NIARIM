import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一覧のサムネイルは、作り直すたびに別のファイルになる（画像はパスごとに
/// キャッシュされるので、同じ名前へ上書きすると一覧に古い絵が出続けた）。
/// 前のファイルは、複製した作品が使っていなければ消える。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_thumb_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({'first_launch': false});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('each thumbnail gets a new file; unused old ones go', (
    tester,
  ) async {
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const SizedBox()),
    );
    final service = tester
        .element(find.byType(SizedBox))
        .read<ProjectService>();
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'P',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      );
      String? thumb() =>
          service.projects.firstWhere((p) => p.id == project.id).thumbnailPath;

      await service.generateAndSaveThumbnail(project.id);
      final first = thumb()!;
      // 作り終えた時点で、保存されたデータも新しいサムネイルを指している
      // （前のファイルは保存し終えてから消す）。
      final saved = await NiaproSerializer.load(
        '${tempDir.path}/niarim/projects/${project.id}/${project.id}.niapro',
      );
      expect(saved.project.thumbnailPath, first);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await service.generateAndSaveThumbnail(project.id);
      final second = thumb()!;
      expect(second, isNot(first));
      expect(File(second).existsSync(), isTrue);
      expect(File(first).existsSync(), isFalse);

      // 複製した作品が同じサムネイルを使っている間は消さない。
      await service.duplicateProject(project.id);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await service.generateAndSaveThumbnail(project.id);
      expect(thumb(), isNot(second));
      expect(File(second).existsSync(), isTrue);
    });
  });
}
