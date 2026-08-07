import 'package:flutter/material.dart';
import '../../widgets/help_button.dart';

/// 利用規約・ライセンス画面。
///
/// 「本アプリの利用規約」はAIが一般的な項目を踏まえて生成した文面であり、
/// 正式な法的文書として権利者・法務担当の確認を経たものではない
/// （TODOコメントで明記）。使用フォントのクレジットは各配布元が同梱する
/// ライセンス文書（OFL.txt等）に基づく。オープンソースライセンスは
/// Flutter標準のLicensePage（各パッケージのLICENSEファイルから自動収集）
/// を利用する。
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('利用規約・ライセンス'), actions: const [HelpButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('利用規約'),
          // TODO: 正式なリリース前に、法務担当・権利者による確認・修正を
          // 経た内容へ差し替えること。以下はAIが一般的なアプリの利用規約に
          // 必要と考えられる項目を踏まえて生成した文面。
          const _TermsBody(),
          const SizedBox(height: 24),
          _SectionTitle('使用フォントについて'),
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
            usage: 'テキストツール同梱フォント（フォント選択から利用可能）',
            name: 'Noto Sans JP / Noto Serif JP / M PLUS Rounded 1c / '
                'Mochiy Pop One / Yusei Magic / Hachi Maru Pop / Reggae One',
            author: 'Google Fonts（各フォントの制作者）',
            license: 'SIL Open Font License 1.1',
            note: '個人・商用問わず無償で利用可能。Noto Serif JPは白光明朝'
                'のフォント未対応文字の補完（フォールバック）にも使用する。',
          ),
          const SizedBox(height: 24),
          _SectionTitle('オープンソースソフトウェアライセンス'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: const Text('使用ライブラリのライセンス一覧'),
            subtitle: const Text('本アプリが使用するOSSパッケージのライセンスを表示します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MIRANIMA',
            ),
          ),
        ],
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
      'この利用規約（以下「本規約」）は、本アプリ「MIRANIMA」（以下「本アプリ」）の'
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
          'クラウド同期）。',
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
      '第8条（提供の停止・変更・終了）',
      '開発者は、ユーザーへの事前告知の有無にかかわらず、本アプリの内容を'
          '変更し、または提供を停止・終了することができるものとします。'
          'これによってユーザーに生じた損害について、開発者は責任を負い'
          'ません。',
    ),
    (
      '第9条（免責事項）',
      '開発者は、本アプリに事実上または法律上の瑕疵がないこと（安全性・'
          '信頼性・正確性・完全性・特定目的適合性・バグや不具合がないこと'
          '等を含みます）を保証するものではありません。本アプリの利用に'
          'よってユーザーに生じた損害について、開発者に故意または重過失が'
          'ある場合を除き、開発者は責任を負いません。作成データの消失に'
          '備え、ユーザー自身による定期的なバックアップ（書き出し・共有'
          '機能の利用）を推奨します。',
    ),
    (
      '第10条（本規約の変更）',
      '開発者は、必要と判断した場合には、ユーザーへの個別の通知なく本規約を'
          '変更できるものとします。変更後の利用規約は、本画面に掲載された'
          '時点から効力を生じるものとします。',
    ),
    (
      '第11条（準拠法・裁判管轄）',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usage,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('作者：$author　ライセンス：$license', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
