import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/help_button.dart';

/// 利用規約・ライセンス画面。
///
/// 「本アプリの利用規約」はAIが一般的な項目を踏まえて生成した文面であり、
/// 正式な法的文書として権利者・法務担当の確認を経たものではない
/// （TODOコメントで明記）。使用フォントのクレジットは各配布元が同梱する
/// ライセンス文書（OFL.txt等）に基づく。オープンソースライセンスは
/// Flutter標準のLicensePage（各パッケージのLICENSEファイルから自動収集）
/// を利用する。
///
/// 多言語対応（タスク#102）について：画面のUI文言（タイトル・見出し・
/// OSSライセンス一覧の案内文等）は4言語対応したが、利用規約12条の本文と
/// 使用フォントのクレジット詳細（ライセンス条件の説明文）はあえて翻訳
/// 対象外としている。前者はまだ法務担当による確認を経ていない草稿段階
/// であり、後者はライセンス条件の正確な記述が求められるため、機械的に
/// 翻訳して誤ったニュアンスが生じるリスクを避けた。正式リリース前に
/// 法務担当の確認を経た上で、必要であれば専門の翻訳者による多言語化を
/// 別途行うことを推奨する。
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
          // TODO: 正式なリリース前に、法務担当・権利者による確認・修正を
          // 経た内容へ差し替えること。以下はAIが一般的なアプリの利用規約に
          // 必要と考えられる項目を踏まえて生成した文面。
          // 法務未確認の草稿段階のため、本文は翻訳対象外（日本語固定）。
          const _TermsBody(),
          const SizedBox(height: 24),
          _SectionTitle(l10n.licenseSectionFonts),
          const _FontCredit(
            usage: 'アプリ全体の基本フォント',
            name: '白光明朝（はっこうみんちょう）',
            author: 'lavsic',
            license: 'SIL Open Font License 1.1',
            note: 'Noto Serifを改変したフリーフォント。個人・商用問わず'
                '無償で利用可能（アプリ・ゲームへの組み込みも可）。',
          ),
          const _FontCredit(
            usage: 'チュートリアル・説明テキスト',
            name: 'くらむぼん',
            author: 'Yoshikawa Kinomi（フロップデザイン）／The Dela Gothic Project Authors',
            license: 'SIL Open Font License 1.1',
            note: 'DelaGothicの派生フリーフォント。個人・商用問わず無償で'
                '利用可能。配布元より下記クレジットの表示が推奨されている'
                'ため掲載する。\n'
                'フォント：くらむぼん／フリーダウンロード：'
                'https://www.flopdesign.com/freefont/kuramubon.html',
          ),
          const _FontCredit(
            usage: '数値表示',
            name: 'Android標準フォント（Roboto / Noto Sans）',
            author: 'Google',
            license: 'Apache License 2.0 / SIL Open Font License',
            note: 'Android OS標準搭載フォントをそのまま使用（追加の同梱・'
                '個別クレジット表記は不要）。',
          ),
          const _FontCredit(
            usage: 'テキストツール同梱フォント',
            name: 'Noto Serif JP',
            author: 'Google Fonts',
            license: 'SIL Open Font License 1.1',
            note: '個人・商用問わず無償で利用可能。白光明朝のフォント未対応'
                '文字の補完（フォールバック）にも使用する。',
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
            note: '初期インストール容量を抑えるため同梱せず、Google Fontsの'
                '配布元（GitHub: '
                'google/fonts）から取得する。ダウンロード後は端末内に'
                '保存され、以降オフラインでも利用できる。',
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
      'この利用規約（以下「本規約」）は、本アプリ「NIARIM」（以下「本アプリ」）の'
          '利用条件を定めるものです。本アプリをダウンロード・利用した時点で、'
          'ユーザーは本規約に同意したものとみなします。',
    ),
    (
      '第2条（利用資格・対応環境）',
      '本アプリはAndroid端末向けに提供されます。動作環境の詳細は配布ストアの'
          '記載に従います。低スペック端末でも動作するよう配慮していますが、'
          '端末の状態・設定によっては一部機能が制限される場合があります。',
    ),
    (
      '第3条（禁止事項）',
      'ユーザーは本アプリの利用にあたり、以下の行為をしてはなりません。\n'
          '・法令または公序良俗に違反する行為\n'
          '・本アプリまたは第三者の知的財産権、肖像権、プライバシー等の権利を'
          '侵害する行為\n'
          '・本アプリの逆コンパイル・逆アセンブル・リバースエンジニアリング'
          '等、解析を目的とする行為（法令上認められる場合を除く）\n'
          '・本アプリの不正な改造、複製、再配布\n'
          '・その他、開発者が不適切と判断する行為',
    ),
    (
      '第4条（作成コンテンツの著作権）',
      'ユーザーが本アプリを用いて作成したイラスト・アニメーション等の'
          'コンテンツ（プロジェクトデータ・書き出し画像・動画を含む）の'
          '著作権は、当該コンテンツを作成したユーザーに帰属します。本アプリは'
          '作成物をクラウドへ送信・収集することはありません（非対応機能：'
          'クラウド同期）。\n'
          '無料版・プレミアム版のいずれで作成した場合であっても、'
          '当該コンテンツの商用利用を制限するものではありません（無料版・'
          'プレミアム版の違いは、エンドカード表示や書き出し時間制限等の'
          '機能面に限られます）。ただし、同梱・追加したフォントや素材'
          'それぞれの利用条件（第5条）には従ってください。',
    ),
    (
      '第5条（同梱フォント・素材について）',
      '本アプリに同梱されるフォントは、本画面「使用フォントについて」に'
          '記載のライセンスに従い利用されています。ユーザーが本アプリに'
          '追加登録したフォント・素材（画像・トーン・スタンプ等）の権利関係'
          'については、ユーザー自身の責任において適法に利用してください。',
    ),
    (
      '第6条（プレミアム機能・課金）',
      '本アプリには無料版と、アプリ内課金により利用可能となるプレミアム版の'
          '機能があります。課金に関する詳細（価格・提供機能・決済方法）は'
          'アプリ内の購入画面の表示に従います。購入後の返金については、'
          'ご利用の決済プラットフォーム（Google Play等）の規定に従います。',
    ),
    (
      '第7条（広告表示）',
      '無料版では第三者配信の広告が表示される場合があります。広告配信に'
          '関する事項は各広告配信事業者のポリシーに従います。',
    ),
    (
      '第8条（個人情報の取り扱い）',
      '本アプリは、ユーザーが作成したイラスト・アニメーション等のコンテンツを'
          'サーバーへ送信・収集することはありません（第4条参照。プロジェクト'
          'データは端末内にのみ保存されます）。一方で、以下の情報については'
          '本アプリに組み込まれた外部サービスにより取得される場合があります。\n'
          '・広告配信：無料版ではGoogle社のAdMobを通じて広告を配信しており、'
          '広告の配信・効果測定のため広告識別子（Advertising ID）等の端末'
          '情報が取得される場合があります。取得・利用の詳細はGoogleの'
          'プライバシーポリシー（https://policies.google.com/privacy）を'
          'ご確認ください。端末設定から広告識別子のリセットや広告の'
          'パーソナライズ解除が可能です。\n'
          '・アプリ内課金：プレミアム機能の購入はGoogle Playの課金システム'
          'を通じて行われ、決済情報（カード番号等）を開発者側が取得・保持'
          'することはありません。取引情報の取り扱いはGoogle Playの規定に'
          '従います。\n'
          '・クラッシュ解析等：本アプリは現時点でクラッシュ解析・利用状況'
          '分析SDKを組み込んでいません。将来組み込む場合は本規約を更新し'
          'アプリ内で告知します。\n'
          'アプリをアンインストールした場合、端末内に保存された全ての'
          'データ（プロジェクト・設定・追加したフォント等）は削除されます。',
    ),
    (
      '第9条（提供の停止・変更・終了）',
      '開発者は、ユーザーへの事前告知の有無にかかわらず、本アプリの内容を'
          '変更し、または提供を停止・終了することができるものとします。'
          'これによってユーザーに生じた損害について、開発者は責任を負い'
          'ません。',
    ),
    (
      '第10条（免責事項）',
      '開発者は、本アプリに事実上または法律上の瑕疵がないこと（安全性・'
          '信頼性・正確性・完全性・特定目的適合性・バグや不具合がないこと'
          '等を含みます）を保証するものではありません。本アプリの利用に'
          'よってユーザーに生じた損害について、開発者に故意または重過失が'
          'ある場合を除き、開発者は責任を負いません。作成データの消失に'
          '備え、ユーザー自身による定期的なバックアップ（書き出し・共有'
          '機能の利用）を推奨します。',
    ),
    (
      '第11条（本規約の変更）',
      '開発者は、必要と判断した場合には、ユーザーへの個別の通知なく本規約を'
          '変更できるものとします。変更後の利用規約は、本画面に掲載された'
          '時点から効力を生じるものとします。',
    ),
    (
      '第12条（準拠法・裁判管轄）',
      '本規約の解釈にあたっては日本法を準拠法とします。本アプリに関して'
          '紛争が生じた場合には、開発者の所在地を管轄する裁判所を専属的'
          '合意管轄とします。',
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
        Text(
          '※本文はAIが一般的なアプリの利用規約として必要と考えられる項目を'
          '踏まえて生成した文面です。配布前に法務担当・権利者による確認・'
          '修正を行ってください。',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
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
  final String note;

  const _FontCredit({
    required this.usage,
    required this.name,
    required this.author,
    required this.license,
    required this.note,
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
            // usage/name/authorとnote（ライセンス条件の説明文）は法務未確認の
            // 草稿段階かつライセンス表記の正確性が求められるため、翻訳対象外
            // （日本語固定。クラス冒頭のコメント参照）。
            Text(usage,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(l10n.licenseFontCreditMeta(author, license), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
