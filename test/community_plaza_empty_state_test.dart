import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// サーバーにつないだ作品広場の一覧が空のときの表示。
///
/// 以前は読み込み中も通信の失敗も、本当に作品が無いときも、検索の×の印と
/// 「作品がありません」だった。公開したばかりの広場は空なので、読み込み中・
/// 読み込めない（再試行）・まだ投稿が無い（投稿の案内）を分けて出す。
void main() {
  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  CommunityService serviceWith(
    Future<http.Response> Function(http.Request) handler,
  ) => CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient(handler),
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
      ),
    ),
  );

  http.Response emptyPage(http.Request request) => http.Response(
    jsonEncode(
      request.url.path.startsWith('/ranking')
          ? {'items': <Object>[], 'nextCursor': null}
          : {'works': <Object>[], 'nextCursor': null},
    ),
    200,
    headers: jsonHeaders,
  );

  Widget host(
    CommunityService service, {
    Locale locale = const Locale('ja'),
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<CommunityService>.value(value: service),
      ChangeNotifierProvider<SettingsService>(create: (_) => SettingsService()),
      ChangeNotifierProvider<PremiumService>(create: (_) => PremiumService()),
      ChangeNotifierProvider<CommunityPreviewService>(
        create: (_) => CommunityPreviewService(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CommunityScreen(),
    ),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('読み込みが終わるまでは「作品がありません」と言わない', (tester) async {
    final gate = Completer<void>();
    final service = serviceWith((request) async {
      await gate.future;
      return emptyPage(request);
    });
    addTearDown(service.dispose);
    await tester.pumpWidget(host(service));
    await tester.pump();
    expect(find.byKey(const Key('communityPlazaLoading')), findsOneWidget);
    expect(find.text('作品がありません'), findsNothing);
    expect(find.byKey(const Key('communityPlazaPostFirst')), findsNothing);
    gate.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byKey(const Key('communityPlazaLoading')), findsNothing);
  });

  testWidgets('作品が0件なら、まだ作品が無いことと投稿の案内を出す', (tester) async {
    final service = serviceWith((request) async => emptyPage(request));
    addTearDown(service.dispose);
    await tester.pumpWidget(host(service));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(service.hasFetchedLatest, isTrue);
    expect(find.byKey(const Key('communityPlazaEmpty')), findsOneWidget);
    expect(find.text('まだ作品がありません'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsNothing);
    final post = find.byKey(const Key('communityPlazaPostFirst'));
    expect(post, findsOneWidget);
    expect(
      find.descendant(of: post, matching: find.text('投稿する')),
      findsOneWidget,
    );
    expect(tester.getSize(post).height, greaterThanOrEqualTo(40));
  });

  testWidgets('読み込めなければ理由と再試行を出し、再試行で読み直す', (tester) async {
    var fail = true;
    var latestRequests = 0;
    final service = serviceWith((request) async {
      if (request.url.path == '/works/latest') latestRequests++;
      if (fail) {
        return http.Response(
          jsonEncode({'error': 'unavailable'}),
          503,
          headers: jsonHeaders,
        );
      }
      return emptyPage(request);
    });
    addTearDown(service.dispose);
    await tester.pumpWidget(host(service));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byKey(const Key('communityPlazaLoadFailed')), findsOneWidget);
    expect(find.text('作品を読み込めませんでした'), findsOneWidget);
    expect(find.text('まだ作品がありません'), findsNothing);
    expect(find.byKey(const Key('communityPlazaPostFirst')), findsNothing);

    fail = false;
    final before = latestRequests;
    await tester.tap(find.byKey(const Key('communityPlazaRetry')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(latestRequests, greaterThan(before));
    expect(find.byKey(const Key('communityPlazaEmpty')), findsOneWidget);
  });

  testWidgets('どの言語でも空の広場の文と投稿のボタンが出る', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final service = serviceWith((request) async => emptyPage(request));
      await tester.pumpWidget(host(service, locale: locale));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      final l10n = lookupAppLocalizations(locale);
      expect(
        find.byKey(const Key('communityPlazaEmpty')),
        findsOneWidget,
        reason: locale.toLanguageTag(),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('communityPlazaPostFirst')),
          matching: find.text(l10n.communityPostButton),
        ),
        findsOneWidget,
        reason: locale.toLanguageTag(),
      );
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    }
  });
}
