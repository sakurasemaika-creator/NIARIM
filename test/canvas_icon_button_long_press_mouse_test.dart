// 長押しで開く物があるツールバーのボタン（早替えツール）は、マウスの長押しと
// 右クリックでも開く。
//
// 実際に使ってみたとき（2026-11-27）、早替えツールの長押し（編集）が
// マウスでは効かなかった（吹き出しの長押しはタッチ・ペンだけで起きる）。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();

  testWidgets('long press opens with touch, mouse and right click', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final providers = (await tester.runAsync(buildAppProviders))!;
    var taps = 0;
    var opens = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: CanvasIconButton(
                icon: Icons.loop,
                onPressed: () => taps++,
                tooltip: 'quick',
                onTooltipLongPress: () => opens++,
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(CanvasIconButton);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 400));
    expect((taps, opens), (1, 0));

    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(opens, 1, reason: 'touch');

    await tester.longPress(button, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(opens, 2, reason: 'mouse');

    await tester.tap(
      button,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(opens, 3, reason: 'right click');
    expect(taps, 1);
  });
}
