import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 差し色を下地に塗る所（ホームのボタン・メニューの見出し・使い方の番号と
/// ボタン）の文字・アイコンは、テーマ・外観の「ボタン内の文字・アイコン色」。
/// 以前は差し色から自動で作った色（onPrimary）で、既定の差し色では白地の
/// 読みにくい組み合わせになっていた（DISC005）。差し色・ボタンの文字色とも
/// 既定と違う色にしたテーマで、どの場所も選んだ色で描かれることを見張る。
void main() {
  final preset = AppThemePreset.defaultLight.copyWith(
    id: 'custom_fill_roles',
    accentColor: const Color(0xFF2E6B5E),
    buttonTextColor: const Color(0xFFFFF0B8),
  );

  Future<AppLocalizations> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'theme_current_json': jsonEncode(preset.toJson()),
    });
    final dir = Directory.systemTemp.createTempSync('accent-fill-roles-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
  }

  Color? paintedColor(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text).text.style?.color;

  testWidgets('accent fills draw with the chosen button text colour', (
    tester,
  ) async {
    final l10n = await open(tester);
    final ink = preset.buttonTextColor;

    // ホームの左下・右下の丸いボタン。
    for (final fab in tester.widgetList<FloatingActionButton>(
      find.byType(FloatingActionButton),
    )) {
      expect(fab.backgroundColor, preset.accentColor);
      expect(fab.foregroundColor, ink);
    }
    final add = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byIcon(Icons.add),
    );
    expect(
      IconTheme.of(tester.element(add)).color ?? tester.widget<Icon>(add).color,
      ink,
    );

    // メニュー（引き出し）の見出し。
    tester
        .state<ScaffoldState>(
          find
              .descendant(
                of: find.byType(HomeScreen),
                matching: find.byType(Scaffold),
              )
              .first,
        )
        .openDrawer();
    await tester.pumpAndSettle();
    expect(paintedColor(tester, find.text('NIARIM')), ink);
    expect(paintedColor(tester, find.text(l10n.homeDrawerAppTagline)), ink);

    // 使い方：番号の丸と「次へ」。
    await tester.tap(find.byKey(const Key('homeDrawerTutorial')));
    await tester.pumpAndSettle();
    final badge = find.descendant(
      of: find.byKey(const Key('tutorialPages')),
      matching: find.text('1'),
    );
    expect(badge, findsWidgets);
    for (final element in badge.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.text.style?.color, ink);
    }
    expect(paintedColor(tester, find.text(l10n.tutorialNext)), ink);
    await tester.tap(find.byKey(const Key('tutorialSkip')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
