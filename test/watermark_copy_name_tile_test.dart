import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/watermark_render.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/watermark_asset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/watermark_settings_screen.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/watermark_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 引き継ぎで足した透かしの複製（「名前 (コピー)」）は、透かしの一覧の
/// 小さなタイルでも「(コピー)」の部分まで読め、この端末の透かしと見分け
/// られる（読み込みの知らせが出した名前を探せる）。文字の透かしの複製を
/// 編集しても「(コピー)」は消えない（同じ名前の透かしが2つ並ばない）。

const _sizes = [Size(360, 800), Size(640, 360)];
const _scales = [1.0, 2.0];
const _locales = [Locale('ja'), Locale('en'), Locale('fr')];

/// 一覧の透かし：文字の透かしとその複製、画像の透かしと名前を変えた複製。
List<WatermarkAsset> _marks(AppLocalizations l10n) => [
  const WatermarkAsset(
    id: 'wm_text',
    name: '@a_account',
    type: WatermarkAssetType.text,
    text: '@a_account',
    textColor: 0xFFFF0000,
  ),
  const WatermarkAsset(
    id: 'wm_logo',
    name: 'logo',
    type: WatermarkAssetType.image,
    fileName: 'logo.png',
  ),
  WatermarkAsset(
    id: 'wm_text_copy',
    name: numberedCopyName(l10n, '@a_account', const {}),
    type: WatermarkAssetType.text,
    text: '@a_account',
    textColor: 0xFFFF0000,
    shadowEnabled: true,
  ),
  WatermarkAsset(
    id: 'wm_logo_copy',
    name: numberedCopyName(l10n, 'logo renamed', const {}),
    type: WatermarkAssetType.image,
    fileName: 'logo.png',
    outlineEnabled: true,
  ),
];

/// 1x1の透明なPNG。
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _WatermarkPicker extends FilePicker {
  late String path;

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
    PlatformFile(name: 'watermark.png', size: 0, path: path),
  ]);
}

class _WatermarkPremiumService extends PremiumService {
  @override
  bool get isPremium => true;
}

