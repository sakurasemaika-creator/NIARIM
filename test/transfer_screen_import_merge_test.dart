import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/settings/transfer_screen.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 選ぶと決まった.niatraを返すファイル選択。
class _PickNiatra extends FilePicker {
  _PickNiatra(this.bytes);

  final Uint8List bytes;

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
  }) async => FilePickerResult([
    PlatformFile(name: 'moved.niatra', size: bytes.length, bytes: bytes),
  ]);
}

const _allItems = {
  '設定': true,
  '端末保存データ': true,
  '素材': true,
  'ブラシ': true,
  'プリセット': true,
  'UIテーマ': true,
  'パレット': true,
};

/// 元の端末：組み込みのペンの太さを覚え、画像つきの自作ブラシと自作の
/// テーマを作って、画面の既定（すべての項目）で書き出す。
Future<Uint8List> _sourceFile(Directory temp) async {
  SharedPreferences.setMockInitialValues({'language': 'ja'});
  final settings = SettingsService();
  final brush = BrushService();
  final tone = ToneService();
  final stamp = StampService();
  final autofill = AutofillPresetService();
  final theme = ThemeService();
  final palette = PaletteService();
  final pixelArt = PixelArtPaletteService();
  await settings.init();
  await brush.init();
  await tone.init();
  await stamp.init();
  await autofill.init();
  await theme.init();
  await palette.init();
  await pixelArt.init();

  brush.selectBrush('Brush0001');
  brush.updateCurrentBrushSize(23);
  await brush.commitRememberedValues();
  final image = File('${temp.path}/source_brush.png')
    ..writeAsBytesSync([1, 2, 3, 4]);
  brush.addBrush(
    Brush(
      id: 'BrushMoved',
      name: 'Moved brush',
      size: 17,
      opacity: 73,
      spacing: 12,
      stabilization: true,
      stabilizationStrength: 41,
      pixelMode: false,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      customImagePath: image.path,
    ),
  );
  theme.savePreset(
    AppThemePreset.defaultLight.copyWith(id: 'theme_moved', name: 'Moved'),
  );
  // サムネイルを付けた自作の自動塗りプリセット。
  await autofill.addPreset(
    const AutofillPreset(
      id: 'p_moved',
      name: 'Moved preset',
      parts: [AutofillPart(id: 'moved_base', name: 'Base', color: 0xFFFF0000)],
    ),
  );
  await autofill.setPresetThumbnailBytes(
    'p_moved',
    Uint8List.fromList([3, 1, 4]),
  );
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
  final raw = await NiatraSerializer.export(
    selectedItems: _allItems,
    settings: settings,
    brush: brush,
    tone: tone,
    stamp: stamp,
    autofillPresets: autofill,
    theme: theme,
    palette: palette,
    pixelArtPalette: pixelArt,
  );
  final bytes = await NiatraAssetBundle.enrichExport(
    raw,
    selectedItems: _allItems,
    brush: brush,
    tone: tone,
    stamp: stamp,
  );
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  FilePicker? previousPicker;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_screen_import_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => temp.path);
    try {
      previousPicker = FilePicker.platform;
    } catch (_) {
      previousPicker = null;
    }
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    if (previousPicker != null) FilePicker.platform = previousPicker!;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('reading the same .niatra twice on the transfer screen adds the '
      'built-in brushes and themes no second time, and the remembered pen '
      'size survives a save and a restart', (tester) async {
    final bytes = (await tester.runAsync(() => _sourceFile(temp)))!;

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TransferScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.element(find.byType(TransferScreen));
    final l10n = AppLocalizations.of(screen)!;
    final brush = screen.read<BrushService>();
    final theme = screen.read<ThemeService>();
    final builtInBrushes = brush.brushes.length;
    final builtInThemes = theme.presets.length;
    FilePicker.platform = _PickNiatra(bytes);

    Future<void> readFile() async {
      await tester.tap(find.text(l10n.transferImport));
      for (
        var i = 0;
        i < 100 &&
            find.text(l10n.transferImportSuccessSnackbar).evaluate().isEmpty;
        i++
      ) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      expect(find.text(l10n.transferImportSuccessSnackbar), findsOneWidget);
      ScaffoldMessenger.of(screen).clearSnackBars();
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
    }

    final problems = <String>[];
    void check(Object? actual, Object? matcher, String reason) {
      try {
        expect(actual, matcher, reason: reason);
      } on TestFailure catch (e) {
        problems.add('$e'.trim());
      }
    }

    void checkState(BrushService b, ThemeService t, String when) {
      check(b.brushes.length, builtInBrushes + 1, '$when: 組み込みのブラシが増えていない');
      check(
        b.brushes.where((x) => x.name == 'Moved brush').length,
        1,
        '$when: 自作のブラシは1つ',
      );
      check(b.brushes.where((x) => x.id == 'Brush0001').map((x) => x.size), [
        23,
      ], '$when: 組み込みのペンで覚えた太さ');
      check(t.presets.length, builtInThemes + 1, '$when: 組み込みのテーマが増えていない');
    }

    await readFile();
    checkState(brush, theme, 'after the first import');
    final thumbnail = screen
        .read<AutofillPresetService>()
        .presets
        .where((p) => p.id == 'p_moved')
        .firstOrNull
        ?.thumbnailPath;
    check(
      thumbnail != null && File(thumbnail).existsSync()
          ? File(thumbnail).readAsBytesSync()
          : null,
      [3, 1, 4],
      '自動塗りプリセットのサムネイルの画像が届く',
    );
    await readFile();
    checkState(brush, theme, 'after the second import');

    // 動いているサービスでいつもの保存をしてから、起動し直す。
    final moved = brush.brushes
        .where((x) => x.name == 'Moved brush')
        .firstOrNull;
    if (moved != null) brush.toggleFavoriteBrush(moved.id);
    brush.selectBrush('Brush0003');
    final size0003 = brush.currentBrush!.size + 8;
    brush.updateCurrentBrushSize(size0003);
    await tester.runAsync(brush.commitRememberedValues);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));

    final restarted = (await tester.runAsync(() async {
      final b = BrushService();
      final t = ThemeService();
      await b.init();
      await t.init();
      return (brush: b, theme: t);
    }))!;
    checkState(restarted.brush, restarted.theme, 'restart after saving');
    check(
      restarted.brush.brushes
          .where((x) => x.id == 'Brush0003')
          .map((x) => x.size),
      [size0003],
      'restart after saving: 読み込みの後に覚えた太さ',
    );
    expect(tester.takeException(), isNull);
    if (problems.isNotEmpty) {
      fail('${problems.length} problem(s):\n\n${problems.join('\n\n')}');
    }
  });

  testWidgets('when this device already had a different version, the '
      'message says the other device\'s version was added under a new name, '
      'and reading the same file again just says it was read', (tester) async {
    final bytes = (await tester.runAsync(() => _sourceFile(temp)))!;

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TransferScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.element(find.byType(TransferScreen));
    final l10n = AppLocalizations.of(screen)!;
    final brush = screen.read<BrushService>();
    // この端末にも同じブラシがあり、中身（間隔）を変えてある。
    brush.addBrush(
      const Brush(
        id: 'BrushMoved',
        name: 'Moved brush',
        size: 17,
        opacity: 73,
        spacing: 5,
        stabilization: true,
        stabilizationStrength: 41,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    FilePicker.platform = _PickNiatra(bytes);

    Future<String> readFile() async {
      await tester.tap(find.text(l10n.transferImport));
      Finder bar() => find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Text),
      );
      for (var i = 0; i < 100 && bar().evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      final text = tester.widget<Text>(bar().first).data ?? '';
      ScaffoldMessenger.of(screen).clearSnackBars();
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      return text;
    }

    final first = await readFile();
    expect(
      brush.brushes.where((b) => b.name == 'Moved brush (コピー)'),
      hasLength(1),
    );
    expect(first, contains('Moved brush (コピー)'), reason: 'もう1台の方を足した名前を知らせる');
    expect(first, isNot(l10n.transferImportSuccessSnackbar));
    final second = await readFile();
    expect(
      second,
      l10n.transferImportSuccessSnackbar,
      reason: '何も足さなければ、読み込んだことだけ',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a project in the file that this device has in another '
      'version is added under a new name and named in the message; reading '
      'the file again adds nothing and just says it was read', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TransferScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.element(find.byType(TransferScreen));
    final l10n = AppLocalizations.of(screen)!;
    final projects = screen.read<ProjectService>();

    Uint8List tile(int value) {
      final bytes = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
      for (var i = 0; i < bytes.length; i += 4) {
        bytes.fillRange(i, i + 3, value);
        bytes[i + 3] = 255;
      }
      return bytes;
    }

    // この端末の作品と、もう1台で描き足した同じ名前の作品の入ったファイル。
    final file = (await tester.runAsync(() async {
      final work = await projects.createProject(
        name: 'Shared work',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      final scene = projects.scenesOf(work.id).first;
      final key = frameLayerKey(
        scene.id,
        scene.frames.first.index,
        scene.frames.first.layers.first.id,
      );
      projects.tileManagerOf(work.id).importAll({
        key: {'0,0': tile(40)},
      });
      final other =
          TileManager(
            canvasWidth: work.drawingWidth,
            canvasHeight: work.drawingHeight,
          )..importAll({
            key: {'0,0': tile(200)},
          });
      final out = Directory('${temp.path}/share')..createSync();
      final share = await NiaproSerializer.saveShare(
        project: work,
        scenes: projects.scenesOf(work.id),
        tileManager: other,
        outputDir: out.path,
      );
      return NiatraSerializer.export(
        selectedItems: const {},
        settings: screen.read<SettingsService>(),
        brush: screen.read<BrushService>(),
        tone: screen.read<ToneService>(),
        stamp: screen.read<StampService>(),
        autofillPresets: screen.read<AutofillPresetService>(),
        theme: screen.read<ThemeService>(),
        palette: screen.read<PaletteService>(),
        pixelArtPalette: screen.read<PixelArtPaletteService>(),
        projectFiles: {'${work.id}.niashare': await share.readAsBytes()},
      );
    }))!;
    FilePicker.platform = _PickNiatra(file);

    Future<String> readFile() async {
      await tester.tap(find.text(l10n.transferImport));
      Finder bar() => find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Text),
      );
      for (var i = 0; i < 100 && bar().evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      final text = tester.widget<Text>(bar().first).data ?? '';
      ScaffoldMessenger.of(screen).clearSnackBars();
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      return text;
    }

    List<String> names() => [for (final p in projects.projects) p.name]..sort();

    final first = await readFile();
    expect(names(), ['Shared work', 'Shared work (コピー)']);
    expect(first, contains('Shared work (コピー)'), reason: 'もう1台の作品を足した名前を知らせる');
    final second = await readFile();
    expect(names(), ['Shared work', 'Shared work (コピー)'], reason: '読み直しても増えない');
    expect(second, l10n.transferImportSuccessSnackbar);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
