import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ設定ではユーザーの色選択を機械的に拒否せず、操作不能になりうる
/// 配色の場合は起動画面右上の固定色リセットボタンから復旧できることを検証する。
///
/// リセットボタンはテーマの設定元（手動設定、プリセット、import、.niatra等）
/// に依存せず、現在のテーマが操作不能リスクの条件に当てはまれば表示される。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 起動画面はexportsフォルダの先読みでディスクを触るため、
  /// path_providerを差し替えておく。
  void mockPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('niarim_theme_rescue_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
  }

  /// 文字も背景もアクセント色も同じ＝何も見えないテーマ。
  const unreadable = AppThemePreset(
    id: 'unreadable_test',
    name: '詰みテーマ',
    accentColor: Color(0xFF336699),
    textColor: Color(0xFF336699),
    panelBgColor: Color(0xFF336699),
    menuBgColor: Color(0xFF336699),
    selectionColor: Color(0xFF336699),
    updateMarkColor: Color(0xFF336699),
  );

  group('リセットボタン用の操作不能リスク判定', () {
    test('同じ色は1.0、白と黒は21.0', () {
      expect(
        contrastRatio(const Color(0xFF336699), const Color(0xFF336699)),
        closeTo(1.0, 0.001),
      );
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21.0, 0.01),
      );
    });

    test('組み込みプリセットは全て「読める」判定を通る', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      expect(service.presets, isNotEmpty);
      for (final preset in service.presets) {
        expect(
          isThemeAtLockoutRisk(preset),
          isFalse,
          reason:
              '組み込みテーマ「${preset.name}」にリセットボタンが誤表示される。'
              'リスク目安$kMinReadableContrastの確認が必要',
        );
      }
    });

    test('同じ色・ほとんど同じ色のテーマは弾かれる', () {
      expect(isThemeAtLockoutRisk(unreadable), isTrue);
      expect(
        isThemeAtLockoutRisk(
          unreadable.copyWith(textColor: const Color(0xFF3A6FA0)),
        ),
        isTrue,
        reason: '見分けがつかないほど近い色も弾く',
      );
    });
  });

  testWidgets('テーマ設定：低コントラストでもユーザーが選んだ色を保存する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ThemeSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final service = tester
        .element(find.byType(ThemeSettingsScreen))
        .read<ThemeService>();
    final before = service.current;

    // 「文字色」のピッカーを開き、文字色をパネル背景と同じ値にする。
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.tap(find.text(l10n.themeColorText));
    await tester.pumpAndSettle();
    service.previewCurrent(
      service.current.copyWith(textColor: before.panelBgColor),
    );
    await tester.pumpAndSettle();

    // 読みにくい配色でも保存を拒否しない。操作不能への対処は起動画面の
    // 復旧ボタンに委ねる。
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.themeContrastErrorTitle), findsNothing);
    expect(service.current.textColor, before.panelBgColor);
    expect(isThemeAtLockoutRisk(service.current), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final persistedJson = prefs.getString('theme_current_json');
    expect(persistedJson, isNotNull);
    expect(
      AppThemePreset.fromJson(
        jsonDecode(persistedJson!) as Map<String, dynamic>,
      ).textColor,
      before.panelBgColor,
    );
  });

  testWidgets('起動画面：読めるテーマではリセットボタンを出さない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final service = ThemeService();
    await service.init();

    await tester.pumpWidget(await _splashApp(tester, service));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(l10n.themeUnreadableResetButton), findsNothing);
  });

  testWidgets('起動画面：読めないテーマならリセットボタンが出て、押すと既定へ戻る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final service = ThemeService();
    await service.init();
    // 色設定・プリセット・外部データ取り込み等、どの経路からでも「詰みテーマ」が入る状態。
    service.savePreset(unreadable);
    service.applyPreset(unreadable.id);

    await tester.pumpWidget(await _splashApp(tester, service));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ja'));
    final resetButton = find.text(l10n.themeUnreadableResetButton);
    // 白縁取り用Text + 黒塗りTextの2層。ただし白縁取り側はSemantics除外。
    expect(resetButton, findsNWidgets(2));
    final labelLayers = tester.widgetList<Text>(resetButton).toList();
    expect(labelLayers.first.style?.foreground?.color, const Color(0xFFFFFFFF));
    expect(labelLayers.first.style?.foreground?.style, PaintingStyle.stroke);
    expect(labelLayers.last.style?.color, const Color(0xFF000000));

    await tester.tap(resetButton.last);
    await tester.pumpAndSettle();

    expect(isThemeAtLockoutRisk(service.current), isFalse);
    expect(service.current.id, AppThemePreset.defaultLight.id);
    // 戻ったのでボタン自体も消える。
    expect(find.text(l10n.themeUnreadableResetButton), findsNothing);
  });
}

Future<Widget> _splashApp(WidgetTester tester, ThemeService service) async {
  final projects = ProjectService();
  await tester.runAsync(projects.init);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeService>.value(value: service),
      ChangeNotifierProvider<ProjectService>.value(value: projects),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        theme: context.watch<ThemeService>().themeData,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    ),
  );
}
