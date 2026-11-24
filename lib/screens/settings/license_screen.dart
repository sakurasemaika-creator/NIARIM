import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../config/font_fallback.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/responsive.dart';
import '../../widgets/grouped_sheet.dart';

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
///
/// ### 追記（規約・法令コンプライアンス監査：第2条に未成年者条項を追加）
/// アプリ全体の規約・ライセンス面を横断監査した際、本アプリが
/// 有料課金（第6条）・作品広場でのUGC投稿（第12条）・広告配信を
/// 備えているにもかかわらず、第2条「利用資格」がOS/動作環境の話に
/// 終始しており、利用者自身の年齢・資格については一切触れていない
/// ことが判明した（絵柄・題材からも未成年ユーザーが一定数想定される
/// アプリである点を踏まえると看過できない抜けと判断）。第2条3項として
/// 「未成年者は保護者等の同意を得て利用する（有料機能含む）」という
/// 一般的な条項を7言語すべてに追加した。具体的な年齢の下限（13歳／
/// 18歳等、国・地域や適用法により異なる）はあえて明記せず、法定代理人の
/// 同意取得という形で汎用的に対応している。あわせて、Google
/// Playコンソール側の「対象年齢」宣言（本アプリのコード変更では設定
/// できない、ストア管理画面側の設定）を、この条項と矛盾しない内容に
/// しておくことを推奨する。
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontCatalogPath = [
      l10n.settingsScreenTitle,
      l10n.settingsFontTitle,
      l10n.fontSettingsTabSearch,
    ].join(' → ');
    return Scaffold(
      // 規約・ライセンス本文自体が説明そのものであり、対応する専用の
      // ヘルプ項目が存在しないため、ヘルプアイコンは表示しない。
      appBar: AppBar(title: FitOrHideTitle(l10n.licenseScreenTitle)),
      body: desktopCentered(
        context,
        maxWidth: 680,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(l10n.licenseSectionTerms),
            const _TermsBody(),
            const SizedBox(height: 24),
            _SectionTitle(l10n.licenseSectionFonts),
            // 書体・印の出どころは1枚の面に並べ、細い線で分ける（1件ずつの
            // カードにしない）。
            GroupedSheet(
              children: [
                _FontCredit(
                  usage: l10n.licenseCreditBody,
                  name: 'Hakkou Mincho',
                  author: 'lavsic',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditHeading,
                  name: 'Kuramubon',
                  author:
                      'Yoshikawa Kinomi (FLOP DESIGN) / The Dela Gothic Project Authors',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditNumbers,
                  name: 'Roboto / Noto Sans',
                  author: 'Google',
                  license: 'Apache License 2.0 / SIL Open Font License',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditCjkBody,
                  name: 'Noto Serif KR / Noto Serif SC',
                  author: 'Adobe',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditCjkHeading,
                  name: 'Noto Sans KR / Noto Sans SC Black',
                  author: 'Adobe',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditFallback,
                  name: 'Dela Gothic One',
                  author: 'The Dela Gothic Project Authors',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditTextTool,
                  name: 'Noto Serif JP',
                  author: 'Adobe',
                  license: 'SIL Open Font License 1.1',
                ),
                _FontCredit(
                  usage: l10n.licenseCreditCatalog(fontCatalogPath),
                  name: 'Google Fonts',
                  author: l10n.licenseCreditCatalogAuthor,
                  license:
                      '${l10n.licenseCreditCatalogLicense}\n'
                      'SIL Open Font License 1.1 / Apache License 2.0 / Ubuntu Font License 1.0',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(l10n.licenseSectionIcons),
            GroupedSheet(
              children: [
                _FontCredit(
                  usage: l10n.licenseCreditIcons,
                  name: 'Font Awesome Free',
                  author: 'Fonticons, Inc.',
                  license:
                      '${l10n.licenseCreditIconLicense}\n'
                      'https://fontawesome.com/license/free',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(l10n.licenseSectionOss),
            GroupedSheet(
              footer: l10n.licenseFfmpegNote,
              children: [
                SheetRow(
                  icon: Icons.code,
                  title: l10n.licenseOssListTitle,
                  subtitle: l10n.licenseOssListSubtitle,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'NIARIM',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: localizedHeadingStyle(
          context,
          const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            height: 1.3,
          ),
        ),
      ),
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
        Text(
          l10n.legalLastUpdated,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final (title, body) in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: localizedHeadingStyle(
                    context,
                    const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(fontSize: 14, height: 1.65)),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usage,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            name,
            style: localizedHeadingStyle(
              context,
              const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
          Text(
            l10n.licenseFontCreditMeta(author, license),
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}
