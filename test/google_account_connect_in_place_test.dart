import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_follow_notifications_screen.dart';
import 'package:niarim/screens/rewards/rewards_sign_in_button.dart';
import 'package:niarim/services/community_notice.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/widgets/legal_consent.dart';
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
  GoogleSignInAccount? _current;
  int chooserRequests = 0;
  Completer<void>? gate;
  bool cancel = false;

  @override
  GoogleSignInAccount? get account => _current;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => _current != null;

  @override
  Future<GoogleSignInAccount> signInInteractively() async {
    chooserRequests++;
    await gate?.future;
    if (cancel) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    _current = _Account('viewer');
    notifyListeners();
    return _current!;
  }
}

/// 「Googleアカウントを連携」は押した画面のままGoogleアカウントでログイン
/// する（利用者の動きで見つかったこと：押すと「自分の投稿」へ移るだけで、
/// そこには「Googleアカウントを追加」とあり、押したボタンと名前も行き先も
/// 食い違っていた）。
void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      kLegalConsentVersionKey: kLegalDocumentsVersion,
      kLegalConsentAgreedAtKey: '2026-11-23T00:00:00.000Z',
    }),
  );

  Future<_Auth> pump(WidgetTester tester, Widget home) async {
    final auth = _Auth();
    final community = CommunityService();
    addTearDown(community.dispose);
    addTearDown(auth.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: communityMyWorksRoute,
          builder: (_, _) => const Scaffold(body: Text('My posts')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: community),
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  final l10n = lookupAppLocalizations(const Locale('ja'));

  testWidgets('the notifications screen signs in where the button is', (
    tester,
  ) async {
    final auth = await pump(tester, const CommunityFollowNotificationsScreen());
    expect(
      find.text(l10n.communityFollowNotificationsSignInRequired),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.communitySignInPromptConnect));
    await tester.pumpAndSettle();
    expect(auth.chooserRequests, 1);
    expect(find.text('My posts'), findsNothing);
    expect(find.byType(CommunityFollowNotificationsScreen), findsOneWidget);
    expect(
      find.text(l10n.communityFollowNotificationsSignInRequired),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button waits for the chooser and tells a cancel', (
    tester,
  ) async {
    final auth = await pump(
      tester,
      const Scaffold(body: Center(child: RewardsSignInButton())),
    );
    auth
      ..gate = Completer<void>()
      ..cancel = true;
    final button = find.byKey(const Key('rewardsSignInButton'));
    await tester.tap(button);
    await tester.pump();
    expect(auth.chooserRequests, 1);
    // ログインの途中は押せない（二度押しで2回選ばせない）。
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(auth.chooserRequests, 1);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.communitySignInFailed(l10n.communityErrorSignInCanceled)),
      findsOneWidget,
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    expect(find.text('My posts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
