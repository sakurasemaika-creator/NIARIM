import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/workspace_preset.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/shared_asset_card_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/widgets/premium_lock_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Capture production export dialogs and PNG files', (
    tester,
  ) async {
    final out = Directory('build/shared-asset-card-captures/dialogs')
      ..createSync(recursive: true);
    final appFiles = await tester.runAsync(
      () => Directory.systemTemp.createTemp('niarim-cards-'),
    );
    const path = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(path, (_) async => appFiles!.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(path, null);
      if (appFiles!.existsSync()) appFiles.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1.5;
    tester.view.physicalSize = const Size(660, 1020);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    late BuildContext screen;
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final now = DateTime.utc(2026, 11, 16);
    const colors = [
      0xff28365c,
      0xff8879b7,
      0xffdca1b0,
      0xffefcf91,
      0xff7bb9bb,
      0xffe7ecf5,
    ];
    const labels = {
      'brush': 'ブラシ',
      'stamp': 'スタンプ',
      'tone': 'トーン',
      'theme': 'テーマ・外観',
      'filter': '描画フィルター',
      'automation': 'オートアクション',
      'palette': 'パレット',
      'pixelPalette': 'ドット絵パレット',
      'workspace': 'ワークスペース',
      'autofill': '自動塗りプリセット',
    };
    for (final kind in labels.keys) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xff6354a1),
              useMaterial3: true,
              fontFamily: 'HakkouMincho',
            ),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: AppBar(title: Text(labels[kind]!)),
              body: Builder(
                builder: (context) {
                  screen = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      final brushes = BrushService();
      if (kind == 'workspace' || kind == 'brush') {
        await tester.runAsync(brushes.init);
      }
      switch (kind) {
        case 'brush':
          final png = await tester.runAsync(
            () => SharedAssetCardService.exportBrush(
              brushes,
              brushes.brushes.first,
              l10n: l10n,
            ),
          );
          SharedAssetCardService.showExportResult(screen, png!);
        case 'stamp':
          final stamps = StampService();
          await tester.runAsync(stamps.init);
          final png = await tester.runAsync(
            () => SharedAssetCardService.exportStamp(
              stamps,
              stamps.stamps.first,
              l10n: l10n,
            ),
          );
          SharedAssetCardService.showExportResult(screen, png!);
        case 'tone':
          final tones = ToneService();
          await tester.runAsync(tones.init);
          final png = await tester.runAsync(
            () => SharedAssetCardService.exportTone(
              tones,
              tones.tones.first,
              l10n: l10n,
            ),
          );
          SharedAssetCardService.showExportResult(screen, png!);
        case 'workspace':
          SharedAssetCardService.exportWorkspace(
            screen,
            const WorkspacePreset(
              id: 'sample',
              name: '線画用ワークスペース',
              isLeftHanded: false,
              toolbarOrder: ['pen', 'eraser', 'bucket'],
            ),
            brushes,
          );
        default:
          final data = switch (kind) {
            'theme' => AppThemePreset.fromJson({
              'id': 'theme-sample',
              'name': '夕暮れ',
              'accentColor': colors[2],
              'textColor': colors[0],
              'buttonTextColor': colors[5],
              'menuTextColor': colors[0],
              'selectionTextColor': colors[0],
              'panelBgColor': colors[5],
              'menuBgColor': colors[4],
              'selectionColor': colors[1],
              'updateMarkColor': colors[3],
            }).toJson(),
            'filter' => const FilterDef(
              id: 'filter-sample',
              name: 'やわらかいぼかし',
              kind: FilterKind.gaussianBlur,
              strength: 12,
              isSettingsPreset: true,
            ).toJson(),
            'automation' => CustomAutomation(
              id: 'automation-sample',
              name: '線画の準備',
              createdAt: now,
              updatedAt: now,
              steps: const [
                CustomAutomationStep(
                  id: 's1',
                  surface: CustomAutomationSurface.canvas,
                  command: 'layer.add',
                  label: 'レイヤーを追加',
                ),
                CustomAutomationStep(
                  id: 's2',
                  surface: CustomAutomationSurface.canvas,
                  command: 'layer.rename',
                  label: 'レイヤー名を変更',
                ),
              ],
            ).toJson(),
            'palette' || 'pixelPalette' => {
              'id': 'palette-sample',
              'name': kind == 'palette' ? '夕暮れの配色' : 'ドット絵の6色',
              'colors': colors,
            },
            'autofill' => const AutofillPreset(
              id: 'fill-sample',
              name: '夕暮れの人物',
              parts: [
                AutofillPart(id: 'p1', name: '髪', color: 0xff28365c),
                AutofillPart(id: 'p2', name: '服', color: 0xffdca1b0),
              ],
            ).toJson(),
            _ => throw StateError(kind),
          };
          SharedAssetCardService.exportSettings(
            screen,
            kind: kind,
            name: data['name'] as String,
            settings: data,
          );
      }
      final dialog = find.byType(AlertDialog);
      for (var i = 0; i < 50; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 150));
        if (dialog.evaluate().isNotEmpty) break;
      }
      expect(dialog, findsOneWidget, reason: kind);
      expect(find.text(l10n.shareCardKeepOriginalNote), findsOneWidget);
      expect(find.textContaining('SNSで画像を保存'), findsNothing);
      await pumpRealAsync(tester, const Duration(milliseconds: 550));
      final image = tester.widget<Image>(
        find.descendant(of: dialog, matching: find.byType(Image)).first,
      );
      final file = (image.image as FileImage).file;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        expect((await SharedAssetCardService.inspect(file)).kind, kind);
        if (kind == 'filter') {
          final payload = await SharedAssetCardService.readSettingsFile(
            file.path,
            kind: 'filter',
          );
          final restored = FilterDef.fromJson(
            jsonDecode(payload) as Map<String, dynamic>,
          );
          expect(
            (restored.name, restored.strength, restored.isSettingsPreset),
            ('やわらかいぼかし', 12.0, true),
          );
        }
        if (const {'brush', 'stamp', 'tone'}.contains(kind)) {
          final card = img.decodePng(await file.readAsBytes())!;
          final stroke = img.copyCrop(
            card,
            x: 210,
            y: 570,
            width: 780,
            height: 140,
          );
          expect(
            stroke.any((pixel) => pixel.r < 120 && pixel.g < 120),
            isTrue,
            reason: '$kind must render ink in the separate stroke area',
          );
        }
        await file.copy('${out.path}/$kind-card.png');
        final picture = await boundary.toImage(pixelRatio: 1.5);
        try {
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          File(
            '${out.path}/$kind-screen.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        } finally {
          picture.dispose();
        }
      });
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();
      brushes.dispose();
      debugPrint('Captured $kind');
    }
    showPremiumBanner(
      screen,
      feature: PremiumFeature.unlimitedDuration,
      title: l10n.premiumBannerFullExportTitle,
      reason: l10n.exportLongProjectNote,
      continueLabel: l10n.exportFirst90Seconds,
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(find.text('作品を全編書き出す'), findsOneWidget);
    expect(find.text(l10n.exportLongProjectNote), findsOneWidget);
    expect(find.text('プレミアム会員の詳細を見る'), findsOneWidget);
    expect(find.text('特典の詳細を見る'), findsOneWidget);
    expect(find.textContaining('コンプリートパック'), findsNothing);
    expect(find.textContaining('準備中'), findsNothing);
    expect(find.textContaining('開発中'), findsNothing);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('無料')),
      findsOneWidget,
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/premium-screen.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.tap(find.text(l10n.exportFirst90Seconds));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('Each locked feature shows its own title and body', (
    tester,
  ) async {
    final labels = lookupAppLocalizations(const Locale('ja'));
    final premium = PremiumService();
    addTearDown(premium.dispose);
    for (final (feature, title, body) in [
      (
        PremiumFeature.endCardEdit,
        labels.premiumFeatureEndLogo,
        labels.premiumBannerEndCardBody,
      ),
      (
        PremiumFeature.watermark,
        labels.premiumFeatureWatermark,
        labels.premiumBannerWatermarkBody,
      ),
      (
        PremiumFeature.toneCurve,
        labels.premiumFeatureToneCurve,
        labels.premiumBannerToneCurveBody,
      ),
      (
        PremiumFeature.levelAdjustment,
        labels.premiumFeatureLevelCorrection,
        labels.premiumBannerLevelsBody,
      ),
      (
        PremiumFeature.unlimitedDuration,
        labels.premiumFeatureMaxDuration,
        labels.timelineDurationLimitBodyFree,
      ),
      (
        PremiumFeature.customAutomation,
        labels.customAutomationTitle,
        labels.premiumBannerAutomationBody,
      ),
    ]) {
      final trigger = ValueKey(feature);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: premium,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PremiumLockWidget(
                key: trigger,
                feature: feature,
                child: const Text('Locked feature'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(trigger));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: feature.name);
      expect(find.text(body), findsOneWidget, reason: feature.name);
      expect(find.text(labels.exportFirst90Seconds), findsNothing);
      await tester.tap(find.text(labels.commonClose));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    }
  });
}
