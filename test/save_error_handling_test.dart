// 「保存が失敗しても何も起きない／画面が壊れる」状態を防ぐ仕組みの
// リグレッションテスト。
//
// 【経緯】「セーブツリーから保存するボタンをタップすると画面が真っ白に
// なる」という報告に対し、保存処理そのものは再現しなかった一方で、
// (1) 保存処理にtry/catchが無く失敗しても画面に何も出ない、
// (2) アプリにErrorWidget.builder・FlutterError.onErrorが未設定で、
//     リリースビルドでは描画中の例外が「文字の無い空白ボックス」になり
//     ユーザーにも開発側にも手がかりが残らない、
// という2点が判明したため、その両方を固定する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/app_error_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('描画中に例外が出ても空白にならず、内容が画面に表示される',
      (WidgetTester tester) async {
    final originalBuilder = ErrorWidget.builder;
    final originalOnError = FlutterError.onError;
    AppErrorReporter.install();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => throw StateError('セーブツリー保存の再現用エラー'),
        ),
      ),
    );
    // 例外そのものはテスト側で消費する（この検証の対象ではない）。
    tester.takeException();

    // 既定のErrorWidgetは文字が出ないが、置き換え後は説明文と
    // エラー内容が画面に出ていること。
    final foundHeading = find.textContaining('エラーが発生しました');
    final foundDetail = find.textContaining('セーブツリー保存の再現用エラー');
    final headingCount = foundHeading.evaluate().length;
    final detailCount = foundDetail.evaluate().length;

    // flutter_testはテスト本体を抜ける前にErrorWidget.builderが元へ
    // 戻っていることを検証するため、expectより先に必ず復帰させる。
    ErrorWidget.builder = originalBuilder;
    FlutterError.onError = originalOnError;

    expect(headingCount, 1, reason: '説明文が表示されていない');
    expect(detailCount, 1, reason: 'エラー内容が表示されていない');
  });

  test('捕捉したエラーが記録され、件数が無制限に増えない', () {
    AppErrorReporter.recentErrors.clear();
    for (var i = 0; i < 30; i++) {
      AppErrorReporter.record(StateError('エラー$i'), StackTrace.current);
    }
    expect(AppErrorReporter.recentErrors.length, lessThanOrEqualTo(20));
    // 最新のものが先頭に来ていること。
    expect(AppErrorReporter.recentErrors.first, contains('エラー29'));
  });
}

