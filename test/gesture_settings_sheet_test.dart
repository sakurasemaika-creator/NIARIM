import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/gesture_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final row = find.text('2本指タップ');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'シートを開いた時点でレイアウト例外（オーバーフロー）が出ている',
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(find.text(l10n.gestureActionUndo), findsWidgets);

    // 画面本体のListViewではなく、モーダル内のSingleChildScrollViewを明示する。
    // Flutter 3.47ではScrollable一般のfinderを渡すと内部Scrollableも含んで
    // 複数一致し、dragUntilVisibleがStateErrorになるため、所有者を固定する。
    final sheetScroll = find.byType(SingleChildScrollView);
    expect(sheetScroll, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(l10n.gestureActionNone),
      120,
      scrollable: sheetScroll,
    );
    expect(find.text(l10n.gestureActionNone), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
