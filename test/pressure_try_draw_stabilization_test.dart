// ペン入力設定の試し書き欄にも、手ぶれ補正をキャンバスと同じ式でかける。
//
// 実際に使ってみたとき（2026-11-27）、手ぶれ補正を0／50／100に変えても試し書き
// 欄の線が変わらなかった（キャンバスでは効いていた）。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/widgets/pressure_curve_try_draw.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> rightmostInk(WidgetTester tester, int strength) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await tester.runAsync(settings.init);
    await tester.runAsync(() => settings.setStrokeStabilization(strength));
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: RepaintBoundary(
                  key: boundary,
                  child: const PressureCurveTryDraw(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final paper = tester.getRect(
      find
          .descendant(
            of: find.byType(PressureCurveTryDraw),
            matching: find.byType(CustomPaint),
          )
          .last,
    );
    final gesture = await tester.startGesture(
      paper.centerLeft + const Offset(20, 0),
    );
    await gesture.moveTo(paper.centerLeft + const Offset(260, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final image = (await tester.runAsync(
      () =>
          (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(),
    ))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final origin = tester.getTopLeft(find.byKey(boundary));
    final y = (paper.center.dy - origin.dy).round();
    final x0 = (paper.left - origin.dx).round() + 4;
    final x1 = (paper.right - origin.dx).round() - 4;
    int pixel(int x) => data.getUint32((y * image.width + x) * 4);
    final paperColour = pixel(x0);
    var right = -1;
    for (var x = x0; x < x1; x++) {
      if (pixel(x) != paperColour) right = x;
    }
    image.dispose();
    settings.dispose();
    return right - x0;
  }

  testWidgets('the try-draw line follows the stabilization strength', (
    tester,
  ) async {
    final loose = await rightmostInk(tester, 0);
    final steady = await rightmostInk(tester, 100);
    expect(loose, greaterThan(240), reason: 'no smoothing: to the pointer');
    expect(steady, lessThan(loose - 100), reason: 'smoothed: trails behind');
  });
}
