import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/export_share_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/exported_work_name.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var fontsLoaded = false;
  var calls = 0;
  Object? failure;
  var nativeResult = '';
  Completer<String>? pending;
  final requests = <Map<dynamic, dynamic>>[];

  Future<({File file, AppLocalizations l10n})> open(
    WidgetTester tester, {
    String language = 'en',
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    calls = 0;
    failure = PlatformException(code: 'audit_share_denied');
    pending = null;
    nativeResult = '';
    requests.clear();
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      'force_pc_mode': size.width >= 1000 ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync(
      'export-share-audit-',
    );
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method != 'share') throw StateError('Unexpected share method');
      calls++;
      requests.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      if (pending != null) return pending!.future;
      if (failure != null) throw failure!;
      return nativeResult; // Controlled native status; no external send.
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/exports/AUDIT_share.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(img.Image(width: 32, height: 18)));
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await tester.pumpAndSettle();
    return (
      file: file,
      l10n: AppLocalizations.of(tester.element(find.byType(HomeScreen)))!,
    );
  }

  Future<void> share(WidgetTester tester, Finder control) async {
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
  }

  for (final preview in [false, true]) {
    testWidgets(
      'the share notice follows the menu text colour set in appearance '
      '(${preview ? 'preview' : 'row'})',
      (tester) async {
        final env = await open(tester);
        final themes = tester
            .element(find.byType(HomeScreen))
            .read<ThemeService>();
        // A menu text colour unlike the body text and unlike Material's
        // error colour: the notice must take this one.
        const menuText = Color(0xFF0B6E4F);
        expect(themes.current.textColor, isNot(menuText));
        themes.previewCurrent(themes.current.copyWith(menuTextColor: menuText));
        await tester.pumpAndSettle();
        failure = MissingPluginException('Synthetic unsupported share');
        if (preview) {
          await tester.tap(findExportedWorkName('AUDIT_share.png'));
          await pumpRealAsync(tester, const Duration(milliseconds: 200));
          await share(
            tester,
            find.widgetWithText(TextButton, env.l10n.homeShareOpenWith),
          );
        } else {
          await share(
            tester,
            find.byTooltip('${env.l10n.homeShareOpenWith}: AUDIT_share.png'),
          );
        }
        final notice = find.text(env.l10n.communityErrorUnsupported);
        expect(notice, findsOneWidget);
        final scheme = Theme.of(tester.element(notice)).colorScheme;
        expect(scheme.error, isNot(menuText));
        expect(tester.widget<Text>(notice).style?.color, menuText);
        // Not by colour alone: an icon marks the line as a notice.
        final line = find.ancestor(
          of: notice,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        );
        final icon = find.descendant(
          of: line.first,
          matching: find.byIcon(Icons.error_outline),
        );
        expect(icon, findsOneWidget);
        expect(
          tester.widget<Icon>(icon).color ??
              IconTheme.of(tester.element(icon)).color,
          menuText,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final preview in [false, true]) {
    testWidgets(
      '${preview ? 'preview' : 'Works row'} share failure stays visible and keeps the file',
      (tester) async {
        final env = await open(tester);
        final before = env.file.readAsBytesSync();
        if (preview) {
          await tester.tap(findExportedWorkName('AUDIT_share.png'));
          await pumpRealAsync(tester, const Duration(milliseconds: 200));
        }
        final control = preview
            ? find.widgetWithText(TextButton, env.l10n.homeShareOpenWith)
            : find.byTooltip('${env.l10n.homeShareOpenWith}: AUDIT_share.png');
        await share(tester, control);
        expect(tester.takeException(), isNull);
        expect(calls, 1);
        expect(find.text(env.l10n.communityErrorGeneric), findsOneWidget);
        if (preview) {
          expect(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.text(env.l10n.communityErrorGeneric),
            ),
            findsOneWidget,
            reason: 'Feedback must appear above the modal barrier',
          );
        }
        expect(env.file.readAsBytesSync(), before);
      },
    );
  }

  void expectOriginInside(Map<dynamic, dynamic> request, Size size) {
    for (final name in ['originX', 'originY', 'originWidth', 'originHeight']) {
      expect(request[name], isA<num>(), reason: '$name must be supplied');
    }
    expect(request['originWidth'], greaterThan(0));
    expect(request['originHeight'], greaterThan(0));
    expect(request['originX'], inInclusiveRange(0, size.width));
    expect(request['originY'], inInclusiveRange(0, size.height));
    expect(
      request['originX'] + request['originWidth'],
      lessThanOrEqualTo(size.width + 1),
    );
    expect(
      request['originY'] + request['originHeight'],
      lessThanOrEqualTo(size.height + 1),
    );
  }

  testWidgets(
    'row share disables repeated share, opening and delete until native dismissal',
    (tester) async {
      final env = await open(tester);
      final before = env.file.readAsBytesSync();
      failure = null;
      pending = Completer<String>();
      final control = find.byTooltip(
        '${env.l10n.homeShareOpenWith}: AUDIT_share.png',
      );
      await share(tester, control);
      expect(calls, 1);
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(of: control, matching: find.byType(IconButton))
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip(
                      '${env.l10n.commonDelete}: AUDIT_share.png',
                    ),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(control);
      await tester.tap(findExportedWorkName('AUDIT_share.png'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(env.file.readAsBytesSync(), before);
      pending!.complete('');
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(of: control, matching: find.byType(IconButton))
                  .first,
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text(env.l10n.communityErrorGeneric), findsNothing);
      expectOriginInside(requests.single, const Size(390, 844));
      expect(requests.single['paths'], [env.file.path]);
      pending = null;
      await share(tester, control);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
      expect(env.file.readAsBytesSync(), before);
    },
  );

  testWidgets(
    'pending preview can close and a late native failure cannot touch the disposed view',
    (tester) async {
      final env = await open(tester);
      final before = env.file.readAsBytesSync();
      await tester.tap(findExportedWorkName('AUDIT_share.png'));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      pending = Completer<String>();
      await share(
        tester,
        find.widgetWithText(TextButton, env.l10n.homeShareOpenWith),
      );
      expect(calls, 1);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, env.l10n.homeShareOpenWith),
            )
            .onPressed,
        isNull,
      );
      final close = find.widgetWithText(TextButton, env.l10n.commonClose);
      expect(tester.widget<TextButton>(close).onPressed, isNotNull);
      await tester.ensureVisible(close);
      await tester.pump();
      await tester.tap(close);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsNothing);
      pending!.completeError(
        PlatformException(code: 'audit_late_share_failure'),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text(env.l10n.communityErrorGeneric), findsNothing);
      expect(env.file.readAsBytesSync(), before);
      pending = null;
      failure = null;
      await share(
        tester,
        find.byTooltip('${env.l10n.homeShareOpenWith}: AUDIT_share.png'),
      );
      expect(
        calls,
        2,
        reason: 'The failed native operation must release the per-file gate',
      );
    },
  );

  testWidgets(
    'unsupported preview sharing remains readable, then dismissal and a controlled status clear the error',
    (tester) async {
      final env = await open(tester);
      final before = env.file.readAsBytesSync();
      failure = MissingPluginException(
        'Synthetic native file share unavailable',
      );
      await tester.tap(findExportedWorkName('AUDIT_share.png'));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      final control = find.widgetWithText(
        TextButton,
        env.l10n.homeShareOpenWith,
      );
      await share(tester, control);
      final error = find.text(env.l10n.communityErrorUnsupported);
      expect(error, findsOneWidget);
      final live = find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(live, findsWidgets);
      final theme = Theme.of(tester.element(error));
      expect(
        tester.widget<Text>(error).style?.color,
        theme.popupMenuTheme.textStyle?.color,
        reason: 'the notice uses the menu text colour chosen in appearance',
      );
      expect(find.text(env.l10n.communityErrorGeneric), findsNothing);
      expectOriginInside(requests.single, const Size(390, 844));
      final image = tester.widget<RawImage>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(RawImage),
        ),
      );
      expect(image.image?.width, 32);
      expect(image.image?.height, 18);
      failure = null;
      await share(tester, control);
      expect(calls, 2);
      expect(error, findsNothing);
      nativeResult = 'audit.synthetic.status';
      await share(tester, control);
      expect(calls, 3);
      expect(error, findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      expect(env.file.readAsBytesSync(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'share feedback and Close remain reachable in 21 locale and layout profiles',
    (tester) async {
      var profiles = 0;
      for (final language in ['ja', 'en', 'fr', 'es', 'ko', 'zh', 'zh_Hant']) {
        for (final (size, scale) in [
          (const Size(320, 844), 2.0),
          (const Size(390, 220), 2.0),
          (const Size(1440, 900), 1.0),
        ]) {
          final env = await open(
            tester,
            language: language,
            size: size,
            scale: scale,
          );
          final before = env.file.readAsBytesSync();
          failure = MissingPluginException('Synthetic unsupported share');
          await share(
            tester,
            find.byTooltip('${env.l10n.homeShareOpenWith}: AUDIT_share.png'),
          );
          expect(find.text(env.l10n.communityErrorUnsupported), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$language/$size/row');
          final name = findExportedWorkName('AUDIT_share.png');
          await tester.ensureVisible(name);
          await tester.pumpAndSettle();
          await tester.tap(name);
          await pumpRealAsync(tester, const Duration(milliseconds: 200));
          await share(
            tester,
            find.widgetWithText(TextButton, env.l10n.homeShareOpenWith),
          );
          final error = find.descendant(
            of: find.byType(Dialog),
            matching: find.text(env.l10n.communityErrorUnsupported),
          );
          expect(error, findsOneWidget);
          await tester.ensureVisible(error);
          await tester.pumpAndSettle();
          expect(tester.getCenter(error).dy, inInclusiveRange(0, size.height));
          expect(
            tester.takeException(),
            isNull,
            reason: '$language/$size/preview',
          );
          final close = find.widgetWithText(TextButton, env.l10n.commonClose);
          await tester.ensureVisible(close);
          await tester.pumpAndSettle();
          expect(close.hitTestable(), findsOneWidget);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          expect(env.file.readAsBytesSync(), before);
          expect(calls, 2);
          profiles++;
        }
      }
      expect(profiles, 21);
    },
  );

  testWidgets(
    'overlapping callers for one file share the same pending native operation',
    (tester) async {
      final env = await open(tester);
      final before = env.file.readAsBytesSync();
      pending = Completer<String>();
      final first = ExportShareService.share(
        env.file,
        origin: const Rect.fromLTWH(1, 2, 30, 40),
      );
      final second = ExportShareService.share(
        File(env.file.path),
        origin: const Rect.fromLTWH(5, 6, 70, 80),
      );
      expect(identical(first, second), isTrue);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(calls, 1);
      expect(requests.single['originX'], 1);
      pending!.complete('');
      await tester.pump();
      final result = await tester.runAsync(() => first);
      expect(result!.status, ShareResultStatus.dismissed);
      expect(env.file.readAsBytesSync(), before);
      pending = null;
      failure = null;
      final retry = ExportShareService.share(
        env.file,
        origin: const Rect.fromLTWH(3, 4, 50, 60),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(
        (await tester.runAsync(() => retry))!.status,
        ShareResultStatus.dismissed,
      );
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline share feedback cannot dismiss an unrelated Undo when retrying',
    (tester) async {
      final env = await open(tester);
      final control = find.byTooltip(
        '${env.l10n.homeShareOpenWith}: AUDIT_share.png',
      );
      await share(tester, control);
      expect(find.text(env.l10n.communityErrorGeneric), findsOneWidget);
      var undone = false;
      ScaffoldMessenger.of(
        tester.element(find.byType(HomeScreen)),
      ).showSnackBar(
        SnackBar(
          content: const Text('AUDIT unrelated action'),
          action: SnackBarAction(
            label: 'AUDIT Undo',
            onPressed: () => undone = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AUDIT unrelated action'), findsOneWidget);
      failure = null;
      await share(tester, control);
      expect(find.text('AUDIT unrelated action'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('AUDIT Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(calls, 2);
    },
  );
}
