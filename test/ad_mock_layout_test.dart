import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/ad_banner_mock_widget.dart';
import 'package:niarim/widgets/progress_dialog.dart';

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('ja'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

void main() {
  testWidgets('横長広告はSafeArea内の画面最上部に固定され操作領域と離れる', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: AdMockPageFrame(
            child: Scaffold(
              appBar: AppBar(key: const Key('page-app-bar')),
              body: const Center(child: Text('page')),
            ),
          ),
        ),
      ),
    );

    final bannerRect = tester.getRect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
    );
    final appBarRect = tester.getRect(find.byKey(const Key('page-app-bar')));

    expect(bannerRect.top, greaterThanOrEqualTo(24 + 8));
    expect(bannerRect.height, 50);
    expect(appBarRect.top - bannerRect.bottom, greaterThanOrEqualTo(16));
    expect(bannerRect.bottom, lessThan(appBarRect.top));
  });

  testWidgets('処理中の正方形広告は注記より下にありダイアログ幅からはみ出さない', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: Center(
            child: ProgressDialog(
              title: '処理中',
              progress: 0.5,
              cancelHint: 'キャンセルに関する注記',
              onCancel: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('square-ad-mock')));
    await tester.pump();

    final squareRect = tester.getRect(find.byKey(const Key('square-ad-mock')));
    final hintRect = tester.getRect(find.text('キャンセルに関する注記'));
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    final cancelRect = tester.getRect(find.text('キャンセル'));

    expect(squareRect.top, greaterThan(hintRect.bottom));
    expect(squareRect.width, squareRect.height);
    expect(squareRect.left, greaterThanOrEqualTo(dialogRect.left));
    expect(squareRect.right, lessThanOrEqualTo(dialogRect.right));
    expect(cancelRect.top, greaterThan(squareRect.bottom));

    // ProgressDialogの定期Timerを確実に破棄する。
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MaterialPageRouteで開く画面にも横長広告フレームが付く', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                adMockMaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('next page')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('next page'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsOneWidget,
    );
  });
}

void _noop() {}
