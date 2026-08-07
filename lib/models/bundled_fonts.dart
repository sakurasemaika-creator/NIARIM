/// アプリにあらかじめ同梱しているフリーフォント一覧（仕様書02・15）。
/// いずれもGoogle Fonts配布分（SIL Open Font License、日本語対応）で、
/// pubspec.yamlの`fonts:`へアセットとして直接登録済みのため、ユーザーが
/// フォント管理から追加した場合と異なりFontServiceでの動的登録は不要。
/// ライセンス表記は設定画面「利用規約・ライセンス」を参照。
const kBundledFonts = [
  (family: 'NotoSansJP', displayName: 'ノトサンス（ゴシック）'),
  (family: 'NotoSerifJP', displayName: '源ノ明朝'),
  (family: 'MPLUSRounded1c', displayName: 'M PLUS Rounded（丸ゴシック）'),
  (family: 'MochiyPopOne', displayName: 'もちぽっぷ'),
  (family: 'YuseiMagic', displayName: '遊筆マジック（手書き風）'),
  (family: 'HachiMaruPop', displayName: 'はちまるポップ'),
  (family: 'ReggaeOne', displayName: 'レゲエワン（漫画・SFX向け）'),
];
