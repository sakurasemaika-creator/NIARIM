import 'package:flutter/material.dart';
import '../../widgets/help_button.dart';

/// 利用規約・ライセンス画面。
///
/// 「本アプリの利用規約」は法的文書の正式なひな形ではなく、実際に配布する
/// 前に権利者・法務担当が内容を確認・差し替えることを前提とした仮の文面
/// である（TODOコメントで明記）。使用フォントのクレジットは各配布元の
/// ライセンス表記に基づく（フォント本体をアプリへ組み込み次第、正式な
/// 表記へ差し替える）。オープンソースライセンスはFlutter標準の
/// LicensePage（各パッケージのLICENSEファイルから自動収集）を利用する。
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('利用規約・ライセンス'), actions: const [HelpButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('本アプリの利用規約'),
          const Text(
            // TODO: 正式な利用規約が確定次第、この仮文面を差し替えること。
            '本アプリ（MIRANIMA）は個人・商用問わずご利用いただけます。'
            '本アプリの利用によって生じたいかなる損害についても、開発者は'
            '責任を負いません。本アプリで作成したコンテンツの著作権は'
            '作成者に帰属します。\n\n'
            '※本文面は仮の内容です。配布前に正式な利用規約への差し替えが'
            '必要です。',
          ),
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
            usage: 'チュートリアル・説明・演出テキスト',
            name: 'くらむぼん',
            author: '配布元の表記に基づき別途確認',
            license: '配布元の利用規約に準拠',
            note: 'Delagothic（Google Fonts）派生のフリーフォント。個人・'
                '商用サイトでの利用は無償だが、配布元によって利用範囲の'
                '制限や使用報告が求められる場合があるため、フォント本体'
                '同梱時に配布元の同梱ライセンス文書を確認して正式な表記へ'
                '更新すること。',
          ),
          const _FontCredit(
            usage: '数値表示',
            name: 'Android標準フォント（Roboto / Noto Sans）',
            author: 'Google',
            license: 'Apache License 2.0 / SIL Open Font License',
            note: 'Android OS標準搭載フォントをそのまま使用（追加の同梱・'
                '個別クレジット表記は不要）。',
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
