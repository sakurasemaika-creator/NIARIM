import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 利用規約・ライセンス画面。
///
/// 利用規約12条の本文は、初版（AI生成の一般的な草稿）に対しユーザーが
/// 外部レビュー（複数のAIによる法務的観点からの指摘：消費者契約法との
/// 関係での免責範囲、コンテンツ権利の帰属表現、広告・個人情報記載の
/// 明確化、規約変更時の周知手続き等）を踏まえて改訂を指示し、その内容を
/// 反映した版。
/// 使用フォントのクレジットは各配布元が同梱するライセンス文書
/// （OFL.txt等）に基づく。オープンソースライセンスはFlutter標準の
/// LicensePage（各パッケージのLICENSEファイルから自動収集）を利用する。
///
/// 第8条（情報の取扱い）1項には、外部レビュー（ChatGPT）の指摘を受けて
/// 「開発者はこれらを自ら保存する機能を持たないため、開発者側での
/// 保存期間という概念自体がない」旨を追記済み（プライバシーポリシー
/// 第2条の同種の追記と対応。詳細はprivacy_policy_screen.dart参照）。
///
/// ### 追記（外部レビュー反映・利用規約のブラッシュアップ第2弾）
/// ユーザーが重ねてChatGPTから受けた利用規約向けの法務アドバイスのうち、
/// 以下2点をコードへ反映した（7言語すべて）。
/// - **第6条（プレミアム機能・課金）**：「年額プランまたは月額プラン」を
///   将来のプラン追加にも対応できるよう「月額プラン、年額プランその他の
///   プレミアムプラン」という表現へ一般化。3項（返金）へ「法令に別段の
///   定めがある場合は、その定めに従う」旨を追記し、Google Playの規定が
///   常に優先されるかのような誤解を避けるようにした。4項の「予告なく
///   変更することがあります」は、消費者契約法上、事業者の裁量が広すぎる
///   条項として問題視されうるため、「合理的な理由」に基づく変更へ限定し、
///   重要な変更は事前告知する旨を追記した（第9条の既存の書きぶりと
///   揃えた）。
/// - **第8条（情報の取扱い）**：AdMob・Google Play Billing・クラッシュ
///   解析の詳細な列挙をプライバシーポリシーと二重管理していたため、
///   利用規約側は「サーバーに保存しない」という原則と「詳細は
///   プライバシーポリシーを参照」という導線のみへ簡略化した（SDK構成の
///   変更のたびに利用規約まで改定する必要をなくすため）。
///
/// 一方、外部レビューが「簡略化してもよい」とした以下2点は、あえて
/// 現状維持とした（開発者にとって有利な具体的な保護規定を、単純化の
/// ためだけに削るのは合理的でないと判断）。
/// - 第10条の損害賠償上限（直近1年間の支払額、無料利用なら0円）は、
///   具体的な上限を明記することで開発者側の責任範囲がより明確になる
///   ため維持。
/// - 第12条の専属的合意管轄裁判所の指定自体は、紛争時に開発者が不利な
///   遠隔地の裁判所へ出廷するリスクを避けられるため維持。ただし
///   バーチャルオフィスを利用する場合は実際の所在地と無関係な特定の
///   市名を書くと矛盾しうるため、
///   「札幌地方裁判所または札幌簡易裁判所」という市名固定の書き方から
///   「開発者の所在地を管轄する地方裁判所または簡易裁判所」という、
///   将来どの市区町村に事業所（バーチャルオフィス含む）を置いても
///   自動的に整合する表現へ改めた（7言語すべて反映）。
///
/// 第6条（プレミアム機能・課金）の「月額プラン、年額プランその他の
/// プレミアムプラン」という記載は、実際の課金実装（`PremiumService`の
/// `monthlyProductId`・`yearlyProductId`によるサブスクリプション2種）と
/// 一致していることを確認済み。
///
/// 多言語対応について：利用規約13条の本文を含め、画面
/// 全体を7言語対応している（本文も翻訳対象）。
/// 各言語の本文は、確定済みの日本語原文をAI翻訳・逆翻訳照合の上で
/// 反映したもの。使用フォントのクレジット
/// （作者名・ライセンス名などの固有名詞情報）は、表記の正確性を優先し
/// 翻訳対象外のままとしている。
///
/// ### 追記（第12条「作品広場：コミュニティ投稿機能」を新設）
/// `29_動画投稿・ランキング機能仕様.md`18章が指摘していた「規約側に
/// 未反映のUGC対応・投稿上限・削除連動の利用条件」を反映するため、
/// 新しい第12条を追加した（旧第12条「準拠法・裁判管轄」は第13条へ
/// 繰り下げ。条文中に他条番号への相互参照は無いことを確認済みのため、
/// 繰り下げによる既存条文の不整合は無い）。あわせて第4条2項に、
/// 「作品広場を利用して投稿する場合の取扱いは第12条による」旨の
/// 相互参照を追記し、「本アプリはサーバーへ送受信しない」という
/// 従来の記載と矛盾しないようにした。第12条の内容は、通報・ブロックの
/// 実バックエンドやYouTube連携（OAuth審査含む）が未実装の現時点でも
/// 記載自体は矛盾しない（同機能を実際に有効化する前の利用条件の
/// 明文化として先行して整備した）。
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // 規約・ライセンス本文自体が説明そのものであり、対応する専用の
      // ヘルプ項目が存在しないため、ヘルプアイコンは表示しない。
      appBar: AppBar(title: Text(l10n.licenseScreenTitle)),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(l10n.licenseSectionTerms),
          const _TermsBody(),
          const SizedBox(height: 24),
          _SectionTitle(l10n.licenseSectionFonts),
          const _FontCredit(
            usage: 'アプリ全体の基本フォント',
            name: '白光明朝（はっこうみんちょう）',
            author: 'lavsic',
            license: 'SIL Open Font License 1.1',
          ),
          const _FontCredit(
            usage: 'チュートリアル・説明テキスト',
            name: 'くらむぼん',
            author: 'Yoshikawa Kinomi（フロップデザイン）／The Dela Gothic Project Authors',
            license: 'SIL Open Font License 1.1',
          ),
          const _FontCredit(
            usage: '数値表示',
            name: 'Android標準フォント（Roboto / Noto Sans）',
            author: 'Google',
            license: 'Apache License 2.0 / SIL Open Font License',
          ),
          const _FontCredit(
            usage: 'くらむぼんに無い文字の代替表示',
            name: 'Dela Gothic One',
            author: 'The Dela Gothic Project Authors',
            license: 'SIL Open Font License 1.1',
          ),
          const _FontCredit(
            usage: 'テキストツール同梱フォント',
            name: 'Noto Serif JP',
            author: 'Google Fonts',
            license: 'SIL Open Font License 1.1',
          ),
          const _FontCredit(
            usage: 'テキストツール追加フリーフォント（設定 → フォント管理 → '
                '追加フリーフォントを探す、からダウンロードして利用可能。'
                '初回のみネット接続が必要）',
            name: 'Google Fonts 全書体（約2000書体。SIL Open Font License /'
                ' Apache License 2.0 / Ubuntu Font License いずれかで'
                '配布されているもの全て）',
            author: 'Google Fonts（各フォントの制作者・詳細はダウンロード'
                '画面から各フォント名で確認可能）',
            license: 'SIL Open Font License 1.1 / Apache License 2.0 / '
                'Ubuntu Font License 1.0（フォントごとに異なる。いずれも'
                '個人・商用問わず無償で利用可能）',
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.licenseSectionIcons),
          const _FontCredit(
            usage: '消しゴム・バケツ塗り・図形ツールのアイコン',
            name: 'Font Awesome Free',
            author: 'Fonticons, Inc.',
            license: 'アイコン：CC BY 4.0 / フォント：SIL Open Font License 1.1 '
                '（font_awesome_flutterパッケージ自体はMIT License。'
                'https://fontawesome.com/license/free）',
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.licenseSectionOss),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: Text(l10n.licenseOssListTitle),
            subtitle: Text(l10n.licenseOssListSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'NIARIM',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.licenseFfmpegNote,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      )),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Kuramubon')),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (l10n.licenseTermsArt1Title, l10n.licenseTermsArt1Body),
      (l10n.licenseTermsArt2Title, l10n.licenseTermsArt2Body),
      (l10n.licenseTermsArt3Title, l10n.licenseTermsArt3Body),
      (l10n.licenseTermsArt4Title, l10n.licenseTermsArt4Body),
      (l10n.licenseTermsArt5Title, l10n.licenseTermsArt5Body),
      (l10n.licenseTermsArt6Title, l10n.licenseTermsArt6Body),
      (l10n.licenseTermsArt7Title, l10n.licenseTermsArt7Body),
      (l10n.licenseTermsArt8Title, l10n.licenseTermsArt8Body),
      (l10n.licenseTermsArt9Title, l10n.licenseTermsArt9Body),
      (l10n.licenseTermsArt10Title, l10n.licenseTermsArt10Body),
      (l10n.licenseTermsArt11Title, l10n.licenseTermsArt11Body),
      (l10n.licenseTermsArt12Title, l10n.licenseTermsArt12Body),
      (l10n.licenseTermsArt13Title, l10n.licenseTermsArt13Body),
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

class _FontCredit extends StatelessWidget {
  final String usage;
  final String name;
  final String author;
  final String license;

  const _FontCredit({
    required this.usage,
    required this.name,
    required this.author,
    required this.license,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // usage/name/authorは法務未確認の草稿段階かつライセンス表記の
            // 正確性が求められるため、翻訳対象外（日本語固定。クラス冒頭の
            // コメント参照）。各フォントのライセンス条件に関する説明文（旧
            // note）は、フォント名・使用箇所・作者・
            // ライセンス・クレジット表示のみを残す形で削除した。
            Text(usage,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Kuramubon')),
            Text(l10n.licenseFontCreditMeta(author, license), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
