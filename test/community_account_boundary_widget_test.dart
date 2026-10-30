import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_edit_feedback.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/screens/community/community_work_settings_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  _Account(this.id);
  @override
  final String id;
  @override
  String get email => '$id@example.invalid';
  @override
  String get displayName => 'Audit $id';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth extends GoogleAuthService {
  _Auth(String id) : _current = _Account(id);
  GoogleSignInAccount? _current;
  @override
  GoogleSignInAccount? get account => _current;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => _current != null;
  void switchTo(String id) {
    _current = _Account(id);
    notifyListeners();
  }
}

http.Response _reply(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Object _page(String owner) => {
  'authorId': owner,
  'works': [
    {
      'workId': '$owner-private',
      'authorId': owner,
      'title': 'Private fixture $owner',
      'postedAt': '2026-10-21T00:00:00Z',
      'isNiarimPublished': false,
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final pc in [false, true]) {
    testWidgets(
      'owner UI drops previous private rows while the next account loads (${pc ? 'PC' : 'SP'})',
      (tester) async {
        final auth = _Auth('old');
        final settings = SettingsService();
        await settings.setForcePcMode(pc);
        final nextStarted = Completer<void>();
        final next = Completer<http.Response>();
        final community = CommunityService(
          api: CommunityApi(
            NiarimApiClient(
              baseUrl: 'https://example.invalid',
              maxGetRetries: 0,
              tokenProvider: () async => auth.account?.id,
              httpClient: MockClient((request) async {
                if (request.headers['Authorization'] == 'Bearer new') {
                  if (!nextStarted.isCompleted) nextStarted.complete();
                  return next.future;
                }
                return _reply(_page('old'));
              }),
            ),
          ),
        );
        await community.contentFiltersReady;
        tester.view.physicalSize = pc
            ? const Size(1440, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(auth.dispose);
        addTearDown(settings.dispose);
        addTearDown(community.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
              ChangeNotifierProvider<CommunityService>.value(value: community),
              ChangeNotifierProvider<SettingsService>.value(value: settings),
              ChangeNotifierProvider(create: (_) => PremiumService()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CommunityMyWorksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Private fixture old'), findsOneWidget);
        community.forgetOwner();
        auth.switchTo('new');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(nextStarted.isCompleted, isTrue);
        expect(find.text('Private fixture old'), findsNothing);
        expect(find.text('Audit new'), findsOneWidget);
        next.complete(_reply(_page('new')));
        await tester.pumpAndSettle();
        expect(find.text('Private fixture new'), findsOneWidget);
        expect(find.text('Private fixture old'), findsNothing);
        expect(community.byId('old-private'), isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'cancelled prior-account edit does not show an error in the next account',
    (tester) async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final community = CommunityService(
        api: CommunityApi(
          NiarimApiClient(
            baseUrl: 'https://example.invalid',
            maxGetRetries: 0,
            tokenProvider: () async => 'isolated-token',
            httpClient: MockClient((request) {
              started.complete();
              return response.future;
            }),
          ),
        ),
      );
      await community.contentFiltersReady;
      addTearDown(community.dispose);
      community.setCurrentUserId('old');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => reportFailedCommunityEdit(
                  context,
                  community,
                  community.toggleBookmark('known'),
                ),
                child: const Text('Bookmark fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Bookmark fixture'));
      await tester.pump();
      expect(started.isCompleted, isTrue);
      community.forgetOwner();
      community.setCurrentUserId('new');
      response.complete(_reply({'error': 'down'}, status: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(community.lastError, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final ai in [true, false]) {
    testWidgets(
      'late previous-account completion cannot enable a pending edit (${ai ? 'AI' : 'visibility'})',
      (tester) async {
        final auth = _Auth('old');
        final pending = <Completer<http.Response>>[];
        final community = CommunityService(
          api: CommunityApi(
            NiarimApiClient(
              baseUrl: 'https://example.invalid',
              maxGetRetries: 0,
              tokenProvider: () async => auth.account?.id,
              httpClient: MockClient((request) async {
                if (request.method == 'PATCH') {
                  final reply = Completer<http.Response>();
                  pending.add(reply);
                  return reply.future;
                }
                final owner = request.headers['Authorization'] == 'Bearer new'
                    ? 'new'
                    : 'old';
                return _reply(_page(owner));
              }),
            ),
          ),
        );
        await community.contentFiltersReady;
        addTearDown(auth.dispose);
        addTearDown(community.dispose);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
              ChangeNotifierProvider<CommunityService>.value(value: community),
              ChangeNotifierProvider(create: (_) => SettingsService()),
              ChangeNotifierProvider(create: (_) => PremiumService()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CommunityMyWorksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          Navigator.of(
            tester.element(find.byType(CommunityMyWorksScreen)),
          ).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  const CommunityWorkSettingsScreen(workId: 'old-private'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(ai ? Checkbox : Switch));
        await tester.tap(find.byType(ai ? Checkbox : Switch));
        await tester.pump();
        expect(pending, hasLength(1));
        for (final id in ['new', 'old']) {
          community.forgetOwner();
          auth.switchTo(id);
          // Bound virtual time while an intentionally unresolved HTTP request exists.
          // pumpAndSettle can advance its transport retry deadline via the spinner.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
        }
        await tester.tap(find.byType(ai ? Checkbox : Switch));
        await tester.pump();
        expect(pending, hasLength(2));
        pending[0].complete(
          _reply({
            'work': {
              'workId': 'old-private',
              'authorId': 'old',
              'title': 'Private fixture old',
              'postedAt': '2026-10-21T00:00:00Z',
              'isNiarimPublished': false,
            },
          }),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        final row = find.byKey(
          Key(
            ai
                ? 'communityWorkSettingsAiFlag'
                : 'communityWorkSettingsVisibility',
          ),
        );
        expect(
          ai
              ? tester.widget<CheckboxListTile>(row).onChanged
              : tester.widget<SwitchListTile>(row).onChanged,
          isNull,
          reason:
              'The old request must not clear the busy flag of the current account request.',
        );
        pending[1].complete(
          _reply({
            'work': {
              'workId': 'old-private',
              'authorId': 'old',
              'title': 'Private fixture old',
              'postedAt': '2026-10-21T00:00:00Z',
              'isNiarimPublished': false,
            },
          }),
        );
        await tester.pumpAndSettle();
        expect(
          ai
              ? tester.widget<CheckboxListTile>(row).onChanged
              : tester.widget<SwitchListTile>(row).onChanged,
          isNotNull,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final tag in [true, false]) {
    for (final covered in [false, true]) {
      testWidgets(
        'owner revision removes ${tag ? 'tag' : 'delete'} modal; preserves unrelated route=$covered',
        (tester) async {
          final requests = <http.Request>[];
          final community = CommunityService(
            api: CommunityApi(
              NiarimApiClient(
                baseUrl: 'https://example.invalid',
                tokenProvider: () async => 'old',
                maxGetRetries: 0,
                httpClient: MockClient((request) async {
                  requests.add(request);
                  return _reply(_page('old'));
                }),
              ),
            ),
          );
          await community.loadOwnWorks();
          addTearDown(community.dispose);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CommunityService>.value(
                  value: community,
                ),
                ChangeNotifierProvider(create: (_) => SettingsService()),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const CommunityWorkSettingsScreen(workId: 'old-private'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final open = find.byKey(
            Key(tag ? 'communityWorkTagAdd' : 'communityWorkSettingsDelete'),
          );
          await tester.scrollUntilVisible(
            open,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(open);
          await tester.tap(open);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (tag) {
            await tester.enterText(
              find.byKey(const Key('communityWorkTagInput')),
              'PRIVATE DRAFT',
            );
          }
          if (covered) {
            unawaited(
              Navigator.of(tester.element(find.byType(AlertDialog))).push<void>(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('UNRELATED ROUTE')),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }
          community.forgetOwner();
          community.setCurrentUserId('new');
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
          expect(find.text('PRIVATE DRAFT', skipOffstage: false), findsNothing);
          if (covered) expect(find.text('UNRELATED ROUTE'), findsOneWidget);
          expect(
            requests.where((r) => r.method != 'GET'),
            isEmpty,
            reason: 'No old dialog may send an edit in the new account',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
