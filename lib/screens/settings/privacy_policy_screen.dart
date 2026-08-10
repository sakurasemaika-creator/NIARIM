import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/help_button.dart';

/// プライバシーポリシー画面。
///
/// 利用規約（license_screen.dart）とは独立した文書として新設した
/// （ChatGPT・Geminiによる外部レビューの指摘：AdMob・広告識別子・
/// Google Play Billing・端末内データ保持・将来のSDK追加時の扱い等は、
/// 利用規約より独立したプライバシーポリシーで詳細に説明する方が
/// 整理しやすいとの指摘を受けて新設）。
///
/// 本文の内容はAIが一般的なプライバシーポリシーとして必要と考えられる
/// 項目を踏まえて生成した草稿であり、専門家（弁護士等）による正式な
/// 法的確認を経たものではない。特に下記2点は、ユーザー自身の情報を
/// 反映した上で公開前に確認・補完する必要がある。
/// - 「お問い合わせ先」：現時点でメールアドレス等の連絡先情報が
///   未確定のため、プレースホルダーのままとなっている。
/// - Google Playの「データセーフティ」フォームの申告内容は、本画面の
///   記載と整合させる必要がある（本アプリが自ら収集するデータはないが、
///   AdMob経由で広告ID等が取得される点、Google Play Billingを通じた
///   決済が行われる点を、フォーム上の該当項目でも申告すること）。
///
/// 多言語対応（タスク#102）について：画面のUI文言（タイトル等）は
/// 7言語対応したが、本文は利用規約と同様の理由（法的文書としての正確性
/// が求められ、専門家の確認前の草稿段階であること）により翻訳対象外
/// としている。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyScreenTitle), actions: const [HelpButton()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [_PolicyBody()],
        ),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  static const _sections = [
    (
      '第1条（本ポリシーの位置づけ）',
      'このプライバシーポリシー（以下「本ポリシー」といいます。）は、'
          '本アプリ「NIARIM」（以下「本アプリ」といいます。）における'
          '情報の取扱いについて定めるものです。本アプリの利用条件全般に'
          'ついては別途「利用規約・ライセンス」画面をご確認ください。',
    ),
    (
      '第2条（本アプリが取得しないデータ）',
      '本アプリは、ユーザーが作成したイラスト・アニメーション等の'
          'コンテンツ（プロジェクトデータ・書き出し画像・動画等を含みます。'
          '以下同じです。）を、開発者のサーバーへ送信・収集・保存する'
          '機能を提供していません。これらのデータは、原則としてユーザーの'
          '端末内にのみ保存されます（クラウド同期機能は搭載していません）。'
          'アプリをアンインストールした場合、端末内に保存されたプロジェクト・'
          '設定・追加したフォント等のデータは削除されます。',
    ),
    (
      '第3条（第三者サービスによる情報の取得）',
      '本アプリは、以下の第三者サービスを組み込んでおり、それぞれの'
          'サービス提供者が、サービス提供に必要な範囲で情報を取得する'
          '場合があります。開発者自身がこれらの情報を直接取得・保管する'
          'ことはありません。\n\n'
          '【広告配信（Google AdMob）】\n'
          '無料版では、Google AdMobを通じて広告を配信しています。広告の'
          '配信、効果測定、不正防止等の目的で、広告識別子（Advertising ID）'
          'その他の端末情報が、Googleまたはその関連事業者によって取得・'
          '利用される場合があります。取得・利用の詳細は、Googleの'
          'プライバシーポリシー（https://policies.google.com/privacy）を'
          'ご確認ください。端末の設定（Android設定アプリの「プライバシー」'
          '等）から、広告識別子のリセットや、パーソナライズ広告の無効化が'
          '可能です。\n\n'
          '【アプリ内課金（Google Play Billing）】\n'
          'プレミアム機能の購入は、Google Playの決済システムを通じて'
          '行われます。クレジットカード番号等の決済情報は、開発者側が'
          '直接取得・保持することはありません。決済に関する情報の取扱いは、'
          'Google Playの規定に従います。\n\n'
          '【クラッシュ解析・利用状況分析】\n'
          '本アプリは、現時点でクラッシュ解析・利用状況分析を目的とした'
          'SDKを組み込んでいません。将来これらのサービスを導入する場合は、'
          '本ポリシーを更新し、本アプリ内で告知します。',
    ),
    (
      '第4条（Cookie等のトラッキング技術について）',
      '本アプリ自体はCookieを使用しませんが、第3条記載の広告配信サービス'
          '（Google AdMob）が、広告の配信・効果測定のために、これに類する'
          '識別技術（広告識別子等）を使用する場合があります。',
    ),
    (
      '第5条（お子様の個人情報について）',
      '本アプリは、13歳未満のお子様を主な対象として意図的に情報を収集'
          'するものではありません。保護者の方は、お子様が本アプリを利用'
          'する際、必要に応じて端末の設定からパーソナライズ広告の無効化'
          '等をご検討ください。',
    ),
    (
      '第6条（情報の越境移転について）',
      '第3条記載の第三者サービス（Google AdMob、Google Play Billing）'
          'は、Google社が世界各地で運用するサーバー上で処理される場合が'
          'あります。これらの取扱いについては、各サービスのプライバシー'
          'ポリシーが適用されます。',
    ),
    (
      '第7条（本ポリシーの変更）',
      '開発者は、法令の改正、本アプリの内容の変更その他必要と判断した'
          '場合、本ポリシーを変更することがあります。本ポリシーを変更する'
          '場合、変更内容および効力発生日を、本アプリ内その他適切な方法'
          'により、事前に周知します。',
    ),
    (
      '第8条（お問い合わせ）',
      '本ポリシーに関するお問い合わせは、下記の連絡先までご連絡ください。\n'
          '（開発者連絡先：未設定 ― 公開前にメールアドレス等の連絡先情報を'
          'ご記入ください）',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, body) in _sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12, height: 1.5)),
              ],
            ),
          ),
      ],
    );
  }
}
