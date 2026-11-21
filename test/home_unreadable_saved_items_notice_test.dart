import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/error_log_screen.dart';
import 'package:niarim/utils/saved_list_reader.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

/// 保存の中に読めない項目があると、起動してホームを開いたときに1回だけ
/// 知らせ、その操作で「エラーの記録」（読めない項目の説明つき）を開ける。
/// 元のデータは一覧に残っている（DISC070）。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an unreadable saved preset is announced once on Home', (
    tester,
  ) async {
    const broken = '{"id": "broken", "name": ';
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'workspace_presets': [broken],
    });
    SavedListCarryOver.reset();
    addTearDown(SavedListCarryOver.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(SavedListCarryOver.counts, {'workspace_presets': 1});
    appRouter.push('/home');
    await settle();
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final notice = find.byKey(const Key('homeUnreadableSavedItemsNotice'));
    expect(notice, findsOneWidget);
    expect(find.text(l10n.savedListUnreadableNotice(1)), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: notice,
        matching: find.text(l10n.settingsErrorLogTitle),
      ),
    );
    await settle();
    expect(find.byType(ErrorLogScreen), findsOneWidget);
    expect(
      find.byKey(const Key('errorLogUnreadableSavedItems')),
      findsOneWidget,
    );
    // 元のデータは保存に残っている。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('workspace_presets'), contains(broken));
    expect(tester.takeException(), isNull);
  });
}
