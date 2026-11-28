import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_header_quality_test.dart' as quality;

/// 作品広場の表示フィルターの投稿日「期間を指定」は今日までしか選べず、
/// カレンダーは今月を下端に、前の月をその上に出して開く（利用者の動きで
/// 見つかったこと：来年の末まで選べ、今月が一番上でその下に先の月が
/// 続いていた）。
void main() {
  testWidgets('the posting-date range ends today, latest month at the bottom', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final themes = ThemeService();
    await themes.init();
    final preview = CommunityPreviewService();
    final community = CommunityService();
    addTearDown(themes.dispose);
    addTearDown(preview.dispose);
    addTearDown(community.dispose);
    await tester.runAsync(() => community.contentFiltersReady);
    await tester.pumpWidget(
      quality.host(
        themes,
        community,
        preview,
        locale: const Locale('ja'),
        scale: 1,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityScreen)),
    )!;

    await tester.tap(find.byKey(const Key('communityContentFilterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityPostDateFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.communityPostPeriodCustom).last);
    await tester.pumpAndSettle();

    final picker = find.byType(DateRangePickerDialog);
    expect(picker, findsOneWidget);
    final today = DateUtils.dateOnly(DateTime.now());
    expect(tester.widget<DateRangePickerDialog>(picker).lastDate, today);

    // 月の一覧（今月より前の月が上に並ぶもの）は、今月が下端に来るように
    // 上へ送ってある。
    final months = find.descendant(
      of: picker,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    final position = [
      for (final e in months.evaluate())
        ((e as StatefulElement).state as ScrollableState).position,
    ].firstWhere((p) => p.minScrollExtent < 0);
    expect(position.pixels, lessThan(0));
    expect(position.pixels, greaterThanOrEqualTo(position.minScrollExtent));

    final localizations = MaterialLocalizations.of(tester.element(picker));
    final screen = tester.getRect(picker);
    final thisMonth = find.text(localizations.formatMonthYear(today));
    final lastMonth = find.text(
      localizations.formatMonthYear(DateTime(today.year, today.month - 1)),
    );
    expect(thisMonth, findsOneWidget);
    expect(lastMonth, findsOneWidget);
    expect(tester.getRect(lastMonth).top, greaterThan(screen.top));
    expect(
      tester.getRect(lastMonth).top,
      lessThan(tester.getRect(thisMonth).top),
    );
    // 来月は一覧に無い。
    expect(
      find.text(
        localizations.formatMonthYear(DateTime(today.year, today.month + 1)),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
