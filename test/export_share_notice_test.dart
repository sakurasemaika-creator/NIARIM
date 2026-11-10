import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/export_share_feedback.dart';

/// 書き出し完了の「共有」。共有できない端末・失敗を、未処理の例外にせず
/// 画面の通知で知らせる（以前は結果を待たずに呼び、Linuxでは
/// 「Sharing files not supported」が未処理の例外になった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Object? failure;
  var calls = 0;
  late Directory dir;
  late File file;

  setUp(() {
    failure = null;
    calls = 0;
    dir = Directory.systemTemp.createTempSync('niarim_export_share_');
    file = File('${dir.path}/out.gif')..writeAsBytesSync([1, 2, 3]);
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      calls++;
      if (failure != null) throw failure!;
      return 'audit.synthetic.status';
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(shareChannel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<AppLocalizations> pump(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: language == 'zh_Hant'
            ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
            : Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => shareExportedFileWithNotice(context, file),
                child: const Text('share'),
              ),
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.text('share')))!;
  }

  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('a device without file sharing is told so ($language)', (
      tester,
    ) async {
      final l10n = await pump(tester, language);
      final before = AppErrorReporter.recentErrors.length;
      failure = MissingPluginException('no share on this device');
      await tester.tap(find.text('share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '未処理の例外にしない');
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.communityErrorUnsupported),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('MissingPluginException'), findsNothing);
      expect(find.textContaining('no share on this device'), findsNothing);
      expect(AppErrorReporter.recentErrors.length, greaterThan(before));
      expect(file.readAsBytesSync(), [1, 2, 3], reason: 'ファイルは残る');
    });
  }

  testWidgets('another failure says so, and a success says nothing', (
    tester,
  ) async {
    final l10n = await pump(tester, 'en');
    failure = PlatformException(code: 'Share failed', message: 'native text');
    await tester.tap(find.text('share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.communityErrorGeneric), findsOneWidget);
    expect(find.textContaining('native text'), findsNothing);
    ScaffoldMessenger.of(tester.element(find.text('share'))).clearSnackBars();
    await tester.pumpAndSettle();

    failure = null;
    await tester.tap(find.text('share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 2);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen may be gone when the share fails', (tester) async {
    await pump(tester, 'ja');
    failure = MissingPluginException('late');
    await tester.tap(find.text('share'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  test('the export-complete dialog shares through the notice helper', () {
    final source = File(
      'lib/screens/export/export_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('SharePlus.instance')));
    expect(source, contains('shareExportedFileWithNotice(context'));
    // 作品一覧の行とプレビューも同じ文の決まりを使う。
    final home = File('lib/screens/home/home_screen.dart').readAsStringSync();
    expect(home, isNot(contains('SharePlus.instance')));
    expect(home, contains('exportShareFailureText('));
  });
}
