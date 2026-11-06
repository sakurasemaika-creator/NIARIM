import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';

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

/// Drawerを開いたテストと描画ツリーを共有せず、完全に新しいWidgetツリーで
/// 「作品一覧」タブを撮影する。Overlay/Drawerの直前フレームがroot
/// RepaintBoundaryへ残るテスト環境固有の問題を避けるための独立確認。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('作品一覧を新しいWidgetツリーから撮影できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FilePicker.platform = _FakeFilePicker();
    appRouter.go('/home');

    final tempDir = Directory.systemTemp.createTempSync('niarim_clean_home_');
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final hakkou = FontLoader('HakkouMincho')
        ..addFont(rootBundle.load('assets/fonts/HakkouMincho.ttf'));
      final kuramubon = FontLoader('Kuramubon')
        ..addFont(rootBundle.load('assets/fonts/Kuramubon.otf'));
      final noto = FontLoader('NotoSerifJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
      await Future.wait([hakkou.load(), kuramubon.load(), noto.load()]);
    });

    final screenshotKey = GlobalKey();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final firstLaunch = find.text('はじめる');
    if (firstLaunch.evaluate().isNotEmpty) {
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 700));
    }

    // 同じ文言がOffstage側にも存在し得るため、実際にhit test可能なタブだけを押す。
    final worksTab = find.text('作品一覧').hitTestable();
    expect(worksTab, findsOneWidget);
    await tester.tap(worksTab);
    await tester.pump(const Duration(milliseconds: 700));

    // この独立テストではDrawerを一度も開いていないため、Drawerの描画要素が
    // 現在のWidgetツリーに存在しないことを確認してから画像化する。
    expect(find.byType(Drawer), findsNothing);

    final exception = tester.takeException();
    expect(exception, isNull, reason: '作品一覧表示でFlutter例外/overflow');

    await tester.pump(const Duration(milliseconds: 120));
    final boundary =
        screenshotKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });

    final dir = Directory('build/visual-smoke');
    dir.createSync(recursive: true);
    // 本体の視覚テストが作った同名画像を、クリーンな描画ツリーの画像で上書きする。
    File('${dir.path}/11_home_works_tab.png').writeAsBytesSync(bytes!);
    // ignore: avoid_print
    print('visual-smoke clean capture: 11_home_works_tab');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