bool _hasColor(Uint8List pixels, List<int> color) {
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i] == color[0] &&
        pixels[i + 1] == color[1] &&
        pixels[i + 2] == color[2] &&
        pixels[i + 3] == color[3]) {
      return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('watermark_copy_tile_');
    Directory('${temp.path}/niarim/watermarks').createSync(recursive: true);
    File('${temp.path}/niarim/watermarks/logo.png').writeAsBytesSync(_png);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => temp.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets(
    'adding a watermark in the timeline bakes in the effects immediately',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'force_pc_mode': 0,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appRouter.go('/');
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers,
            ChangeNotifierProvider<PremiumService>(
              create: (_) => _WatermarkPremiumService(),
            ),
          ],
          child: const NiarimApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MaterialApp));
      final projects = context.read<ProjectService>();
      final service = context.read<WatermarkService>();
      final project = (await tester.runAsync(() async {
        await service.addTextWatermark(
          'Fx',
          color: 0xFF00FF00,
          outlineEnabled: true,
          outlineColor: 0xFFFF0000,
          outlineWidth: 3,
          shadowEnabled: true,
          shadowColor: 0x800000FF,
          shadowOffsetY: -8,
          shadowBlur: 0,
        );
        return projects.createProject(
          name: 'Timeline watermark test',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 128,
          exportHeight: 128,
        );
      }))!;
      appRouter.go('/timeline/${project.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('timelineAddMaterialMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timelineAddWatermarkMenuItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Fx'));
      await pumpRealAsync(tester, const Duration(milliseconds: 450));
      final scene = projects.scenesOf(project.id).first;
      final layer = projects
          .layersOf(project.id, scene.id, 0)
          .singleWhere((l) => l.type == LayerType.watermark);
      final key = projects.tileKeyFor(project.id, scene.id, 0, layer.id);
      final tiles = projects.tileManagerOf(project.id).exportAll()[key]!.values;
      expect(
        tiles.any((tile) => _hasColor(tile, const [255, 0, 0, 255])),
        isTrue,
      );
      expect(
        tiles.any((tile) => _hasColor(tile, const [0, 0, 128, 128])),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<(WatermarkService, AppLocalizations)> pumpScreen(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    required double scale,
    bool empty = false,
  }) async {
    final l10n = lookupAppLocalizations(locale);
    SharedPreferences.setMockInitialValues({
      'language': locale.languageCode,
      'watermark_assets': [
        if (!empty)
          for (final m in _marks(l10n)) jsonEncode(m.toJson()),
      ],
    });
    final services = (await tester.runAsync(() async {
      final marks = WatermarkService();
      final theme = ThemeService();
      final settings = SettingsService();
      await marks.init();
      await theme.init();
      await settings.init();
      return (marks, theme, settings);
    }))!;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: services.$1),
          ChangeNotifierProvider.value(value: services.$2),
          ChangeNotifierProvider.value(value: services.$3),
          ChangeNotifierProvider(create: (_) => FontService()),
          ChangeNotifierProvider<PremiumService>(
            create: (_) => _WatermarkPremiumService(),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const WatermarkSettingsScreen(),
          ),
        ),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    return (services.$1, l10n);
  }

  /// [card]の中の文字（RenderParagraph）。
  List<RenderParagraph> paragraphs(WidgetTester tester, Finder card) => [
    for (final e
        in find
            .descendant(of: card, matching: find.byType(RichText))
            .evaluate())
      e.renderObject! as RenderParagraph,
  ];

  testWidgets(
    'watermark list, editor and placement render the selected outline and shadow',
    (tester) async {
      final path = '${temp.path}/niarim/watermarks/logo.png';
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const Color(0xFF00FF00), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2, 2);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        image.dispose();
        picture.dispose();
        await File(path).writeAsBytes(data.buffer.asUint8List());
      });
      final (service, l10n) = await pumpScreen(
        tester,
        locale: const Locale('en'),
        size: const Size(640, 844),
        scale: 1,
      );
      final asset = service.assets
          .firstWhere((a) => a.id == 'wm_logo')
          .copyWith(
            outlineEnabled: true,
            outlineColor: 0xFFFF0000,
            outlineWidth: 3,
            shadowEnabled: true,
            shadowColor: 0x800000FF,
            shadowOffsetX: -10,
            shadowOffsetY: -10,
            shadowBlur: 0,
          );
      await tester.runAsync(() => service.updateAsset(asset));
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      Future<Uint8List> pixelsOf(Finder finder) async {
        final raw = tester.widget<RawImage>(finder);
        return (await tester.runAsync(
          () async => (await raw.image!.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List(),
        ))!;
      }

      const red = [255, 0, 0, 255];
      const blue = [0, 0, 128, 128];
      const green = [0, 255, 0, 255];
      final card = find.ancestor(
        of: find.text('logo'),
        matching: find.byType(Card),
      );
      final tile = find.descendant(of: card, matching: find.byType(RawImage));
      final listPixels = await pixelsOf(tile);
      expect(_hasColor(listPixels, red), isTrue);
      expect(_hasColor(listPixels, blue), isTrue);
      expect(_hasColor(listPixels, green), isTrue);

      await tester.tap(tile);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      final editor = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(RawImage),
      );
      expect(await pixelsOf(editor), listPixels);
      final outline = find.widgetWithText(
        SwitchListTile,
        l10n.watermarkOutlineLabel,
      );
      await tester.ensureVisible(outline);
      await tester.tap(outline);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      final adjusted = await pixelsOf(editor);
      expect(_hasColor(adjusted, red), isFalse);
      expect(_hasColor(adjusted, blue), isTrue);

      final placed = (await tester.runAsync(
        () => rasterizeWatermark(asset, 96, 96, imagePath: path),
      ))!;
      expect(_hasColor(placed, red), isTrue);
      expect(_hasColor(placed, blue), isTrue);
      expect(_hasColor(placed, green), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the text action fits in a short watermark add sheet', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final (_, l10n) = await pumpScreen(
      tester,
      locale: const Locale('fr'),
      size: const Size(520, 193),
      scale: 2,
      empty: true,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip(l10n.commonAdd));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final addText = find.descendant(
      of: sheet,
      matching: find.text(l10n.watermarkAddText),
    );
    expect(addText.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(addText);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid images and blank text do not create a watermark', (
    tester,
  ) async {
    final (service, l10n) = await pumpScreen(
      tester,
      locale: const Locale('ja'),
      size: const Size(390, 844),
      scale: 1,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = service.assets.length;
    final bad = File('${temp.path}/bad-image.png')
      ..writeAsStringSync('invalid');
    final picker = _WatermarkPicker();
    FilePicker.platform = picker;
    final add = find.byType(FloatingActionButton);
    for (final path in [bad.path, '${temp.path}/missing-image.png']) {
      picker.path = path;
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.watermarkAddFromImage));
      await pumpRealAsync(tester, const Duration(milliseconds: 450));
      expect(find.text(l10n.watermarkImageImportFailed), findsOneWidget);
      expect(service.assets, hasLength(before));
      expect(tester.takeException(), isNull);
      ScaffoldMessenger.of(
        tester.element(find.byType(WatermarkSettingsScreen)),
      ).removeCurrentSnackBar();
      await tester.pump();
    }

    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.watermarkAddText));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final confirm = find.widgetWithText(FilledButton, l10n.commonAdd);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(service.assets, hasLength(before));
    await tester.enterText(find.byType(TextField), 'New watermark');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('a copy\'s tile shows the copy suffix in full, at every size, '
      'text scale and language', (tester) async {
    await loadAppFonts(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final problems = <String>[];
    for (final locale in _locales) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          final (service, l10n) = await pumpScreen(
            tester,
            locale: locale,
            size: size,
            scale: scale,
          );
          final where =
              '$locale ${size.width.toInt()}x'
              '${size.height.toInt()} x$scale';
          for (final (index, mark) in service.assets.indexed) {
            final copy = copyNameParts(mark.name);
            if (copy == null) continue;
            final suffix = mark.name.substring(copy.name.length).trim();
            final card = find.byType(Card).at(index);
            if (card.evaluate().isEmpty) {
              problems.add('$where: no tile for ${mark.name}');
              continue;
            }
            final shown = [
              for (final p in paragraphs(tester, card))
                if (p.text.toPlainText().contains(suffix) &&
                    !p.didExceedMaxLines)
                  p,
            ];
            if (shown.isEmpty) {
              problems.add(
                '$where: "${mark.name}" is cut before "$suffix" '
                '(${[for (final p in paragraphs(tester, card)) '${p.text.toPlainText()}${p.didExceedMaxLines ? '…' : ''}'].join(' / ')})',
              );
            }
          }
          expect(tester.takeException(), isNull, reason: where);
        }
      }
    }
    if (problems.isNotEmpty) {
      fail('${problems.length} problem(s):\n${problems.join('\n')}');
    }
  });

  testWidgets('editing a copied text watermark keeps the copy suffix, also '
      'when the text changes', (tester) async {
    await loadAppFonts(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (service, l10n) = await pumpScreen(
      tester,
      locale: const Locale('ja'),
      size: const Size(360, 800),
      scale: 1,
    );
    Future<void> edit(String? newText) async {
      final copy = service.assets.firstWhere((m) => m.id == 'wm_text_copy');
      final card = find.byType(Card).at(service.assets.indexOf(copy));
      await tester.tap(
        find.descendant(of: card, matching: find.byType(InkWell)).first,
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      if (newText != null) {
        await tester.enterText(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField),
              )
              .first,
          newText,
        );
      }
      await tester.tap(find.text(l10n.commonOk));
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
    }

    await edit(null);
    expect(
      service.assets.firstWhere((m) => m.id == 'wm_text_copy').name,
      '@a_account (コピー)',
      reason: '文字を変えずに保存しても「(コピー)」は消えない',
    );
    await edit('@b_account');
    expect(
      service.assets.firstWhere((m) => m.id == 'wm_text_copy').name,
      '@b_account (コピー)',
      reason: '文字を変えた名前にも「(コピー)」を残す',
    );
    expect(
      service.assets.firstWhere((m) => m.id == 'wm_text').name,
      '@a_account',
    );
    expect(tester.takeException(), isNull);
  });
}
