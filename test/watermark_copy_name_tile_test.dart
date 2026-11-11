import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/watermark_asset.dart';
import 'package:niarim/screens/settings/watermark_settings_screen.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/watermark_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
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

  Future<(WatermarkService, AppLocalizations)> pumpScreen(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    required double scale,
  }) async {
    final l10n = lookupAppLocalizations(locale);
    SharedPreferences.setMockInitialValues({
      'language': locale.languageCode,
      'watermark_assets': [
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
