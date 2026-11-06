import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 理由ごとの見出しと、本文・ボタン（無いものはnull）。
typedef Expected = ({
  String Function(AppLocalizations) title,
  String Function(AppLocalizations)? body,
  String Function(AppLocalizations)? reload,
});

/// ブクマ済みタブが空のとき、その理由（まだ何もブックマークしていない／
/// 保存はあるが表示フィルター等で見えない／ログインしていない／読み込む前／
/// 読み込み中／読み込めなかった）を、7言語・スマホとPC・文字の大きさ1倍と
/// 2倍のどれでも読み切れて、操作のボタンに届くこと。見ている間に保存済みの
/// ブックマークは変わらないこと。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const json = {'content-type': 'application/json; charset=utf-8'};

  CommunityService backend(MockClient client) => CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: client,
        tokenProvider: () async => 'isolated-token',
        maxGetRetries: 0,
      ),
    ),
  );

  http.Response social(http.Request r) => http.Response(
    r.url.path.endsWith('/bookmarks')
        ? '{"works":[]}'
        : r.url.path.endsWith('/following')
        ? '{"following":[]}'
        : '{"reposts":[]}',
    200,
    headers: json,
  );

  Future<void> check(
    WidgetTester tester, {
    required String reason,
    required bool pc,
    required Expected expected,
    CommunityService? service,
    Future<void> Function(CommunityService service)? prepare,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('bookmark-reasons-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = pc
        ? const Size(1440, 900)
        : const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          if (service != null)
            ChangeNotifierProvider<CommunityService>.value(value: service),
        ],
        child: const NiarimApp(),
      ),
    );
    await tester.pumpAndSettle();
    final home = find.byType(HomeScreen);
    final community = tester.element(home).read<CommunityService>();
    await prepare?.call(community);
    final savedIds = Set<String>.of(community.bookmarkedIds);
    final tab = find.byKey(const ValueKey('home_tab_2'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final settings = tester.element(home).read<SettingsService>();
    final sizes = pc
        ? const [Size(1440, 900), Size(1024, 640)]
        : const [Size(390, 844), Size(320, 640)];
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      final l10n = appLocalizationsFor(locale);
      for (final size in sizes) {
        for (final scale in const [1.0, 2.0]) {
          final where =
              '$reason ${pc ? 'PC' : 'SP'} $code '
              '${size.width.toInt()}x${size.height.toInt()} x$scale';
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: where);
          final texts = [
            expected.title(l10n),
            ?expected.body?.call(l10n),
            ?expected.reload?.call(l10n),
            l10n.communityScreenTitle,
          ];
          for (final text in texts) {
            final finder = find.text(text, skipOffstage: false).hitTestable();
            final any = find.text(text, skipOffstage: false);
            expect(any, findsWidgets, reason: '$where "$text"');
            await tester.ensureVisible(any.last);
            await tester.pump();
            expect(finder, findsWidgets, reason: '$where "$text" reachable');
            final rect = tester.getRect(finder.last);
            expect(rect.left, greaterThanOrEqualTo(-0.5), reason: where);
            expect(rect.right, lessThanOrEqualTo(size.width + 0.5));
            expect(rect.bottom, lessThanOrEqualTo(size.height + 0.5));
          }
          // ほかの理由の見出しは出ない（理由を取り違えない）。
          for (final other in [
            l10n.homeBookmarkedEmptyTitle,
            l10n.homeBookmarkedHiddenTitle,
            l10n.homeBookmarkedLoading,
            l10n.homeBookmarkedLoadFailed,
            l10n.homeBookmarkedLoadPrompt,
          ]) {
            if (other == expected.title(l10n)) continue;
            expect(find.text(other), findsNothing, reason: '$where $other');
          }
        }
      }
    }
    expect(community.bookmarkedIds.toSet(), savedIds, reason: reason);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final pc in [false, true]) {
    final mode = pc ? 'PC' : 'SP';

    testWidgets('$mode nothing bookmarked yet', (tester) async {
      await check(
        tester,
        reason: 'empty',
        pc: pc,
        expected: (
          title: (l) => l.homeBookmarkedEmptyTitle,
          body: (l) => l.homeBookmarkedEmptyBody,
          reload: null,
        ),
      );
    });

    testWidgets('$mode saved bookmarks that cannot be shown', (tester) async {
      await check(
        tester,
        reason: 'hidden',
        pc: pc,
        expected: (
          title: (l) => l.homeBookmarkedHiddenTitle,
          body: (l) => l.homeBookmarkedHiddenBody,
          reload: null,
        ),
        prepare: (service) => service.toggleBookmark('fixture-missing'),
      );
    });

    testWidgets('$mode not signed in', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = backend(MockClient((r) async => social(r)));
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      await check(
        tester,
        reason: 'signed out',
        pc: pc,
        service: service,
        expected: (
          title: (l) => l.homeBookmarkedEmptyTitle,
          body: (l) => l.homeBookmarkedSignInBody,
          reload: null,
        ),
      );
    });

    testWidgets('$mode signed in but not loaded yet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = backend(MockClient((r) async => social(r)));
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('fixture-owner');
      await check(
        tester,
        reason: 'not loaded',
        pc: pc,
        service: service,
        expected: (
          title: (l) => l.homeBookmarkedLoadPrompt,
          body: null,
          reload: (l) => l.communityReloadTooltip,
        ),
      );
    });

    testWidgets('$mode loading', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final held = Completer<http.Response>();
      final service = backend(
        MockClient(
          (r) async =>
              r.url.path.endsWith('/bookmarks') ? held.future : social(r),
        ),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('fixture-owner');
      Future<void>? pending;
      await check(
        tester,
        reason: 'loading',
        pc: pc,
        service: service,
        prepare: (s) async {
          pending = s.loadSocial();
        },
        expected: (
          title: (l) => l.homeBookmarkedLoading,
          body: null,
          reload: null,
        ),
      );
      held.complete(http.Response('{"works":[]}', 200, headers: json));
      await tester.runAsync(() async => pending);
    });

    testWidgets('$mode loading failed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = backend(
        MockClient(
          (r) async => r.url.path.endsWith('/bookmarks')
              ? http.Response('{"error":"unavailable"}', 503, headers: json)
              : social(r),
        ),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('fixture-owner');
      await check(
        tester,
        reason: 'failed',
        pc: pc,
        service: service,
        prepare: (s) => tester.runAsync(s.loadSocial),
        expected: (
          title: (l) => l.homeBookmarkedLoadFailed,
          body: null,
          reload: (l) => l.communityRetry,
        ),
      );
    });
  }
}
