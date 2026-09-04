import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/monetization_gate.dart';
import '../utils/runtime_platform.dart';
import 'premium_service.dart';
import 'ad_provider.dart';
import 'admob_provider.dart';

/// 広告表示の窓口。画面側はこのサービス経由でのみ広告を扱い、
/// 広告SDK（AdMob）へ直接依存しない。プレミアム時は全広告を非表示にする。
/// `isMonetizationEnabled`がfalseの間（税務上の都合による一時停止期間）は
/// AdMob SDK自体を初期化せず、広告を一切表示しない。
///
/// EEA・英国・スイスのユーザーへ広告を配信するには、IAB TCF準拠の
/// 同意管理プラットフォーム（CMP）の導入がGoogleのポリシーで必須と
/// なっている（2024年1月16日以降。Google AdMob Help「Google consent
/// management requirements for serving ads in the EEA, the UK, and
/// Switzerland」参照）。`google_mobile_ads`パッケージに同梱されている
/// UMP（User Messaging Platform）SDKを使い、広告SDK自体の初期化前に
/// 必ず同意フローを済ませる（`_canRequestAds`がtrueになるまで広告を
/// 一切リクエストしない）。追加のパッケージ依存は不要。
class AdvertisingService extends ChangeNotifier {
  final PremiumService premiumService;
  late AdProvider _provider;
  // UMP（同意管理）フローの結果、広告をリクエストしてよいかどうか。
  // 同意フロー未実施・EEA等で同意未取得の間はfalseのままとし、
  // shouldShowAdsをfalseに固定して広告を一切表示しない。
  bool _canRequestAds = false;

  AdvertisingService({required this.premiumService});

  Future<void> init() async {
    _provider = AdMobProvider(onAdEvent: notifyListeners);
    // google_mobile_adsのUMPはAndroid/iOS専用。Windows上のwidget testや
    // Flutter WebでMethodChannelを呼ぶとMissingPluginExceptionが非同期に
    // 投げられ、アプリの起動自体が完了しなくなるため、対応OSでのみ実行する。
    // defaultTargetPlatformはwidget testでもAndroidを返すため、条件付き
    // import先で実際の実行OSを判定する（Webではdart:ioを読み込まない）。
    if (isMonetizationEnabled && supportsMobilePluginRuntime) {
      await _requestConsentThenInitialize();
    }
    premiumService.addListener(_onPremiumChanged);
  }

  /// UMP SDKで同意情報を取得・必要なら同意フォームを表示し、
  /// リクエスト可能と判定できた場合のみAdMob SDKを初期化する。
  Future<void> _requestConsentThenInitialize() async {
    final completer = Completer<void>();
    Future<void> finishUpConsentFlow() async {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (_canRequestAds) {
        await _provider.initialize();
      }
      if (!completer.isCompleted) completer.complete();
    }

    // 本アプリは13歳未満のお子様を主な対象として意図的に情報を収集する
    // ものではない（プライバシーポリシー第5条）ため、
    // tagForUnderAgeOfConsentはfalseで要求する。
    final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false);
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // フォームの読み込み・表示に失敗しても、以降の
          // canRequestAds()判定でリクエスト可否を最終確認する。
        }
        await finishUpConsentFlow();
      },
      (_) async {
        // 同意情報の更新自体に失敗した場合（通信エラー等）でも、
        // 既に同意取得済み・同意不要な地域であればcanRequestAds()が
        // trueを返すため、その場合のみ広告を有効化する
        // （Googleの公式サンプル実装と同じフォールバック方針）。
        await finishUpConsentFlow();
      },
    );
    return completer.future;
  }

  /// 設定画面等から「広告の同意設定を変更」ボタンを出すべきかどうか
  /// （EEA・英国等、同意管理の対象ユーザーにのみtrueを返す）。
  Future<PrivacyOptionsRequirementStatus> privacyOptionsRequirementStatus() =>
      ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

  /// 同意設定（パーソナライズ広告の可否等）を後からユーザー自身が
  /// 変更できるようにするための、Googleの同意プライバシーオプション
  /// フォームを表示する（CMPとして必須の導線）。
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) async {
      // 変更後、広告リクエスト可否が変わりうるため再判定する。
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  bool get shouldShowAds =>
      isMonetizationEnabled && !premiumService.isPremium && _canRequestAds;

  /// ロード済みバナー広告。未ロード・プレミアム時はnull（AdBannerWidgetが描画に使う）。
  BannerAd? get bannerAd => shouldShowAds ? _provider.currentBanner : null;

  /// ロード済み正方形広告。未ロード・プレミアム時はnull（処理中ダイアログが描画に使う）。
  BannerAd? get squareAd => shouldShowAds ? _provider.currentSquareAd : null;

  void _onPremiumChanged() {
    if (premiumService.isPremium) hideAllAds();
    notifyListeners();
  }

  Future<void> showBanner(AdPosition position) async {
    if (!shouldShowAds) return;
    await _provider.showBanner(position);
  }

  Future<void> showSquareAd() async {
    if (!shouldShowAds) return;
    await _provider.showSquareAd();
  }

  Future<void> hideAllAds() async {
    await _provider.hideAllAds();
    notifyListeners();
  }

  @override
  void dispose() {
    premiumService.removeListener(_onPremiumChanged);
    _provider.hideAllAds();
    super.dispose();
  }
}

enum AdPosition { top, bottom }
