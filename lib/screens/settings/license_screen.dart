import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/help_button.dart';

/// 利用規約・ライセンス画面。
///
/// 利用規約12条の本文は、初版（AI生成の一般的な草稿）に対しユーザーが
/// 外部レビュー（複数のAIによる法務的観点からの指摘：消費者契約法との
/// 関係での免責範囲、コンテンツ権利の帰属表現、広告・個人情報記載の
/// 明確化、規約変更時の周知手続き等）を踏まえて改訂を指示し、その内容を
/// 反映した版。ただし専門家（弁護士等）による正式な法的確認を経たもの
/// ではない点は変わらないため、公開前に確認を受けることが引き続き
/// 望ましい（画面上の注意書きはユーザーの指示により削除済み）。
/// 使用フォントのクレジットは各配布元が同梱するライセンス文書
/// （OFL.txt等）に基づく。オープンソースライセンスはFlutter標準の
/// LicensePage（各パッケージのLICENSEファイルから自動収集）を利用する。
///
/// 多言語対応（タスク#102）について：画面のUI文言（タイトル・見出し・
/// OSSライセンス一覧の案内文等）は7言語対応したが、利用規約12条の本文
/// （法的文書としての正確性が特に求められる）と使用フォントのクレジット
/// （作者名・ライセンス名などの固有名詞情報）は引き続き翻訳対象外と
/// している。専門家の確認を経た最終版が確定した段階で、必要であれば
/// 専門の翻訳者による多言語化を別途行うことを推奨する。
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.licenseScreenTitle), actions: const [HelpButton()]),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(l10n.licenseSectionTerms),
          // 法的文書としての正確性が求められるため、本文は翻訳対象外
          // （日本語固定。クラス冒頭のコメント参照）。
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
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  static const _sections = [
    (
      '第1条（適用）',
      'この利用規約（以下「本規約」といいます。）は、本アプリ「NIARIM」'
          '（以下「本アプリ」といいます。）の利用条件を定めるものです。'
          'ユーザーは、本規約に同意の上、本アプリをご利用いただくものと'
          'します。本アプリを利用することにより、本規約に同意したものと'
          'みなします。',
    ),
    (
      '第2条（利用資格・対応環境）',
      '1. 本アプリは、Android端末向けに提供されます。対応OSや推奨動作'
          '環境の詳細は、各配布ストアおよび本アプリ内の表示に従います。\n'
          '2. 本アプリは、多様な性能の端末でも快適にご利用いただけるよう'
          '配慮して設計されていますが、端末の性能・OSのバージョン・空き'
          '容量・設定その他の利用環境によっては、一部機能が制限される、'
          'または正常に動作しない場合があります。',
    ),
    (
      '第3条（禁止事項）',
      'ユーザーは本アプリの利用にあたり、以下の行為をしてはなりません。\n'
          '・法令または公序良俗に違反する行為\n'
          '・本アプリ、開発者または第三者の著作権・商標権その他の知的財産権、'
          '肖像権、プライバシーその他の権利または利益を侵害する行為\n'
          '・本アプリの逆コンパイル、逆アセンブル、リバースエンジニアリング'
          'その他解析を目的とする行為（法令上認められる場合を除く）\n'
          '・本アプリの不正な改造、複製または再配布\n'
          '・本アプリまたはその提供基盤に対する不正アクセス、過度な負荷'
          'その他、正常な提供を妨げる行為\n'
          '・その他、開発者が合理的な理由に基づき不適切と判断する行為',
    ),
    (
      '第4条（作成コンテンツの権利）',
      '1. ユーザーが本アプリを利用して作成したイラスト・アニメーション等の'
          'コンテンツ（プロジェクトデータ・書き出した画像・動画等を含み'
          'ます。以下「作成コンテンツ」といいます。）に関する著作権その他の'
          '権利は、法令上認められる範囲において、当該コンテンツについて'
          '権利を有するユーザーまたは第三者に帰属します。\n'
          '2. 本アプリは、作成コンテンツを開発者のサーバーへ送信・収集・'
          '同期する機能を提供していません。プロジェクトデータは、原則として'
          'ユーザーの端末内にのみ保存されます。\n'
          '3. 無料版・プレミアム版のいずれを利用して作成した場合であっても、'
          '本アプリの利用料金やエディションを理由として、開発者が作成'
          'コンテンツの商用利用を制限することはありません（無料版・'
          'プレミアム版の違いは、エンドカード表示や書き出し時間の上限等の'
          '機能面に限られます）。\n'
          '4. 前項にかかわらず、ユーザーが本アプリに追加したフォント・画像・'
          '素材等、第三者が権利を有するものについては、それぞれの利用条件'
          '（第5条）に従う必要があります。',
    ),
    (
      '第5条（同梱フォント・追加素材について）',
      '1. 本アプリに同梱されるフォントその他の素材は、本画面「使用フォント'
          'について」に記載された各ライセンス条件に従い利用されています。\n'
          '2. ユーザーが本アプリに追加登録・読み込みしたフォント、画像、'
          'トーン、スタンプ等の素材の権利関係については、ユーザー自身の'
          '責任において、必要な権利または許諾を取得の上、適法にご利用'
          'ください。\n'
          '3. ユーザーによる第三者素材の利用に起因して第三者との間で紛争等'
          'が生じた場合、開発者は、法令上の責任を負う場合を除き、その責任'
          'を負いません。',
    ),
    (
      '第6条（プレミアム機能・課金）',
      '1. 本アプリには、無料でご利用いただける機能のほか、アプリ内課金'
          '（年額プランまたは月額プラン）により利用可能となるプレミアム'
          '機能があります。\n'
          '2. プレミアム機能の価格、提供内容、購入方法その他の条件は、'
          '購入時点における本アプリ内または配布ストアの表示に従います。\n'
          '3. 購入後のキャンセル・返金その他決済に関する事項は、Google Play'
          'その他ご利用の決済プラットフォームの規定に従います。\n'
          '4. 開発者は、法令上必要な場合を除き、プレミアム機能の内容を'
          '予告なく変更することがあります。',
    ),
    (
      '第7条（広告表示）',
      '1. 無料版では、第三者の広告配信サービスを通じた広告が表示される'
          '場合があります。\n'
          '2. 広告配信事業者による情報の取得・利用その他の取扱いについては、'
          '各広告配信事業者のプライバシーポリシーが適用されます。',
    ),
    (
      '第8条（情報の取扱い）',
      '1. 本アプリは、ユーザーが作成したイラスト・アニメーション等の'
          'コンテンツおよびプロジェクトデータを、開発者のサーバーへ送信・'
          '収集する機能を提供していません。これらは原則としてユーザーの'
          '端末内にのみ保存されます。\n'
          '2. 本アプリでは、以下の第三者サービスを利用しており、各サービス'
          'の提供者が、それぞれのサービス提供に必要な範囲で端末情報等を'
          '取得する場合があります。\n'
          '・広告配信：無料版ではGoogle AdMobを通じて広告を配信しており、'
          '広告の配信・効果測定・不正防止等の目的で、広告識別子'
          '（Advertising ID）等の端末情報が取得される場合があります。'
          '詳細はGoogleのプライバシーポリシー'
          '（https://policies.google.com/privacy）をご確認ください。'
          '端末の設定から、広告識別子のリセットやパーソナライズ広告の'
          '無効化が可能です。\n'
          '・アプリ内課金：プレミアム機能の購入はGoogle Playの決済システム'
          'を通じて行われます。開発者がクレジットカード番号等の決済情報を'
          '直接取得・保持することはありません。決済に関する情報の取扱いは'
          'Google Playの規定に従います。\n'
          '・クラッシュ解析・利用状況分析：本アプリは、現時点でこれらを'
          '目的としたSDKを組み込んでいません。将来組み込む場合は、本規約'
          'その他の関連する説明を更新し、本アプリ内で告知します。\n'
          '3. 本アプリをアンインストールした場合、端末内に保存されたデータ'
          '（プロジェクト、設定、追加したフォント等）は削除されます。',
    ),
    (
      '第9条（提供の停止・変更・終了）',
      '1. 開発者は、本アプリの保守・更新・修正を行う場合、提供基盤に'
          '不具合が生じた場合その他やむを得ない事情がある場合、本アプリの'
          '全部または一部の提供を一時的に停止することがあります。\n'
          '2. 開発者は、必要に応じて本アプリの内容を変更し、または本アプリ'
          'の提供を終了することがあります。\n'
          '3. 前2項の場合、緊急のときを除き、可能な限り事前に本アプリ内'
          'その他適切な方法で告知します。\n'
          '4. 本条に基づく変更・停止・終了によってユーザーに生じた損害に'
          'ついて、開発者は、法令上の責任を負う場合を除き、責任を負い'
          'ません。',
    ),
    (
      '第10条（免責事項）',
      '1. 開発者は、本アプリについて、事実上または法律上の瑕疵（安全性・'
          '信頼性・正確性・完全性・特定目的への適合性・バグや不具合が'
          'ないこと等を含みます。）がないことを保証するものではありません。\n'
          '2. ユーザーは、本アプリを自己の責任においてご利用いただくものと'
          'します。端末の故障・誤操作・OSの更新その他の事情によりデータが'
          '失われる場合がありますので、作成中のデータについては、書き出し・'
          '共有機能等を利用した定期的なバックアップを推奨します。\n'
          '3. 本アプリの利用によってユーザーに生じた損害について、開発者'
          'は、法令上認められる範囲で責任を負いません。ただし、開発者に'
          '故意または重過失がある場合はこの限りではなく、その場合であって'
          'も、開発者が負う損害賠償責任は、通常生じうる直接損害に限り、'
          'ユーザーが本アプリに関し直近1年間に実際に支払った金額（無料で'
          'ご利用の場合は0円）を上限とします。',
    ),
    (
      '第11条（本規約の変更）',
      '1. 開発者は、法令の改正、本アプリの内容の変更その他必要と判断した'
          '場合、本規約を変更することがあります。\n'
          '2. 本規約を変更する場合、変更内容および効力発生日を、本アプリ内'
          'その他適切な方法により、事前に周知します。\n'
          '3. 変更後の本規約は、法令上認められる範囲において、前項の効力'
          '発生日から適用されます。',
    ),
    (
      '第12条（準拠法・裁判管轄）',
      '1. 本規約の解釈にあたっては、日本法を準拠法とします。\n'
          '2. 本アプリに関して紛争が生じた場合には、開発者の所在地を管轄'
          'する裁判所を第一審の専属的合意管轄裁判所とします。',
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
            // note）は、ユーザーの指示によりフォント名・使用箇所・作者・
            // ライセンス・クレジット表示のみを残す形で削除した。
            Text(usage,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(l10n.licenseFontCreditMeta(author, license), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
