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

/// テーマ・外観設定で「文字色と背景色を同じ色にしてしまい、画面が読めなく
/// なって元に戻せない」状態（詰み）を防ぐ2段構えの仕組みを検証する。
///
/// 1. テーマ・外観設定では、その組み合わせを保存させない
/// 2. それでも読めないテーマになったときは、起動画面に固定色のリセット
///    ボタンを出す（引き継ぎファイルの取り込み等、1をすり抜ける経路がある）
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

  group('コントラスト判定', () {
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
          isThemeReadable(preset),
          isTrue,
          reason:
              '組み込みテーマ「${preset.name}」が弾かれている。'
              'しきい値$kMinReadableContrastが厳しすぎる',
        );
      }
    });

    test('同じ色・ほとんど同じ色のテーマは弾かれる', () {
      expect(isThemeReadable(unreadable), isFalse);
      expect(
        isThemeReadable(
          unreadable.copyWith(textColor: const Color(0xFF3A6FA0)),
        ),
        isFalse,
        reason: '見分けがつかないほど近い色も弾く',
      );
    });
  });

  testWidgets('テーマ設定：読めなくなる色は保存されず、元の配色へ戻る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    // ThemeSettingsScreenはSettingsService等も読むので、本番と同じ
    // Provider一式を立てる。
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

    // 「文字色」の行をタップしてカラーピッカーを開く。
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.tap(find.text(l10n.themeColorText));
    await tester.pumpAndSettle();

    // ピッカーの中身を触る代わりに、ドラッグ中と同じ経路
    // （previewCurrent）で背景と同じ色まで持っていく。
    service.previewCurrent(
      service.current.copyWith(textColor: before.panelBgColor),
    );
    await tester.pumpAndSettle();

    // 閉じる＝確定。読めない組み合わせなので保存されず、理由が出る。
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.themeContrastErrorTitle), findsOneWidget);
    expect(service.current.textColor, before.textColor, reason: '元の文字色へ戻る');
    expect(isThemeReadable(service.current), isTrue);
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
    // 引き継ぎファイルの取り込み等で「詰みテーマ」が入ってしまった状態。
    service.savePreset(unreadable);
    service.applyPreset(unreadable.id);

    await tester.pumpWidget(await _splashApp(tester, service));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ja'));
    final resetButton = find.text(l10n.themeUnreadableResetButton);
    expect(resetButton, findsOneWidget);

    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(isThemeReadable(service.current), isTrue);
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
