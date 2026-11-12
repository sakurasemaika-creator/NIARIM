import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';

class _FakeAccount implements GoogleSignInAccount {
  _FakeAccount(this.id);
  @override
  final String id;
  @override
  String get email => '$id@example.invalid';
  @override
  String get displayName => id;
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends GoogleAuthService {
  GoogleSignInAccount? _current;
  @override
  GoogleSignInAccount? get account => _current;
  void switchAccount(String? id) {
    _current = id == null ? null : _FakeAccount(id);
    notifyListeners();
  }
}

void main() {
  test(
    'coin Premium is revoked immediately on account switch and sign-out',
    () {
      final auth = _FakeAuth();
      final premium = PremiumService();
      premium.bindGoogleAuth(auth);
      final expiry = DateTime.now().add(const Duration(days: 7));
      auth.switchAccount('account-a');
      premium.applyServerCoinPremiumExpiry(expiry, accountId: 'account-a');
      expect(premium.hasCoinPremium, isTrue);

      auth.switchAccount('account-b');
      expect(premium.hasCoinPremium, isFalse);
      premium.applyServerCoinPremiumExpiry(expiry, accountId: 'account-a');
      expect(premium.hasCoinPremium, isFalse);

      premium.applyServerCoinPremiumExpiry(expiry, accountId: 'account-b');
      expect(premium.hasCoinPremium, isTrue);
      auth.switchAccount(null);
      expect(premium.hasCoinPremium, isFalse);

      premium.dispose();
      auth.dispose();
    },
  );

  test('unattributed entitlements cannot unlock a bound account', () {
    final auth = _FakeAuth()..switchAccount('account-a');
    final premium = PremiumService()..bindGoogleAuth(auth);
    premium.applyServerCoinPremiumExpiry(
      DateTime.now().add(const Duration(days: 1)),
    );
    expect(premium.hasCoinPremium, isFalse);
    premium.dispose();
    auth.dispose();
  });
  test('individual coin rights activate only their selected feature for the authenticated account', () {
    final auth = _FakeAuth()..switchAccount('account-a');
    final premium = PremiumService()..bindGoogleAuth(auth);
    final expiry = DateTime.now().add(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    premium.applyServerCoinBenefitEntitlements([
      {'feature':'toneCurve','status':'active','expiresAtEpochMs':expiry},
      {'feature':'watermark','status':'paused','expiresAtEpochMs':expiry},
      {'feature':'allAds','status':'active','expiresAtEpochMs':expiry},
      {'feature':'unknownBenefit','status':'active','expiresAtEpochMs':expiry},
    ],accountId:'account-a');
    expect(premium.isFeatureAvailable(PremiumFeature.toneCurve),isTrue);
    expect(premium.isFeatureAvailable(PremiumFeature.watermark),isFalse);
    expect(premium.isFeatureAvailable(PremiumFeature.endCardEdit),isFalse);
    expect(premium.isServerCoinBenefitActive('allAds'),isTrue);
    expect(premium.isServerCoinBenefitActive('unknownBenefit'),isFalse);
    expect(premium.isPremium,isFalse);
    auth.switchAccount('account-b');
    expect(premium.isFeatureAvailable(PremiumFeature.toneCurve),isFalse);
    expect(premium.isServerCoinBenefitActive('allAds'),isFalse);
    premium.dispose();auth.dispose();
  });

  test('expired, paused, and cross-account feature grants never unlock tools',(){
    final auth=_FakeAuth()..switchAccount('account-a');
    final premium=PremiumService()..bindGoogleAuth(auth);
    final valid=DateTime.now().add(const Duration(minutes:20))
        .millisecondsSinceEpoch;
    final stale=DateTime.now().subtract(const Duration(seconds:1))
        .millisecondsSinceEpoch;
    premium.applyServerCoinBenefitEntitlements([
      {'feature':'endCardEdit','status':'active','expiresAtEpochMs':stale},
      {'feature':'toneCurve','status':'paused','expiresAtEpochMs':valid},
    ],accountId:'account-a');
    expect(premium.isFeatureAvailable(PremiumFeature.endCardEdit),isFalse);
    expect(premium.isFeatureAvailable(PremiumFeature.toneCurve),isFalse);
    premium.applyServerCoinBenefitEntitlements([
      {'feature':'toneCurve','status':'active','expiresAtEpochMs':valid},
    ],accountId:'account-b');
    expect(premium.isFeatureAvailable(PremiumFeature.toneCurve),isFalse);
    premium.dispose();auth.dispose();
  });

}
