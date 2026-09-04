import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/gesture_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ジェスチャー割り当ての選択シートが、**選択肢を全部出せる**ことを検証する。
///
/// 選択肢は既定で9件あり1件あたり約56dpなので約504dp必要になる。一方
/// `showModalBottomSheet`は既定で画面高の9/16（360x760の端末で約427dp）
/// までしか高さを取らないため、スクロールできないColumnのままだと
/// RenderFlexがオーバーフローし、下の選択肢が縞模様で潰れて選べなくなる。
///
/// `test/dialog_screenshot_audit_test.dart`が実画面を焼いたときに
/// 「A RenderFlex overflowed by 77 pixels on the bottom.」で発覚した。
void main() {
  testWidgets('ジェスチャー選択シートがオーバーフローせず全選択肢へ到達できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GestureSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 「2本指タップ」の行を開く（選択肢がいちばん多い既定リストを使う行）。
    final row = find.text('2本指タップ');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    // オーバーフローはpump時の例外として現れる。
    expect(
      tester.takeException(),
      isNull,
      reason: 'シートを開いた時点でレイアウト例外（オーバーフロー）が出ている',
    );

    // 先頭の選択肢は見えている（表示名は訳文。以前ここだけ英語の
    // 'Undo'を直書きしていたのを、l10n経由へ直した）。
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(find.text(l10n.gestureActionUndo), findsWidgets);

    // 最後の選択肢まで実際にスクロールして到達できる
    // （オーバーフローで潰れていると到達できない）。
    await tester.scrollUntilVisible(
      find.text(l10n.gestureActionNone),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(l10n.gestureActionNone), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
