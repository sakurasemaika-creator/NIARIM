import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/services/google_auth_service.dart';

class _SignIn extends Fake implements GoogleSignIn {
  final events = StreamController<GoogleSignInAuthenticationEvent>.broadcast();
  final initialization = Completer<void>();
  var initializeCalls = 0;
  var lightweightCalls = 0;
  var failNext = false;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls++;
    expect(serverClientId, GoogleAuthService.googleClientId);
    if (failNext) {
      failNext = false;
      throw StateError('SDK initialization failed');
    }
    await initialization.future;
  }

  @override
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      events.stream;

  @override
  Future<GoogleSignInAccount?> attemptLightweightAuthentication({
    bool reportAllExceptions = false,
  }) async {
    lightweightCalls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => expect(
      GoogleAuthService.googleClientId,
      isNotEmpty,
      reason: 'Run with the workflow configured-auth dart-define.',
    ),
  );

  test('concurrent init shares the SDK and creates one subscription', () async {
    final sdk = _SignIn();
    final service = GoogleAuthService(signIn: sdk);
    addTearDown(sdk.events.close);
    addTearDown(service.dispose);
    final first = service.init();
    final second = service.init();
    expect(sdk.initializeCalls, 1);
    sdk.initialization.complete();
    await Future.wait([first, second]);
    expect(service.isInitialized, isTrue);
    expect(sdk.lightweightCalls, 1);
    await service.init();
    expect(sdk.initializeCalls, 1);
  });

  test(
    'new bootstrap owner reuses initialized SDK after prior owner disposal',
    () async {
      final sdk = _SignIn()..initialization.complete();
      addTearDown(sdk.events.close);
      final first = GoogleAuthService(signIn: sdk);
      await first.init();
      expect(sdk.events.hasListener, isTrue);
      first.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(sdk.events.hasListener, isFalse);
      final retry = GoogleAuthService(signIn: sdk);
      addTearDown(retry.dispose);
      await retry.init();
      expect(sdk.initializeCalls, 1);
      expect(sdk.lightweightCalls, 2);
      expect(sdk.events.hasListener, isTrue);
    },
  );

  test(
    'SDK initialization failure is not cached and same owner can retry',
    () async {
      final sdk = _SignIn()
        ..failNext = true
        ..initialization.complete();
      final service = GoogleAuthService(signIn: sdk);
      addTearDown(sdk.events.close);
      addTearDown(service.dispose);
      await expectLater(service.init(), throwsStateError);
      expect(service.isInitialized, isFalse);
      expect(sdk.events.hasListener, isFalse);
      await service.init();
      expect(service.isInitialized, isTrue);
      expect(sdk.initializeCalls, 2);
      expect(sdk.lightweightCalls, 1);
    },
  );
}
