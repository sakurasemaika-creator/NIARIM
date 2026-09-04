import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'timeline has no RenderFlex overflow at 320 logical pixels',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FilePicker.platform = _FakeFilePicker();
      final tempDir = Directory.systemTemp.createTempSync(
        'niarim_timeline_overflow_',
      );
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      tester.view.physicalSize = const Size(960, 1707);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest.listAssets();
        Future<void> family(String name, String needle) async {
          final matches = assets.where((a) => a.contains(needle)).toList();
          if (matches.isEmpty) return;
          final loader = FontLoader(name)
            ..addFont(rootBundle.load(matches.first));
          await loader.load();
        }

        Future<void> materialIcons() async {
          final flutterRoot = Platform.environment['FLUTTER_ROOT'];
          if (flutterRoot == null) return;
          final file = File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          );
          if (!file.existsSync()) return;
          final data = ByteData.sublistView(
            Uint8List.fromList(await file.readAsBytes()),
          );
          final loader = FontLoader('MaterialIcons')
            ..addFont(Future<ByteData>.value(data));
          await loader.load();
        }

        await Future.wait([
          family('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
          family('Kuramubon', 'assets/fonts/Kuramubon.otf'),
          family('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
          materialIcons(),
        ]);
      });

      appRouter.go('/');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      final context = tester.element(find.byType(MaterialApp).first);
      final ps = context.read<ProjectService>();
      final project = await tester.runAsync(
        () => ps.createProject(
          name: 'timeline-overflow-probe',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 180,
        ),
      );

      appRouter.go('/timeline/${project!.id}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Timeline must render without any Flutter layout/runtime exception at 320 logical px',
      );
      expect(find.text('timeline-overflow-probe'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
