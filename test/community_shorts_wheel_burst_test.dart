import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';

/// 縦画面モードはマウスのホイールで次・前の作品へ送る。続けて回しても
/// （1つ送っている間に次のホイールが届いても）送りが止まって元の作品へ
/// 戻らない（利用者の動きで見つかったこと：1回ずつなら進むが、続けて
/// 回すと1つも進まなかった。送る間はページに触れられず、その間のホイールを
/// PageView自身が受けて送りを止め、53pxだけ動かしてから元のページへ
/// 戻していた）。
void main() {
  testWidgets('a quick run of wheel notches steps one work at a time', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final community = CommunityService();
    addTearDown(community.dispose);
    final works = community.discoverableWorks.take(6).toList();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: community,
        child: MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityShortsScreen(
            works: works,
            bookmarkedIds: const {},
            onToggleBookmark: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(
          find.byWidgetPredicate(
            (w) => w is PageView && w.scrollDirection == Axis.vertical,
          ),
        )
        .controller!;
    int page() => controller.page!.round();

    // 50msおきのホイール（xdotoolで回したときと同じ間隔）。
    Future<void> wheel(int notches, {double dy = 53}) async {
      for (var i = 0; i < notches; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: const Offset(206, 390),
            scrollDelta: Offset(0, dy),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    expect(page(), 0);
    await wheel(2);
    expect(page(), 1, reason: 'the second notch must not undo the first');
    await wheel(3);
    expect(page(), 2);
    // 送り終えた後のホイールは、また1つ送る。
    await wheel(1);
    expect(page(), 3);
    await wheel(2, dy: -53);
    expect(page(), 2);
    // 1つ送っている途中に押したキーも、送りを止めない。
    await wheel(1);
    expect(page(), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: const Offset(206, 390),
        scrollDelta: const Offset(0, 53),
      ),
    );
    await tester.pumpAndSettle();
    expect(page(), 4);
    // 一番最後で回しても先へは行かない。
    await wheel(1);
    expect(page(), 5);
    await wheel(2);
    expect(page(), 5);
    expect(
      controller.position.pixels % controller.position.viewportDimension,
      moreOrLessEquals(0),
    );
    expect(tester.takeException(), isNull);
  });
}
