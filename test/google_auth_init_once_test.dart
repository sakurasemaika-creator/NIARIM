import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/services/google_auth_service.dart';

/// GoogleSignInの`initialize`は1プロセスに1回しか呼べない。起動に失敗して
/// GoogleAuthServiceを作り直しても、SDKの初期化が二重にならないことを
/// 確かめる。
///
/// OAuthクライアントIDが未設定のビルドではSDKへ一切触れない（匿名モード）
/// ため、この検証は次のように設定付きで実行したときだけ動く：
///   flutter test --dart-define=NIARIM_GOOGLE_CLIENT_ID=test \
///     test/google_auth_init_once_test.dart
class _FakeSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  Completer<void> initialization = Completer<void>();
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
  }) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final configured = GoogleAuthService.googleClientId.isNotEmpty;
  const skip = 'run with --dart-define=NIARIM_GOOGLE_CLIENT_ID=test';

  test('a recreated service reuses the SDK initialization', () async {
    final signIn = _FakeSignIn()..initialization.complete();
    final first = GoogleAuthService(signIn: signIn);
    await first.init();
    first.dispose();

    final second = GoogleAuthService(signIn: signIn);
    await second.init();
    expect(second.isInitialized, isTrue);
    expect(signIn.initializeCalls, 1);
    second.dispose();
  }, skip: configured ? false : skip);

  test('concurrent services share one in-flight initialization', () async {
    final signIn = _FakeSignIn();
    final a = GoogleAuthService(signIn: signIn);
    final b = GoogleAuthService(signIn: signIn);
    final both = Future.wait([a.init(), b.init()]);
    await Future<void>.delayed(Duration.zero);
    expect(signIn.initializeCalls, 1);
    signIn.initialization.complete();
    await both;
    expect(a.isInitialized && b.isInitialized, isTrue);
    a.dispose();
    b.dispose();
  }, skip: configured ? false : skip);

  test('a failed initialization is retried by the next attempt', () async {
    final signIn = _FakeSignIn();
    signIn.initialization.completeError(StateError('offline'));
    final first = GoogleAuthService(signIn: signIn);
    await expectLater(first.init(), throwsStateError);
    expect(first.isInitialized, isFalse);
    first.dispose();

    signIn.initialization = Completer<void>()..complete();
    final second = GoogleAuthService(signIn: signIn);
    await second.init();
    expect(second.isInitialized, isTrue);
    expect(signIn.initializeCalls, 2);
    second.dispose();
  }, skip: configured ? false : skip);
}
