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
/// 望ましい（画面上の注意書きは削除済み）。
/// 使用フォントのクレジットは各配布元が同梱するライセンス文書
/// （OFL.txt等）に基づく。オープンソースライセンスはFlutter標準の
/// LicensePage（各パッケージのLICENSEファイルから自動収集）を利用する。
///
/// 多言語対応（タスク#102）について：利用規約12条の本文を含め、画面
/// 全体を7言語対応した（本文も翻訳対象に追加）。
/// 各言語の本文は、確定済みの日本語原文をAI翻訳・逆翻訳照合の上で
/// 反映したものであり、専門家（弁護士・専門翻訳者等）による正式な
/// 法的確認を経たものではない点は日本語原文と同様。公開前に各言語版を
/// 専門家に確認いただくことが引き続き望ましい。使用フォントのクレジット
/// （作者名・ライセンス名などの固有名詞情報）は、表記の正確性を優先し
/// 翻訳対象外のままとしている。
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
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(l10n.licenseFontCreditMeta(author, license), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
