import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// DISC098の新しい文（フォルダをゴミ箱へ移す確かめの注意・容量削減で
/// ゴミ箱を空にしなかった知らせ）が、7言語×幅320・360・1280×文字の倍率
/// 1.0・2.0ではみ出さず、最後まで読める。
void main() {
  testWidgets('the new trash notices fit every locale, width and text size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final message =
          '${l10n.homeMoveToTrashConfirm(1)}\n'
          '${l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(3, 2))}\n'
          '${l10n.homeMoveToTrashUnreadNote}';
      final notice = l10n.storageEmptyTrashKeptUnreadFolders(
        l10n.communityRetry,
      );
      for (final size in const [
        Size(320, 640),
        Size(360, 800),
        Size(1280, 800),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          final where =
              '${locale.toLanguageTag()} ${size.width.toInt()} x$scale';
          tester.view.physicalSize = size;
          final messengerKey = GlobalKey<ScaffoldMessengerState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.themeData,
              locale: locale,
              scaffoldMessengerKey: messengerKey,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(body: SizedBox.expand()),
            ),
          );
          final context = tester.element(find.byType(Scaffold));
          showDialog<void>(
            context: context,
            builder: (_) => ProjectTrashDialog(
              title: l10n.homeMoveToTrash,
              message: message,
              confirmLabel: l10n.commonMove,
              itemNames: const ['旅行'],
              onApply: () async {},
            ),
          );
          await tester.pumpAndSettle();
          var error = tester.takeException();
          if (error != null) problems.add('$where dialog: $error');
          final text = find.text(message);
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          final rect = tester.getRect(text);
          if (rect.bottom > size.height || rect.top < 0) {
            problems.add('$where dialog text off screen: $rect');
          }
          Navigator.of(tester.element(text)).pop();
          await tester.pumpAndSettle();
          messengerKey.currentState!.showSnackBar(
            SnackBar(content: Text(notice)),
          );
          await tester.pump(const Duration(milliseconds: 600));
          error = tester.takeException();
          if (error != null) problems.add('$where snack: $error');
          final snack = tester.getRect(find.text(notice));
          if (snack.bottom > size.height || snack.top < 0) {
            problems.add('$where snack text off screen: $snack');
          }
          messengerKey.currentState!.removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
