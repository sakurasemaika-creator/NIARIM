import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/advertising_service.dart';

/// プライバシーポリシー画面。
///
/// 利用規約（license_screen.dart）とは独立した文書として新設した
/// （ChatGPT・Geminiによる外部レビューの指摘：AdMob・広告識別子・
/// Google Play Billing・端末内データ保持・将来のSDK追加時の扱い等は、
/// 利用規約より独立したプライバシーポリシーで詳細に説明する方が
/// 整理しやすいとの指摘を受けて新設）。
///
/// 本文の内容はAIが一般的なプライバシーポリシーとして必要と考えられる
/// 項目を踏まえて生成した草稿。
///
/// 多言語対応について：利用規約と同様、本文を含め画面全体を
/// 7言語対応している。各言語の本文は、確定済みの
/// 日本語原文をAI翻訳・逆翻訳照合の上で反映したもの。特に下記2点は、
/// ユーザー自身の情報を反映した上で、いずれの
/// 言語版についても公開前に確認・補完する必要がある。
/// - 「お問い合わせ先」：現時点でメールアドレス等の連絡先情報が
///   未確定のため、全言語共通でプレースホルダーのままとなっている。
///   外部レビュー（ChatGPT）の指摘どおり、普段使いの個人アドレスでは
///   なく、本アプリ専用の連絡先（例：niarim.app@gmail.com のような
///   形の無料Gmailアドレス）を新規に用意し、それをここへ反映するのが
///   望ましい。
/// - Google Playの「データセーフティ」フォームの申告内容は、本画面の
///   記載と整合させる必要がある（本アプリが自ら収集するデータはないが、
///   AdMob経由で広告ID等が取得される点、Google Play Billingを通じた
///   決済が行われる点を、フォーム上の該当項目でも申告すること）。実際に
///   組み込んだAdMob SDKの広告設定（パーソナライズド広告の可否、
///   同意取得の有無、対象年齢設定等）が固まった時点で、第3条の記載も
///   その内容に即して見直すこと。
///
/// ### 追記（外部レビュー反映・ブラッシュアップ）
/// ユーザーがChatGPTから受けた法務アドバイスを踏まえ、以下2点を修正した。
/// - 第3条冒頭の「開発者自身がこれらの情報を直接取得・保管することは
///   ありません」という断定的な表現は、開発者が制御できないGoogle側の
///   挙動まで保証してしまう危険があるため、「本アプリの開発者は、これら
///   の情報を独自に取得・保存する機能を実装していません」という、実装
///   事実に即した表現へ弱めた（7言語すべて反映）。
/// - Google Playが要求する「データの保存期間・削除ポリシー」の記載が
///   明示的でなかったため、第2条へ「開発者側での保存期間という概念
///   自体がない」旨を明文化した（サーバーを持たないNIARIMの構成上、
///   この説明が可能）。
/// なお、「裁判管轄」等の紛争解決条項は利用規約（license_screen.dart）
/// 側にのみ置き、本ポリシーには含めない方針を維持している（本ポリシーは
/// データの取扱いの説明に専念する）。また、日本国内で有料アプリ内課金を
/// 提供する場合に必要となる特定商取引法に基づく表示は、事業者名・
/// 電話番号・所在地等、開発者自身の実際の情報（バーチャルオフィス利用の
/// 要否を含む）が確定してから別途対応する事項であり、本ポリシー・利用規約
/// には含めていない（コードでは解決できない対応待ち事項として
/// `28_継続タスク（未着手一覧）.md`に記載）。
///
/// ### 追記（実装とポリシー記載内容の突き合わせで発覚した不足の解消）
/// 利用規約・プライバシーポリシーの7言語見直し作業の一環で、実際の
/// コード実装（AdMob・広告ID・Google Play Billing等の第三者サービス
/// 組み込み状況）とプライバシーポリシーの記載内容を突き合わせた結果、
/// 「EEA（欧州経済領域）・英国・スイスのユーザーへ広告を配信するには
/// IAB TCF準拠の同意管理プラットフォーム（CMP）の導入がGoogleの
/// ポリシー上必須（2024年1月16日以降）」であるにもかかわらず、
/// `AdvertisingService`にその導入が無いという不足を発見した。
/// `google_mobile_ads`パッケージに同梱されているUMP（User Messaging
/// Platform）SDKを使い、広告SDKの初期化前に必ず同意フローを済ませる形へ
/// `AdvertisingService`を修正した（追加のパッケージ依存は不要。詳細は
/// `advertising_service.dart`参照）。本画面下部の「広告の同意設定を
/// 変更」ボタンは、CMP対象地域のユーザーにのみ表示される、Googleの
/// ポリシー上必須の「いつでも同意設定を変更できる」導線。
///
/// ### 追記（第7条「NIARIM作品広場：コミュニティ投稿機能における
/// 情報の取扱い」を新設）
/// `29_動画投稿・ランキング機能仕様.md`18章が指摘していた、規約側
/// （利用規約第12条、license_screen.dart）と対になるプライバシー
/// ポリシー側の反映として追加した（旧第7条「本ポリシーの変更」・
/// 旧第8条「お問い合わせ」はそれぞれ第8条・第9条へ繰り下げ。条文中の
/// 相互参照は「第3条」を指すもの2件のみで、第7条以降を参照する記述は
/// 無いことを確認済みのため、繰り下げによる既存条文の不整合は無い）。
/// あわせて第2条に、「NIARIM作品広場を利用して投稿する場合の情報の
/// 取扱いは第7条による」旨の相互参照を追記し、「本アプリはサーバーへ
/// 送受信しない」という従来の記載と矛盾しないようにした。本機能の
/// 実バックエンド（通報・ブロック・YouTube連携含む）は未実装だが、
/// 実際に有効化する前の情報取扱いの明文化として先行して整備した。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // プライバシーポリシー本文自体が説明そのものであり、対応する専用の
      // ヘルプ項目が存在しないため、ヘルプアイコンは表示しない。
      appBar: AppBar(title: Text(l10n.privacyPolicyScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [_PolicyBody(), SizedBox(height: 16), _PrivacyOptionsButton()],
        ),
      ),
    );
  }
}

