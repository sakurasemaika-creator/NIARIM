import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/home_app_harness.dart';

/// プロジェクトタブで選んだ並び順（名前／更新日時・昇順／降順）は、起動し
/// 直しても引き継ぐ（以前は毎回「更新日時の新しい順」に戻っていた）。
/// 設定の引き継ぎ（.niatra）にも設定として入る。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  const key = 'home.projectSortMode.v1';

  testWidgets('the chosen sort survives a restart', (tester) async {
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'detail'},
    );
    await home.open(
      seed: (service) async {
        for (final name in ['作品2', '作品10', '作品1']) {
          await HomeAppHarness.work(service, name);
        }
      },
    );
    expect(home.shownNames(), ['作品1', '作品10', '作品2']);
    // 名前を選ぶ（降順のまま）。
    await tester.tap(find.byTooltip(ja.homeSortFieldUpdated).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.homeSortFieldName).last);
    await tester.pumpAndSettle();
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getString(key), 'nameDesc');
    // 昇順へ。
    await tester.tap(find.byTooltip(ja.homeSortDirectionDescTooltip).first);
    await tester.pumpAndSettle();
    expect(prefs.getString(key), 'nameAsc');
    final shown = home.shownNames();

    // 起動し直す。
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await home.settle();
    expect(find.byTooltip(ja.homeSortFieldName), findsWidgets);
    expect(find.byTooltip(ja.homeSortDirectionAscTooltip), findsWidgets);
    expect(home.shownNames(), shown);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a broken saved sort falls back to the newest first', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'detail', key: 'sideways'},
    );
    await home.open(
      seed: (service) async {
        for (final name in ['a', 'b']) {
          await HomeAppHarness.work(service, name);
        }
      },
    );
    expect(find.byTooltip(ja.homeSortFieldUpdated), findsWidgets);
    expect(home.shownNames(), ['b', 'a']);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  test('the sort is carried by the settings transfer', () {
    expect(NiatraSerializer.settingKeys, contains(key));
    expect(NiatraSerializer.deviceRecordKeys, isNot(contains(key)));
  });
}
