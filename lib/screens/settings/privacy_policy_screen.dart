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
/// 法的確認を経たものではない。
///
/// 多言語対応（タスク#102）について：利用規約と同様、ユーザーの指示に
/// より本文を含め画面全体を7言語対応した。各言語の本文は、確定済みの
/// 日本語原文をAI翻訳・逆翻訳照合の上で反映したものであり、専門家
/// （弁護士等）による正式な法的確認を経たものではない点は日本語原文と
/// 同様。特に下記2点は、ユーザー自身の情報を反映した上で、いずれの
/// 言語版についても公開前に確認・補完する必要がある。
/// - 「お問い合わせ先」：現時点でメールアドレス等の連絡先情報が
///   未確定のため、全言語共通でプレースホルダーのままとなっている。
/// - Google Playの「データセーフティ」フォームの申告内容は、本画面の
///   記載と整合させる必要がある（本アプリが自ら収集するデータはないが、
///   AdMob経由で広告ID等が取得される点、Google Play Billingを通じた
///   決済が行われる点を、フォーム上の該当項目でも申告すること）。
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
