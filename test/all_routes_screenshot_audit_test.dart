import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/community_service.dart';
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

  testWidgets('全主要ルートを本番Routerで巡回し実画面PNGとFlutter例外を監査する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FilePicker.platform = _FakeFilePicker();
    final tempDir = Directory.systemTemp.createTempSync('niarim_all_routes_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> loadFonts() async {
      await tester.runAsync(() async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest.listAssets();

        Future<void> loadFamily(String family, String needle) async {
          final matches = assets.where((a) => a.contains(needle)).toList();
          if (matches.isEmpty) return;
          final loader = FontLoader(family)
            ..addFont(rootBundle.load(matches.first));
          await loader.load();
        }

        Future<void> loadSdkMaterialIcons() async {
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
          loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
          loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
          loadFamily('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
          loadFamily('FontAwesomeSolid', 'fa-solid-900.ttf'),
          loadFamily('FontAwesomeRegular', 'fa-regular-400.ttf'),
          loadFamily('FontAwesomeBrands', 'fa-brands-400.ttf'),
          loadSdkMaterialIcons(),
        ]);
      });
    }

    Future<void> settleRoute({int maxRounds = 12}) async {
      for (var i = 0; i < maxRounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        if (i >= 2 &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
    }

    await loadFonts();
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settleRoute();

    final out = Directory('build/all-route-screenshots')
      ..createSync(recursive: true);
    final failures = <String>[];

    Future<void> capture(String name) async {
      await settleRoute();
      final exception = tester.takeException();
      if (exception != null) failures.add('$name: $exception');
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        failures.add('$name: root RepaintBoundary missing');
        return;
      }
      try {
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data?.buffer.asUint8List();
        });
        if (bytes == null || bytes!.isEmpty) {
          failures.add('$name: PNG capture empty');
        } else {
          await tester.runAsync(
            () => File('${out.path}/$name.png').writeAsBytes(bytes),
          );
        }
      } catch (e) {
        failures.add('$name: capture failed: $e');
      }
    }

    await capture('00_launch');

    final launchButton = find.byIcon(Icons.brush_outlined);
    if (launchButton.evaluate().isNotEmpty) {
      await tester.tap(launchButton.first);
      await settleRoute();
      final firstLaunch = find.text('はじめる');
      if (firstLaunch.evaluate().isNotEmpty) {
        await tester.tap(firstLaunch.first);
        await settleRoute();
      }
    } else {
      appRouter.go('/home');
      await settleRoute();
    }
    await capture('01_home');

    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final p = await tester.runAsync(
      () => ps.createProject(
        name: 'all-route-audit',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    );
    final project = p!;
    final community = context.read<CommunityService>();
    final workId = community.works.isEmpty ? null : community.works.first.id;

    final routes = <({String name, String route})>[
      (name: '02_new_project', route: '/new-project'),
      (name: '03_project_detail', route: '/project/${project.id}'),
      (name: '04_canvas', route: '/canvas/${project.id}'),
      (name: '05_timeline', route: '/timeline/${project.id}'),
      (name: '06_materials', route: '/materials/${project.id}'),
      (name: '07_export', route: '/export/${project.id}'),
      (name: '08_save_tree', route: '/save-tree/${project.id}'),
      (name: '09_autofill_presets', route: '/autofill-presets'),
      (name: '10_community', route: '/community'),
      if (workId != null)
        (name: '11_community_work', route: '/community/work/$workId'),
      (name: '12_premium', route: '/premium'),
      (name: '13_settings', route: '/settings'),
      (name: '14_settings_bucket', route: '/settings/bucket'),
      (name: '15_settings_fonts', route: '/settings/fonts'),
      (name: '16_settings_gestures', route: '/settings/gestures'),
      (name: '17_settings_license', route: '/settings/license'),
      (name: '18_settings_pen', route: '/settings/pen'),
      (name: '19_settings_performance', route: '/settings/performance'),
      (name: '20_settings_privacy', route: '/settings/privacy-policy'),
      (name: '21_settings_shortcuts', route: '/settings/shortcuts'),
      (name: '22_settings_theme', route: '/settings/theme'),
      (name: '23_settings_transfer', route: '/settings/transfer'),
      (name: '24_settings_watermark', route: '/settings/watermark'),
      (name: '25_settings_workspace', route: '/settings/workspace'),
      (name: '26_help', route: '/help'),
      (name: '27_tips', route: '/tips'),
      (name: '28_shared', route: '/shared'),
      (name: '29_storage', route: '/storage'),
      (name: '30_trash', route: '/trash'),
    ];

    for (final entry in routes) {
      try {
        appRouter.go(entry.route);
        await settleRoute();
        await capture(entry.name);
      } catch (e) {
        failures.add('${entry.name}: navigation failed: $e');
      }
    }

    final report = File('${out.path}/route_audit_failures.txt');
    await tester.runAsync(
      () => report.writeAsString(
        failures.isEmpty ? 'PASS\n' : failures.join('\n'),
      ),
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
