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
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/widgets/theme_rescue_button.dart';
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
    buttonTextColor: Color(0xFF336699),
    menuTextColor: Color(0xFF336699),
    selectionTextColor: Color(0xFF336699),
    panelBgColor: Color(0xFF336699),
    menuBgColor: Color(0xFF336699),
    selectionColor: Color(0xFF336699),
    updateMarkColor: Color(0xFF336699),
  );

  group('新しいテーマ文字色の独立性', () {
    test('すべての組み込みプリセットに4種類の文字色が明示されている', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      expect(service.presets.length, 28);
      for (final preset in service.presets) {
        final encoded = preset.toJson();
        for (final field in const [
          'textColor',
          'buttonTextColor',
          'menuTextColor',
          'selectionTextColor',
        ]) {
          expect(
            encoded[field],
            isA<int>(),
            reason: '${preset.id} must define $field explicitly',
          );
        }
      }
    });

    test('4種類の文字色はJSON書き出し・読み込みで独立して保持', () {
      final custom = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF111111),
        buttonTextColor: const Color(0xFFFFFFFF),
        menuTextColor: const Color(0xFF993366),
        selectionTextColor: const Color(0xFF00FF00),
      );
      final restored = AppThemePreset.fromJson(
        jsonDecode(jsonEncode(custom.toJson())) as Map<String, dynamic>,
      );
      expect(restored.textColor, const Color(0xFF111111));
      expect(restored.buttonTextColor, Colors.white);
      expect(restored.menuTextColor, const Color(0xFF993366));
      expect(restored.selectionTextColor, const Color(0xFF00FF00));
    });

    test('新形式に足りない文字色があるプリセットは不完全として読み込まない', () {
      final old = Map<String, dynamic>.from(
        AppThemePreset.defaultLight.toJson(),
      );
      old.remove('buttonTextColor');
      expect(() => AppThemePreset.fromJson(old), throwsA(isA<TypeError>()));
    });

    test('本文が黒・塗りつぶしボタンが白・メニューが紫もそのまま適用', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      service.previewCurrent(
        AppThemePreset.defaultLight.copyWith(
          textColor: const Color(0xFF111111),
          buttonTextColor: Colors.white,
          menuTextColor: const Color(0xFF8844CC),
          selectionTextColor: const Color(0xFF44EE55),
        ),
      );
      final data = service.themeData;
      expect(data.colorScheme.onSurface, const Color(0xFF111111));
      expect(data.colorScheme.onPrimary, Colors.white);
      expect(data.colorScheme.onSecondary, const Color(0xFF44EE55));
      expect(data.colorScheme.onPrimaryContainer, const Color(0xFF111111));
      expect(data.colorScheme.onSecondaryContainer, const Color(0xFF111111));
      expect(data.listTileTheme.selectedColor, const Color(0xFF44EE55));
      expect(
        data.listTileTheme.selectedTileColor,
        service.current.selectionColor,
      );
      final selected = <WidgetState>{WidgetState.selected};
      final unselected = <WidgetState>{};
      expect(
        data.segmentedButtonTheme.style!.foregroundColor!.resolve(selected),
        const Color(0xFF44EE55),
      );
      expect(
        data.segmentedButtonTheme.style!.foregroundColor!.resolve(unselected),
        const Color(0xFF111111),
      );
      expect(
        data.segmentedButtonTheme.style!.backgroundColor!.resolve(selected),
        service.current.selectionColor,
      );
      expect(
        data.navigationBarTheme.iconTheme!.resolve(selected)!.color,
        const Color(0xFF44EE55),
      );
      expect(data.appBarTheme.foregroundColor, const Color(0xFF8844CC));
      expect(data.popupMenuTheme.textStyle!.color, const Color(0xFF8844CC));
      expect(service.current.textColor, const Color(0xFF111111));
    });

    test('復旧リスクも各新しい文字色と実際の背景を参照する', () {
      final base = AppThemePreset.defaultLight;
      expect(isThemeAtLockoutRisk(base), isFalse);
      expect(
        isThemeAtLockoutRisk(base.copyWith(buttonTextColor: base.accentColor)),
        isTrue,
      );
      expect(
        isThemeAtLockoutRisk(base.copyWith(menuTextColor: base.menuBgColor)),
        isTrue,
      );
      expect(
        isThemeAtLockoutRisk(
          base.copyWith(selectionTextColor: base.selectionColor),
        ),
        isTrue,
      );
    });
  });

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

    test('実際の文字・背景：画像1は危険、画像2は復旧不要', () {
      const red = Color(0xFFFF0000);
      const darkRed = Color(0xFFB24545);
      const pink = Color(0xFFFFAFAF);
      expect(apcaContrast(red, darkRed), closeTo(-11.6, 0.5));
      expect(apcaContrast(pink, Colors.white), closeTo(31.8, 0.5));
      expect(isEssentialTextNearlyInvisible(red, darkRed), isTrue);
      expect(isEssentialTextNearlyInvisible(pink, Colors.white), isFalse);
      expect(
        isEssentialTextNearlyInvisible(Colors.black, Colors.white),
        isFalse,
      );
      expect(
        isEssentialTextNearlyInvisible(Colors.white, Colors.white),
        isTrue,
      );
    });

    test('スマホの小さな文字：水色とピンクも実文字のLcで判定', () {
      const blue = Color(0xFFA3D9F4);
      const pink = Color(0xFFFFBDCE);
      expect(apcaContrast(blue, pink).abs(), lessThan(10));
      expect(isEssentialTextNearlyInvisible(blue, pink), isTrue);
    });

    test('軽度の読みにくさでは常駐リセットボタンを表示しない', () {
      const foreground = Color(0xFF200020);
      const background = Color(0xFFC02040);
      expect(apcaContrast(foreground, background).abs(), greaterThan(20));
      // 1型の模擬後も Lc約14.9。旧閾値20では表示されていた。
      final simulatedLc = apcaContrast(
        simulateColorVision(foreground, ColorVisionType.protanopia),
        simulateColorVision(background, ColorVisionType.protanopia),
      ).abs();
      expect(simulatedLc, greaterThanOrEqualTo(kThemeRescueUnusableTextLc));
      expect(isEssentialTextNearlyInvisible(foreground, background), isFalse);
    });

    test('復旧の境界値：プラス・マイナスとも |Lc| 10未満のみ表示', () {
      const background = Color(0xFF777777);
      const plusBelow = Color(0xFF5C5C5C); // Lc 約+9.97
      const plusAbove = Color(0xFF5B5B5B); // Lc 約+10.39
      const minusBelow = Color(0xFF8D8D8D); // Lc 約-9.79
      const minusAbove = Color(0xFF8E8E8E); // Lc 約-10.29
      expect(kThemeRescueUnusableTextLc, 10.0);
      expect(apcaContrast(plusBelow, background), closeTo(9.97, 0.1));
      expect(apcaContrast(plusAbove, background), closeTo(10.39, 0.1));
      expect(apcaContrast(minusBelow, background), closeTo(-9.79, 0.1));
      expect(apcaContrast(minusAbove, background), closeTo(-10.29, 0.1));
      expect(isEssentialTextNearlyInvisible(plusBelow, background), isTrue);
      expect(isEssentialTextNearlyInvisible(plusAbove, background), isFalse);
      expect(isEssentialTextNearlyInvisible(minusBelow, background), isTrue);
      expect(isEssentialTextNearlyInvisible(minusAbove, background), isFalse);
    });

    test('正常ではLc約-11.6でも、1型では0に埋もれる赤系は復旧対象', () {
      const foreground = Color(0xFFFF0000);
      const background = Color(0xFFB24545);
      expect(apcaContrast(foreground, background).abs(), greaterThan(10));
      expect(
        apcaContrast(
          simulateColorVision(foreground, ColorVisionType.protanopia),
          simulateColorVision(background, ColorVisionType.protanopia),
        ),
        0,
      );
      expect(isEssentialTextNearlyInvisible(foreground, background), isTrue);
    });

    test('正常・1型ではLc 10以上でも2型で埋もれたら復旧対象', () {
      const foreground = Color(0xFFA00F0F);
      const background = Color(0xFF0F820F);
      expect(apcaContrast(foreground, background).abs(), greaterThan(10));
      expect(
        apcaContrast(
          simulateColorVision(foreground, ColorVisionType.protanopia),
          simulateColorVision(background, ColorVisionType.protanopia),
        ).abs(),
        greaterThan(10),
      );
      expect(
        apcaContrast(
          simulateColorVision(foreground, ColorVisionType.deuteranopia),
          simulateColorVision(background, ColorVisionType.deuteranopia),
        ).abs(),
        lessThan(10),
      );
      expect(isEssentialTextNearlyInvisible(foreground, background), isTrue);
    });

    test('正常・1型・2型が読めても3型で埋もれたら復旧対象', () {
      const foreground = Color(0xFFFE8923);
      const background = Color(0xFFF251AF);
      for (final vision in const [
        ColorVisionType.protanopia,
        ColorVisionType.deuteranopia,
      ]) {
        expect(
          apcaContrast(
            simulateColorVision(foreground, vision),
            simulateColorVision(background, vision),
          ).abs(),
          greaterThan(10),
        );
      }
      expect(apcaContrast(foreground, background).abs(), greaterThan(10));
      expect(
        apcaContrast(
          simulateColorVision(foreground, ColorVisionType.tritanopia),
          simulateColorVision(background, ColorVisionType.tritanopia),
        ).abs(),
        lessThan(10),
      );
      expect(isEssentialTextNearlyInvisible(foreground, background), isTrue);
    });

    test('透過色は実際の下地と合成して文字として判定する', () {
      const panel = Color(0xFFF9F9F9);
      final color = opaqueOver(const Color(0x00FF0000), panel);
      expect(isEssentialTextNearlyInvisible(color, panel), isTrue);
    });

    test('テーマの変更時だけリセット判定キャッシュを更新する', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      expect(service.needsThemeRescue, isFalse);
      expect(service.needsThemeRescue, isFalse);
      service.previewCurrent(unreadable);
      expect(service.needsThemeRescue, isTrue);
      expect(service.needsThemeRescue, isTrue);
      await service.resetToDefault();
      expect(service.needsThemeRescue, isFalse);
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
              'APCA復旧判定に誤検知がないか確認すること',
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
    test('正常・1型・2型それぞれに知覚色差を計算する', () {
      const first = Color(0xFFDC0F0F);
      const second = Color(0xFF0FA00F);
      final normal = perceivedColorDistance(first, second);
      final type1 = perceivedColorDistance(
        first,
        second,
        visionType: ColorVisionType.protanopia,
      );
      final type2 = perceivedColorDistance(
        first,
        second,
        visionType: ColorVisionType.deuteranopia,
      );
      expect(normal, greaterThan(0.30));
      expect(type1, greaterThan(0.08));
      expect(type2, lessThan(kMaxConfusableOkLabDistance));
    });

    test('ほぼ白の文字とほぼ白の背景は復旧対象', () {
      final light = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFFFFFAF0),
        panelBgColor: const Color(0xFFFFFBEA),
      );
      expect(isThemeAtLockoutRisk(light), isTrue);
    });

    test('パステル配色・白黒モノクロは、重要な文字が読める限り排除しない', () {
      final pastel = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF2B2730),
        panelBgColor: const Color(0xFFFFBDCE),
        accentColor: const Color(0xFFFF7EB3),
        selectionColor: const Color(0xFFFF7EB3),
      );
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
        isThemeAtLockoutRisk(
          AppThemePreset.defaultLight.copyWith(
            textColor: red,
            panelBgColor: green,
          ),
        ),
        isTrue,
      );
      expect(isColorVisionPairConfusable(Colors.black, Colors.white), isFalse);
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
    expect(
      dialogTheme.colorScheme.onSurface,
      AppThemePreset.defaultLight.textColor,
    );
    expect(
      dialogTheme.dialogTheme.backgroundColor,
      AppThemePreset.defaultLight.menuBgColor,
    );

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
    final saved =
        jsonDecode(prefs.getString('theme_current_json')!)
            as Map<String, dynamic>;
    expect(
      AppThemePreset.fromJson(saved).textColor,
      AppThemePreset.defaultLight.textColor,
    );

    // 再起動しても標準色のまま
    final reopened = ThemeService();
    await reopened.init();
    expect(reopened.current.id, AppThemePreset.defaultLight.id);
    expect(reopened.current.textColor, AppThemePreset.defaultLight.textColor);
  });

  testWidgets('外観・テーマ：右上に同じ復旧ボタンを置き、確認で標準へ戻す', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
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
    final service = tester
        .element(find.byType(ThemeSettingsScreen))
        .read<ThemeService>();
    service.restoreCurrent(unreadable);
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ja'));
    // 狭幅ではラベルを省いたアイコンのみのボタンになるが、
    // ボタンとしてのSemantics、判定・確認・復旧の動作は同一。
    final button = find.byType(ThemeRescueButton);
    expect(button, findsOneWidget);
    expect(tester.widget<ThemeRescueButton>(button).iconOnly, isTrue);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(l10n.themeResetConfirmTitle), findsOneWidget);
    expect(service.current.id, unreadable.id);

    await tester.tap(find.text(l10n.themeResetConfirmAction));
    await tester.pumpAndSettle();
    expect(service.current.id, AppThemePreset.defaultLight.id);
    expect(button, findsNothing);
  });

  test('引き継いだ詰みテーマも勝手に補正・拒否されず復元できる', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_current_json',
      jsonEncode(unreadable.toJson()),
    );
    final restored = ThemeService();
    await restored.init();
    expect(restored.current.textColor, unreadable.textColor);
    expect(isThemeAtLockoutRisk(restored.current), isTrue);
  });
}

Future<Widget> _splashApp(WidgetTester tester, ThemeService service) async {
  final projects = ProjectService();
  await tester.runAsync(projects.init);
  // 起動画面はPC（DeX等）かどうかで並びの大きさを変えるので設定も読む。
  final settings = SettingsService();
  await tester.runAsync(settings.init);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeService>.value(value: service),
      ChangeNotifierProvider<ProjectService>.value(value: projects),
      ChangeNotifierProvider<SettingsService>.value(value: settings),
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
