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

    test('組み込みプリセットでは復旧ボタンのリスク判定に該当しない', () async {
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

    test('同じ色・ほとんど同じ色のテーマは復旧ボタンの表示対象になる', () {
      expect(isThemeAtLockoutRisk(unreadable), isTrue);
      expect(
        isThemeAtLockoutRisk(
          unreadable.copyWith(textColor: const Color(0xFF3A6FA0)),
        ),
        isTrue,
        reason: '見分けがつかないほど近い色も弾く',
      );
    });
    test('ほぼ白の文字とほぼ白の背景は復旧対象', () {
      final light = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFFFFFAF0),
        panelBgColor: const Color(0xFFFFFBEA),
      );
      expect(isThemeAtLockoutRisk(light), isTrue);
    });

    test('パステル調の色相差がある配色・白黒モノクロは判定で排除しない', () {
      final pastel = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFFA3D9F4),
        panelBgColor: const Color(0xFFFFBDCE),
      );
      expect(contrastRatio(pastel.textColor, pastel.panelBgColor),
          lessThan(1.2));
      expect(isThemeAtLockoutRisk(pastel), isFalse);
      final monochrome = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF000000),
        panelBgColor: const Color(0xFFFFFFFF),
        menuBgColor: const Color(0xFFFFFFFF),
        accentColor: const Color(0xFF333333),
        selectionColor: const Color(0xFF333333),
        updateMarkColor: const Color(0xFFFFFFFF),
      );
      expect(isThemeAtLockoutRisk(monochrome), isFalse);
    });

    test('隣接しない色項目は完全に同色でも復旧ボタンの判定対象外', () {
      final theme = AppThemePreset.defaultLight.copyWith(
        updateMarkColor: AppThemePreset.defaultLight.textColor,
        selectionColor: AppThemePreset.defaultLight.accentColor,
      );
      expect(isThemeAtLockoutRisk(theme), isFalse);
    });

    test('通常の色覚では区別できても2型色覚でほぼ区別できない配色', () {
      const red = Color(0xFFDC0F0F);
      const green = Color(0xFF0FA00F);
      expect(contrastRatio(red, green), greaterThan(kMinReadableContrast));
      expect(okLabDistance(red, green), greaterThan(0.3));
      expect(
        okLabDistance(
          simulateColorVision(red, ColorVisionType.deuteranopia),
          simulateColorVision(green, ColorVisionType.deuteranopia),
        ),
        lessThan(kMaxConfusableOkLabDistance),
      );
      expect(isColorVisionPairConfusable(red, green), isTrue);
      expect(
        isThemeAtLockoutRisk(AppThemePreset.defaultLight.copyWith(
          textColor: red,
          panelBgColor: green,
        )),
        isTrue,
      );
      expect(
        isColorVisionPairConfusable(Colors.black, Colors.white),
        isFalse,
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

  testWidgets('起動画面：キャンセルでは変更せず、確認した場合だけ保存して復旧', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final service = ThemeService();
    await service.init();
    service.savePreset(unreadable);
    service.applyPreset(unreadable.id);

    await tester.pumpWidget(await _splashApp(tester, service));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ja'));
    final resetButton = find.text(l10n.themeUnreadableResetButton);
    expect(resetButton, findsNWidgets(2));
    final labelLayers = tester.widgetList<Text>(resetButton).toList();
    expect(labelLayers.first.style?.foreground?.color, Colors.white);
    expect(labelLayers.first.style?.foreground?.style, PaintingStyle.stroke);
    expect(labelLayers.last.style?.color, Colors.black);

    await tester.tap(resetButton.last);
    await tester.pumpAndSettle();
    expect(service.current.id, unreadable.id);
    expect(find.text(l10n.themeResetConfirmTitle), findsOneWidget);
    final dialogTheme = Theme.of(tester.element(find.byType(AlertDialog)));
    expect(dialogTheme.colorScheme.onSurface,
        AppThemePreset.defaultLight.textColor);
    expect(dialogTheme.dialogTheme.backgroundColor,
        AppThemePreset.defaultLight.menuBgColor);

    await tester.tap(find.text(l10n.commonCancel).last);
    await tester.pumpAndSettle();
    expect(service.current.id, unreadable.id);
    expect(resetButton, findsNWidgets(2));

    await tester.tap(resetButton.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.themeResetConfirmAction));
    await tester.pumpAndSettle();

    expect(isThemeAtLockoutRisk(service.current), isFalse);
    expect(service.current.id, AppThemePreset.defaultLight.id);
    expect(resetButton, findsNothing);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('theme_current_json')!)
        as Map<String, dynamic>;
    expect(AppThemePreset.fromJson(saved).textColor,
        AppThemePreset.defaultLight.textColor);

    // 再起動しても標準色のまま
    final reopened = ThemeService();
    await reopened.init();
    expect(reopened.current.id, AppThemePreset.defaultLight.id);
    expect(reopened.current.textColor, AppThemePreset.defaultLight.textColor);
  });

  testWidgets('外観・テーマ：右上に同じ復旧ボタンを置き、確認で標準へ戻す', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    service.restoreCurrent(unreadable);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: service,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: const Locale('ja'),
            theme: context.watch<ThemeService>().themeData,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ThemeSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final resetButton = find.text(l10n.themeUnreadableResetButton);
    expect(resetButton, findsNWidgets(2));
    await tester.tap(resetButton.last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.themeResetConfirmTitle), findsOneWidget);
    expect(service.current.id, unreadable.id);

    await tester.tap(find.text(l10n.themeResetConfirmAction));
    await tester.pumpAndSettle();
    expect(service.current.id, AppThemePreset.defaultLight.id);
    expect(resetButton, findsNothing);
  });

  test('引き継いだ詰みテーマも勝手に補正・拒否されず復元できる', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_current_json', jsonEncode(unreadable.toJson()));
    final restored = ThemeService();
    await restored.init();
    expect(restored.current.textColor, unreadable.textColor);
    expect(isThemeAtLockoutRisk(restored.current), isTrue);
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
