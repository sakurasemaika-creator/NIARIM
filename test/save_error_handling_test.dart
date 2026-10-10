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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_error_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // installは1プロセスに1回しか効かない（多重ラップ防止）ため、入れた
  // ErrorWidget.builderを控えておき、各テストで使ってから元へ戻す。
  late ErrorWidgetBuilder installedBuilder;
  setUpAll(() {
    final originalBuilder = ErrorWidget.builder;
    final originalOnError = FlutterError.onError;
    AppErrorReporter.install();
    installedBuilder = ErrorWidget.builder;
    ErrorWidget.builder = originalBuilder;
    FlutterError.onError = originalOnError;
  });

  // エラー表示はアプリの表示言語（祖先のロケール）で出る。
  for (final locale in const [Locale('ja'), Locale('en')]) {
    testWidgets('描画中に例外が出ても空白にならず、内容が画面に表示される（$locale）', (
      WidgetTester tester,
    ) async {
      final originalBuilder = ErrorWidget.builder;
      ErrorWidget.builder = installedBuilder;

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => throw StateError('セーブツリー保存の再現用エラー'),
          ),
        ),
      );
      // 例外そのものはテスト側で消費する（この検証の対象ではない）。
      tester.takeException();

      // 既定のErrorWidgetは文字が出ないが、置き換え後は説明文と
      // エラー内容が画面に出ていること。
      final l10n = lookupAppLocalizations(locale);
      final headingCount = find.text(l10n.errorViewTitle).evaluate().length;
      final bodyCount = find.text(l10n.errorViewBody).evaluate().length;
      final detailCount = find
          .textContaining('セーブツリー保存の再現用エラー')
          .evaluate()
          .length;

      // flutter_testはテスト本体を抜ける前にErrorWidget.builderが元へ
      // 戻っていることを検証するため、expectより先に必ず復帰させる。
      ErrorWidget.builder = originalBuilder;

      expect(headingCount, 1, reason: '説明文の見出しが表示されていない');
      expect(bodyCount, 1, reason: '説明文が表示されていない');
      expect(detailCount, 1, reason: 'エラー内容が表示されていない');
    });
  }

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
