// 投げ縄塗りの「囲って塗る」は、バケツの長押しから開く投げ縄塗りのシートで
// 切り替える。切り替えてもシートは閉じない。
//
// 所有者の判断（2026-11-27、案C）：以前はこのスイッチとテキストツールのヒント
// （「キャンバスをタップしてテキストを入力」）を上部バーに出していて、狭い画面では
// バーが2段になり、ツールを替えるたびに紙が上下にずれた。ヒントは出さない。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the lasso fill sheet switches 囲って塗る and stays open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    late ToneService tones;
    var closed = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  tones = context.read<ToneService>();
                  return SizedBox(
                    height: 500,
                    child: LassoFillToneSheet(onClose: () => closed++),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final toggle = find.byKey(const Key('lassoFillEnclosedSwitch'));
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(
        of: toggle,
        matching: find.text(l10n.canvasLassoEnclosedLabel),
      ),
      findsOneWidget,
    );
    expect(tones.lassoEnclosed, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(tones.lassoEnclosed, isTrue);
    expect(closed, 0, reason: 'switching keeps the sheet open');
    await tester.tap(toggle);
    await tester.pump();
    expect(tones.lassoEnclosed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
