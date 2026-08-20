import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
/// 法的確認を経たものではない。
///
/// 多言語対応（タスク#102）について：利用規約と同様、本文を含め画面全体を
/// 7言語対応した。各言語の本文は、確定済みの
/// 日本語原文をAI翻訳・逆翻訳照合の上で反映したものであり、専門家
/// （弁護士等）による正式な法的確認を経たものではない点は日本語原文と
/// 同様。特に下記2点は、ユーザー自身の情報を反映した上で、いずれの
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
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // プライバシーポリシー本文自体が説明そのものであり、対応する専用の
      // ヘルプ項目が存在しないため、ヘルプアイコンは表示しない
      // （仕様書28：ヘルプアイコンは対応する項目を開けるページにのみ表示）。
      appBar: AppBar(title: Text(l10n.privacyPolicyScreenTitle)),
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
