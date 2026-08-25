import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';

/// アプリを実際に起動し、主要画面を人手を介さず自動で巡回して、
/// 例外が発生しないことを確認するスモークテスト。
/// `main()`と同じ`buildAppProviders()`でサービス一式を初期化するため、
/// 起動時の配線ミス・providerの取り違え・画面遷移時の実行時エラーを
/// 見た目のチェックなしで検知できる。
///
/// `testWidgets`のテスト本体は既定でFlutterの仮想時計（fake clock）が
/// 支配するゾーンで動く。`buildAppProviders()`内部で使われる本物の
/// Timer/Future.delayed（プラグイン呼び出しの内部実装等）は、
/// `tester.pump()`で仮想時計を明示的に進めるまで発火しないため、
/// pumpWidget前にawaitすると永久にハングする。これを避けるため、
/// `tester.runAsync()`で本物の非同期ゾーンへ逃がしてから実行する。
///
/// 各ステップの後に`tester.takeException()`でFlutter側が捕捉した
/// 例外（レンダリングオーバーフロー・null参照・providerが見つからない
/// 等）が無いことを確認する。UIの見た目の良し悪しではなく、
/// 「クラッシュせずに動くか」を検証するためのテスト。
/// `pumpAndSettle()`は無限に繰り返すアニメーション・タイマーがあると
/// タイムアウトするため使わず、固定時間の`pump()`を都度呼ぶ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('起動→ホーム→設定→ショートカット設定まで例外なく遷移できる', (WidgetTester tester) async {
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '起動画面の描画で例外');

    // 起動画面の「アニメを作る」ボタンでホーム画面へ遷移する。
    final createButtonFinder = find.byIcon(Icons.brush_outlined);
    expect(createButtonFinder, findsOneWidget);
    await tester.tap(createButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ホーム画面への遷移で例外');
    expect(find.byType(Scaffold), findsWidgets);

    // 初回起動時の案内ダイアログ（「はじめる」ボタン）が出ていれば閉じる。
    final firstLaunchDialogButton = find.text('はじめる');
    if (firstLaunchDialogButton.evaluate().isNotEmpty) {
      await tester.tap(firstLaunchDialogButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '初回起動ダイアログを閉じる際に例外');
    }

    // ドロワーを開いて設定画面へ遷移する。
    final scaffoldState = tester.state<ScaffoldState>(
      find.byType(Scaffold).first,
    );
    scaffoldState.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ドロワー表示で例外');

    final settingsTileFinder = find.byIcon(Icons.settings_outlined);
    expect(settingsTileFinder, findsOneWidget);
    await tester.tap(settingsTileFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '設定画面への遷移で例外');

    // 設定一覧から、今回新設したショートカット設定画面まで開いてみる。
    final shortcutEntryFinder = find.byIcon(Icons.keyboard);
    if (shortcutEntryFinder.evaluate().isNotEmpty) {
      await tester.tap(shortcutEntryFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'ショートカット設定画面への遷移で例外');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
