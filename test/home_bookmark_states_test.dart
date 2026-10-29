import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/app.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_models.dart';
import 'package:niarim/services/community_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<CommunityService> open(
    WidgetTester tester,
    bool pc, {
    CommunityService? backend,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'en',
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('home-bookmark-states-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = pc
        ? const Size(1440, 900)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          if (backend != null)
            ChangeNotifierProvider<CommunityService>.value(value: backend),
        ],
        child: const NiarimApp(),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(HomeScreen)).read<CommunityService>();
  }

  Future<void> bookmarks(WidgetTester tester) async {
    final tab = find.byKey(const ValueKey('home_tab_2'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
  }

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
  for (final pc in [false, true]) {
    testWidgets(
      '${pc ? 'PC' : 'SP'} resize during a nonadjacent tab transition keeps title body and controls aligned',
      (tester) async {
        for (final delay in [0, 10, 50, 100, 200, 300, 500]) {
          await open(tester, pc);
          tester.view.physicalSize = const Size(640, 844);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpAndSettle();
          final tab = find.byKey(const ValueKey('home_tab_2'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pump();
          await tester.pump(Duration(milliseconds: delay));
          tester.view.physicalSize = const Size(320, 844);
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(HomeScreen)),
          )!;
          expect(
            tester.widget<Semantics>(tab).properties.selected,
            isTrue,
            reason: 'delay=$delay',
          );
          final appBar = tester.widget<AppBar>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(AppBar),
                )
                .first,
          );
          expect(
            (appBar.title as Text).data,
            l10n.homeTabBookmarked,
            reason: 'delay=$delay',
          );
          expect(
            find.text(l10n.homeBookmarkedEmptyTitle),
            findsOneWidget,
            reason: 'delay=$delay',
          );
          expect(
            find.byType(FloatingActionButton),
            findsNothing,
            reason:
                'The project-only scroll-to-top FAB is hidden on bookmarks; delay=$delay',
          );
          expect(find.byKey(const Key('homeBackToSplashButton')), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        }
      },
    );

    testWidgets(
      '${pc ? 'PC' : 'SP'} empty saved works can be refreshed by pulling the viewport',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var fetches = 0;
        final service = backend(
          MockClient((r) async {
            if (r.url.path.endsWith('/bookmarks')) {
              fetches++;
              return http.Response('{"works":[]}', 200);
            }
            return http.Response(
              r.url.path.endsWith('/following')
                  ? '{"following":[]}'
                  : '{"reposts":[]}',
              200,
            );
          }),
        );
        addTearDown(service.dispose);
        await service.contentFiltersReady;
        service.setCurrentUserId('fixture-owner');
        await open(tester, pc, backend: service);
        await tester.runAsync(() => service.loadSocial());
        await bookmarks(tester);
        expect(fetches, 1);
        final refresh = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(RefreshIndicator),
        );
        await tester.drag(refresh, const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(fetches, 2);
        expect(service.hasLoadedSocial, isTrue);
        expect(service.bookmarkedIds, isEmpty);
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('home_tab_2')))
              .properties
              .selected,
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '${pc ? 'PC' : 'SP'} selected tab stays visible after text growth and resize',
      (tester) async {
        await open(tester, pc);
        tester.view.physicalSize = const Size(640, 844);
        await tester.pumpAndSettle();
        await bookmarks(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(320, 844);
        await tester.pumpAndSettle();
        final selected = find.byKey(const ValueKey('home_tab_2'));
        expect(tester.getRect(selected).left, greaterThanOrEqualTo(-.01));
        expect(tester.getRect(selected).right, lessThanOrEqualTo(320.01));
        expect(tester.widget<Semantics>(selected).properties.selected, isTrue);
        tester.view.physicalSize = const Size(1440, 900);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(320, 844);
        await tester.pumpAndSettle();
        expect(tester.getRect(selected).right, lessThanOrEqualTo(320.01));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    for (final unresolved in [false, true]) {
      testWidgets(
        '${pc ? 'PC' : 'SP'} ${unresolved ? 'unresolved' : 'filtered'} bookmark is not reported as never bookmarked',
        (tester) async {
          final service = await open(tester, pc);
          if (!unresolved) {
            service.applyServerWork(
              ApiWork.fromJson({
                'workId': 'fixture-ai',
                'authorId': 'fixture-other',
                'title': 'AI fixture bookmark',
                'postedAt': '2026-10-22T00:00:00Z',
                'isNiarimPublished': true,
                'containsGenerativeAiImageOrVideo': true,
              }).toCommunityWork(),
            );
          }
          await service.toggleBookmark(
            unresolved ? 'fixture-missing' : 'fixture-ai',
          );
          await tester.runAsync(
            () => service.setHideGenerativeAiImageVideo(true),
          );
          await bookmarks(tester);
          expect(service.bookmarkedIds, hasLength(1));
          expect(service.bookmarkedWorksForViewer, isEmpty);
          expect(
            find.text(
              AppLocalizations.of(
                tester.element(find.byType(HomeScreen)),
              )!.homeBookmarkedEmptyTitle,
            ),
            findsNothing,
            reason:
                'A saved bookmark must not be presented as absent because its work is filtered or unavailable.',
          );
          if (unresolved) {
            service.applyServerWork(
              ApiWork.fromJson({
                'workId': 'fixture-missing',
                'authorId': 'fixture-other',
                'title': 'Recovered fixture bookmark',
                'postedAt': '2026-10-22T00:00:00Z',
                'isNiarimPublished': true,
              }).toCommunityWork(),
            );
          } else {
            await tester.runAsync(
              () => service.setHideGenerativeAiImageVideo(false),
            );
          }
          await tester.pumpAndSettle();
          expect(
            find.text(
              unresolved ? 'Recovered fixture bookmark' : 'AI fixture bookmark',
            ),
            findsOneWidget,
          );
          expect(service.bookmarkedIds, hasLength(1));
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets('${pc ? 'PC' : 'SP'} loading bookmarks has a loading state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final held = Completer<http.Response>();
      final started = Completer<void>();
      final service = backend(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            started.complete();
            return held.future;
          }
          if (r.url.path.endsWith('/following')) {
            return http.Response('{"following":[]}', 200);
          }
          return http.Response('{"reposts":[]}', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('fixture-owner');
      await open(tester, pc, backend: service);
      final pending = service.loadSocial();
      await tester.pump();
      expect(started.isCompleted, isTrue);
      await bookmarks(tester);
      final loading = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .isNotEmpty;
      held.complete(http.Response('{"works":[]}', 200));
      await tester.pump();
      await pending;
      await tester.pumpAndSettle();
      expect(
        loading,
        isTrue,
        reason: 'An unfinished request is not an empty account.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('${pc ? 'PC' : 'SP'} bookmark load failure provides Retry', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var bookmarkRequests = 0;
      final service = backend(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            return ++bookmarkRequests == 1
                ? http.Response('{"error":"unavailable"}', 503)
                : http.Response('{"works":[]}', 200);
          }
          if (r.url.path.endsWith('/following')) {
            return http.Response('{"following":[]}', 200);
          }
          return http.Response('{"reposts":[]}', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('fixture-owner');
      await open(tester, pc, backend: service);
      final pending = service.loadSocial();
      await tester.pump();
      await pending;
      await bookmarks(tester);
      expect(
        find.text('Retry'),
        findsOneWidget,
        reason:
            'A failed request must not look like a successful empty result.',
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(bookmarkRequests, 2);
      expect(service.socialError, isNull);
      expect(service.hasLoadedSocial, isTrue);
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final guest in [false, true]) {
      testWidgets(
        '${pc ? 'PC' : 'SP'} ${guest ? 'guest guidance' : 'unloaded account has explicit Load action'}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          var requests = 0;
          final service = backend(
            MockClient((r) async {
              requests++;
              return http.Response(
                r.url.path.endsWith('/bookmarks')
                    ? '{"works":[]}'
                    : r.url.path.endsWith('/following')
                    ? '{"following":[]}'
                    : '{"reposts":[]}',
                200,
              );
            }),
          );
          addTearDown(service.dispose);
          await service.contentFiltersReady;
          if (!guest) service.setCurrentUserId('fixture-owner');
          await open(tester, pc, backend: service);
          await bookmarks(tester);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(HomeScreen)),
          )!;
          if (guest) {
            expect(find.text(l10n.homeBookmarkedSignInBody), findsOneWidget);
            expect(requests, 0);
          } else {
            expect(find.text(l10n.homeBookmarkedLoadPrompt), findsOneWidget);
            await tester.tap(find.text(l10n.communityReloadTooltip));
            await tester.pumpAndSettle();
            expect(service.hasLoadedSocial, isTrue);
            expect(find.text(l10n.homeBookmarkedEmptyTitle), findsOneWidget);
            expect(find.text(l10n.homeBookmarkedLoadPrompt), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
