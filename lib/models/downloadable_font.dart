/// テキストツール用の「追加フリーフォント」カタログ（オンデマンド
/// ダウンロード方式。仕様書15）。
///
/// いずれもGoogle Fonts配布分（SIL Open Font License、日本語対応）で、
/// 初期インストール容量を抑えるためアプリには同梱せず、設定画面
/// 「フォント管理」からユーザーが選んだものだけをGitHub上のgoogle/fonts
/// リポジトリ（OFLライセンスの配布元そのもの）から取得する。ダウンロード
/// 後はFontService.importBundledFont()経由でユーザーフォントと同じ仕組みで
/// 端末内に保存・登録されるため、以降はオフラインでも利用できる
/// （再ダウンロードは不要）。
class DownloadableFontEntry {
  /// FontService内で安定的に使うID（FontAsset.id・フォントファミリー名の
  /// 元になるため、後から変更しないこと）。
  final String id;
  final String displayName;
  final String fileName;
  final String sourceUrl;
  final double approxSizeMB;

  const DownloadableFontEntry({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sourceUrl,
    required this.approxSizeMB,
  });
}

const kDownloadableFonts = [
  DownloadableFontEntry(
    id: 'dlfont_notosansjp',
    displayName: 'ノトサンス（ゴシック）',
    fileName: 'NotoSansJP.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf',
    approxSizeMB: 9.6,
  ),
  DownloadableFontEntry(
    id: 'dlfont_mplusrounded1c',
    displayName: 'M PLUS Rounded（丸ゴシック）',
    fileName: 'MPLUSRounded1c-Regular.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/mplusrounded1c/MPLUSRounded1c-Regular.ttf',
    approxSizeMB: 3.4,
  ),
  DownloadableFontEntry(
    id: 'dlfont_mochiypopone',
    displayName: 'もちぽっぷ',
    fileName: 'MochiyPopOne-Regular.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/mochiypopone/MochiyPopOne-Regular.ttf',
    approxSizeMB: 5.2,
  ),
  DownloadableFontEntry(
    id: 'dlfont_yuseimagic',
    displayName: '遊筆マジック（手書き風）',
    fileName: 'YuseiMagic-Regular.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/yuseimagic/YuseiMagic-Regular.ttf',
    approxSizeMB: 3.1,
  ),
  DownloadableFontEntry(
    id: 'dlfont_hachimarupop',
    displayName: 'はちまるポップ',
    fileName: 'HachiMaruPop-Regular.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/hachimarupop/HachiMaruPop-Regular.ttf',
    approxSizeMB: 4.4,
  ),
  DownloadableFontEntry(
    id: 'dlfont_reggaeone',
    displayName: 'レゲエワン（漫画・SFX向け）',
    fileName: 'ReggaeOne-Regular.ttf',
    sourceUrl:
        'https://raw.githubusercontent.com/google/fonts/main/ofl/reggaeone/ReggaeOne-Regular.ttf',
    approxSizeMB: 2.2,
  ),
];
