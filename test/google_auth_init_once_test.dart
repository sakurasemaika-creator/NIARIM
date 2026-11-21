import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';
import 'package:niarim/services/google_auth_service.dart';

/// GoogleSignInの`initialize`は1プロセスに1回しか呼べない。起動に失敗して
/// GoogleAuthServiceを作り直しても、SDKの初期化が二重にならないことを
/// 確かめる。
class _FakeSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  int lightweightCalls = 0;
  int signOutCalls = 0;
  Completer<void> initialization = Completer<void>();
  Future<GoogleSignInAccount?>? Function()? lightweight;
  final _events = StreamController<GoogleSignInAuthenticationEvent>.broadcast();

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) {
    initializeCalls++;
    return initialization.future;
  }

  @override
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _events.stream;

  @override
  Future<GoogleSignInAccount?>? attemptLightweightAuthentication({
    bool reportAllExceptions = false,
  }) {
    lightweightCalls++;
    return lightweight?.call();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAccount implements GoogleSignInAccount {
  _TestAccount({this.id = 'first', this.token = 'stale'});

  @override
  final String id;

  final String token;

  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);

  @override
  final _TestAuthorization authorizationClient = _TestAuthorization();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthorization implements GoogleSignInAuthorizationClient {
  final checked = <List<String>>[];
  final prompted = <List<String>>[];
  final granted = <String>{};

  @override
  Future<GoogleSignInClientAuthorization?> authorizationForScopes(
    List<String> scopes,
  ) async {
    checked.add(scopes);
    return granted.containsAll(scopes)
        ? const GoogleSignInClientAuthorization(accessToken: 'cached')
        : null;
  }

  @override
  Future<GoogleSignInClientAuthorization> authorizeScopes(
    List<String> scopes,
  ) async {
    prompted.add(scopes);
    granted.addAll(scopes);
    return const GoogleSignInClientAuthorization(accessToken: 'approved');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<GoogleAuthService> signedIn(
    _FakeSignIn sdk,
    _TestAccount account,
  ) async {
    final service = GoogleAuthService(signIn: sdk, clientId: 'test');
    addTearDown(service.dispose);
    await service.init();
    sdk._events.add(GoogleSignInAuthenticationEventSignIn(user: account));
    await Future<void>.delayed(Duration.zero);
    return service;
  }

  test(
    'concurrent 401 responses retry once with a renewed account token',
    () async {
      final sdk = _FakeSignIn()..initialization.complete();
      final auth = await signedIn(sdk, _TestAccount());
      final refreshed = _TestAccount(token: 'fresh');
      final refreshGate = Completer<GoogleSignInAccount>();
      final renewalStarted = Completer<void>();
      sdk.lightweight = () {
        renewalStarted.complete();
        return refreshGate.future;
      };
      final twoRequests = Completer<void>();
      final tokens = <String?>[];
      final api = NiarimApiClient(
        baseUrl: 'https://example.invalid',
        tokenProvider: auth.backendIdToken,
        refreshToken: auth.refreshRejectedBackendIdToken,
        httpClient: MockClient((request) async {
          final token = request.headers['authorization'];
          tokens.add(token);
          if (tokens.length == 2) twoRequests.complete();
          if (token == 'Bearer fresh') return http.Response('{}', 200);
          return http.Response('{"code":"UNAUTHORIZED"}', 401);
        }),
      );
      addTearDown(api.close);
      final writes = Future.wait([
        api.patchJson('/works/one', body: {'title': 'one'}),
        api.postJson('/users/creator/follow', body: {'follow': true}),
      ]);
      await Future.wait([twoRequests.future, renewalStarted.future]);
      sdk._events.add(GoogleSignInAuthenticationEventSignIn(user: refreshed));
      refreshGate.complete(refreshed);
      await writes;
      expect(sdk.lightweightCalls, 2); // Startup and a single renewal.
      expect(tokens, [
        'Bearer stale',
        'Bearer stale',
        'Bearer fresh',
        'Bearer fresh',
      ]);
    },
  );

  test('known-expired credentials are renewed before they are sent', () async {
    final sdk = _FakeSignIn()..initialization.complete();
    final payload = base64Url.encode(utf8.encode('{"exp":1}'));
    final auth = await signedIn(sdk, _TestAccount(token: 'head.$payload.sig'));
    sdk.lightweight = () async => _TestAccount(token: 'fresh');
    expect(await auth.backendIdToken(), 'fresh');
    expect(await auth.backendIdToken(), 'fresh');
    expect(sdk.lightweightCalls, 2);
  });

  test(
    'a deleted account signs out without automatically refreshing',
    () async {
      final sdk = _FakeSignIn()..initialization.complete();
      final auth = await signedIn(sdk, _TestAccount());
      final api = NiarimApiClient(
        baseUrl: 'https://example.invalid',
        tokenProvider: auth.backendIdToken,
        refreshToken: auth.refreshRejectedBackendIdToken,
        onAccountErased: auth.signOutDeletedAccount,
        httpClient: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer stale');
          return http.Response('{"code":"ACCOUNT_ERASED"}', 410);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.getJson('/me/works', authenticated: true),
        throwsA(
          isA<NiarimApiException>().having(
            (e) => e.code,
            'code',
            'ACCOUNT_ERASED',
          ),
        ),
      );
      expect(sdk.lightweightCalls, 1);
      expect(sdk.signOutCalls, 1);
      expect(await auth.backendIdToken(), isNull);
    },
  );

  test(
    'the deletion response for a prior account preserves the current sign-in',
    () async {
      final sdk = _FakeSignIn()..initialization.complete();
      final auth = await signedIn(
        sdk,
        _TestAccount(id: 'second', token: 'other'),
      );
      await auth.signOutDeletedAccount('stale');
      expect(sdk.signOutCalls, 0);
      expect(await auth.backendIdToken(), 'other');
    },
  );

  test(
    'a different account at renewal signs out and never replays a write',
    () async {
      final sdk = _FakeSignIn()..initialization.complete();
      final auth = await signedIn(sdk, _TestAccount());
      sdk.lightweight = () async {
        final other = _TestAccount(id: 'second', token: 'other');
        sdk._events.add(GoogleSignInAuthenticationEventSignIn(user: other));
        return other;
      };
      final tokens = <String?>[];
      final api = NiarimApiClient(
        baseUrl: 'https://example.invalid',
        tokenProvider: auth.backendIdToken,
        refreshToken: auth.refreshRejectedBackendIdToken,
        httpClient: MockClient((request) async {
          tokens.add(request.headers['authorization']);
          return http.Response('{}', 401);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.postJson('/works'),
        throwsA(
          isA<NiarimApiException>().having(
            (e) => e.isUnauthorized,
            '401',
            true,
          ),
        ),
      );
      expect(tokens, ['Bearer stale']);
      expect(auth.isSignedIn, isFalse);
      expect(await auth.backendIdToken(), isNull);
    },
  );

  test('YouTube only requests the scopes needed for each action', () async {
    const read = 'https://www.googleapis.com/auth/youtube.readonly';
    const upload = 'https://www.googleapis.com/auth/youtube.upload';
    final sdk = _FakeSignIn()..initialization.complete();
    final service = GoogleAuthService(signIn: sdk, clientId: 'test');
    addTearDown(service.dispose);
    await service.init();
    final account = _TestAccount();
    sdk._events.add(GoogleSignInAuthenticationEventSignIn(user: account));
    await Future<void>.delayed(Duration.zero);
    final auth = account.authorizationClient;

    expect(await service.youtubeReadAccessToken(), isNull);
    expect(auth.prompted, isEmpty);
    expect(
      await service.youtubeReadAccessToken(promptIfNecessary: true),
      'approved',
    );
    expect(auth.prompted.single, [read]);
    expect(await service.youtubeUploadAccessToken(), isNull);
    expect(
      await service.youtubeUploadAccessToken(promptIfNecessary: true),
      'approved',
    );
    expect(auth.prompted.last.toSet(), {read, upload});
    expect(
      await service.youtubeUploadAccessToken(promptIfNecessary: true),
      'cached',
    );
    expect(
      await service.youtubeReadAccessToken(promptIfNecessary: true),
      'cached',
    );
    expect(auth.checked.last, [read]);
    expect(auth.prompted, hasLength(2));
  });

  test('a recreated service reuses the SDK initialization', () async {
    final signIn = _FakeSignIn()..initialization.complete();
    final first = GoogleAuthService(signIn: signIn, clientId: 'test');
    await first.init();
    first.dispose();

    final second = GoogleAuthService(signIn: signIn, clientId: 'test');
    await second.init();
    expect(second.isInitialized, isTrue);
    expect(signIn.initializeCalls, 1);
    second.dispose();
  });

  test('an unconfigured service starts without calling the SDK', () async {
    final signIn = _FakeSignIn();
    final service = GoogleAuthService(signIn: signIn, clientId: '');
    addTearDown(service.dispose);

    await service.init();

    expect(service.isConfigured, isFalse);
    expect(service.isInitialized, isTrue);
    expect(await service.backendIdToken(), isNull);
    expect(signIn.initializeCalls, 0);
    expect(signIn.lightweightCalls, 0);
  });

  test('concurrent callers share the service startup sign-in', () async {
    final startupSignIn = Completer<GoogleSignInAccount?>();
    final signIn = _FakeSignIn()..lightweight = () => startupSignIn.future;
    final service = GoogleAuthService(signIn: signIn, clientId: 'test');
    addTearDown(service.dispose);

    var completed = 0;
    final both = Future.wait([
      service.init().then((_) => completed++),
      service.init().then((_) => completed++),
    ]);
    signIn.initialization.complete();
    await Future<void>.delayed(Duration.zero);

    expect(signIn.initializeCalls, 1);
    expect(signIn.lightweightCalls, 1);
    expect(completed, 0);
    final account = _TestAccount();
    startupSignIn.complete(account);
    await both;
    expect(service.account, same(account));
  });

  test(
    'disposal before SDK initialization finishes prevents sign-in',
    () async {
      final signIn = _FakeSignIn();
      final service = GoogleAuthService(signIn: signIn, clientId: 'test');
      final initialization = service.init();
      service.dispose();
      signIn.initialization.complete();

      await initialization;

      expect(signIn.lightweightCalls, 0);
    },
  );

  test('concurrent services share one in-flight initialization', () async {
    final signIn = _FakeSignIn();
    final a = GoogleAuthService(signIn: signIn, clientId: 'test');
    final b = GoogleAuthService(signIn: signIn, clientId: 'test');
    final both = Future.wait([a.init(), b.init()]);
    await Future<void>.delayed(Duration.zero);
    expect(signIn.initializeCalls, 1);
    signIn.initialization.complete();
    await both;
    expect(a.isInitialized && b.isInitialized, isTrue);
    a.dispose();
    b.dispose();
  });

  test('a failed initialization is retried by the next attempt', () async {
    final signIn = _FakeSignIn();
    signIn.initialization.completeError(StateError('offline'));
    final first = GoogleAuthService(signIn: signIn, clientId: 'test');
    await expectLater(first.init(), throwsStateError);
    expect(first.isInitialized, isFalse);
    first.dispose();

    signIn.initialization = Completer<void>()..complete();
    final second = GoogleAuthService(signIn: signIn, clientId: 'test');
    await second.init();
    expect(second.isInitialized, isTrue);
    expect(signIn.initializeCalls, 2);
    second.dispose();
  });
}