/// EEA・英国・スイス等、同意管理プラットフォーム（CMP）の対象地域の
/// ユーザーにのみ表示される「広告の同意設定を変更」ボタン。
/// `AdvertisingService.privacyOptionsRequirementStatus()`
/// （UMP SDKの`getPrivacyOptionsRequirementStatus()`）がrequiredを
/// 返した場合のみ表示する（Googleの同意管理ポリシー上、CMP導入時は
/// ユーザーがいつでも同意設定を変更できる導線を提供する必要がある）。
/// 対象外地域のユーザーやAdMob自体が無効な期間（`isMonetizationEnabled`
/// がfalseの間）は何も表示しない。
class _PrivacyOptionsButton extends StatelessWidget {
  const _PrivacyOptionsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final advertisingService = context.watch<AdvertisingService>();
    return FutureBuilder<PrivacyOptionsRequirementStatus>(
      future: advertisingService.privacyOptionsRequirementStatus(),
      builder: (context, snapshot) {
        if (snapshot.data != PrivacyOptionsRequirementStatus.required) {
          return const SizedBox.shrink();
        }
        return OutlinedButton.icon(
          onPressed: () => advertisingService.showPrivacyOptionsForm(),
          icon: const Icon(Icons.tune),
          label: Text(l10n.privacyPolicyAdConsentButton),
        );
      },
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (l10n.privacyPolicyArt1Title, l10n.privacyPolicyArt1Body),
      (l10n.privacyPolicyArt2Title, l10n.privacyPolicyArt2Body),
      (l10n.privacyPolicyArt3Title, l10n.privacyPolicyArt3Body),
      (l10n.privacyPolicyArt4Title, l10n.privacyPolicyArt4Body),
      (l10n.privacyPolicyArt5Title, l10n.privacyPolicyArt5Body),
      (l10n.privacyPolicyArt6Title, l10n.privacyPolicyArt6Body),
      (l10n.privacyPolicyArt7Title, l10n.privacyPolicyArt7Body),
      (l10n.privacyPolicyArt8Title, l10n.privacyPolicyArt8Body),
      (l10n.privacyPolicyArt9Title, l10n.privacyPolicyArt9Body),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, body) in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Kuramubon')),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12, height: 1.5)),
              ],
            ),
          ),
      ],
    );
  }
}
