// メイキングの画面は、記録を読めなかったときに「この作品のメイキング記録は
// ありません」と言わない（読めていない間は「ありません」の文を出さない決まり）。
// 知らせと「再試行」を出し、読めたら本当の状態（ここでは記録なし）を出す。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/project/making_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/icon_notice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _paths = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  var unreadable = true;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('making_load_failure_');
    unreadable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, (_) async {
          if (unreadable) {
            throw PlatformException(code: 'storage_unavailable');
          }
          return temp.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  for (final locale in const [Locale('ja'), Locale('en'), Locale('fr')]) {
    testWidgets(
      'an unreadable history says so with a retry (${locale.languageCode})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themes = ThemeService();
        await tester.runAsync(themes.init);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: themes),
              ChangeNotifierProvider(create: (_) => ProjectService()),
            ],
            child: MaterialApp(
              theme: themes.themeData,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const MakingScreen(projectId: 'project_1'),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final l10n = lookupAppLocalizations(locale);

        expect(
          find.widgetWithText(IconNotice, l10n.makingLoadFailed),
          findsOneWidget,
        );
        expect(find.text(l10n.makingEmpty), findsNothing);
        expect(find.text(l10n.makingRecordProject), findsNothing);

        unreadable = false;
        await tester.tap(find.byKey(const Key('makingRetryLoadButton')));
        await tester.pump();
        // 読み直しはファイルを読むので、実際の時間で終わるのを待つ。
        for (var i = 0; i < 100; i++) {
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        expect(find.byType(IconNotice), findsNothing);
        expect(find.text(l10n.makingEmpty), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
