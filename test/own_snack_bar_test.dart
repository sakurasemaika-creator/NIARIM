// 自分の知らせだけを置き換える（`showOwnSnackBar`）。
//
// 設定の「機能の説明をもう一度表示」・エラーの記録の「コピー」は、前の知らせを
// `hideCurrentSnackBar`で閉じてから出していた。知らせはアプリ全体の
// メッセンジャーが画面をまたいで出すので、ホームでゴミ箱へ移した直後に
// 設定でこれを押すと、ゴミ箱の「元に戻す」の知らせが消えた。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/app_toast_messenger.dart';

void main() {
  Widget app(GlobalKey<ScaffoldMessengerState> messengerKey) => MaterialApp(
    builder: (context, child) =>
        AppToastMessenger(key: messengerKey, child: child!),
    home: const Scaffold(body: Center(child: Text('page'))),
  );

  BuildContext page(WidgetTester tester) => tester.element(find.text('page'));

  testWidgets('another feature’s notice stays; the own notice is replaced', (
    tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(app(messengerKey));

    // ホームでゴミ箱へ移した知らせ（元に戻す）。
    messengerKey.currentState!.showSnackBar(
      SnackBar(
        content: const Text('Moved to the trash'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        persist: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 設定で2回押す。
    for (var i = 0; i < 2; i++) {
      showOwnSnackBar(
        page(tester),
        SnackBar(
          key: const ValueKey('settingsTipsResetNotice'),
          content: Text('Tips will show again $i'),
        ),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Moved to the trash'),
      findsOneWidget,
      reason: 'the settings notice closed the trash notice and its Undo',
    );
    expect(find.text('Undo'), findsOneWidget);

    // ゴミ箱の知らせが消えた後は、2回目の自分の知らせだけが出る
    // （1回目は取り下げられて重ならない）。
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tips will show again 1'), findsOneWidget);
    expect(find.text('Tips will show again 0'), findsNothing);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Tips will show again 0'), findsNothing);
  });

  test('these screens close only their own notices', () {
    for (final path in [
      'lib/screens/settings/settings_screen.dart',
      'lib/screens/settings/error_log_screen.dart',
      'lib/widgets/startup_failure_app.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('hideCurrentSnackBar()') ||
            source.contains('removeCurrentSnackBar()') ||
            source.contains('clearSnackBars()'),
        isFalse,
        reason: '$path closes notices it did not show',
      );
    }
  });
}
