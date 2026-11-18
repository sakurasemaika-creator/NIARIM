import 'dart:ui';

({String file, String layer, String view, String settings})
desktopCanvasMenuLabels(Locale locale) => switch (locale.languageCode) {
  'ja' => (file: 'ファイル', layer: 'レイヤー', view: '表示', settings: '設定'),
  'ko' => (file: '파일', layer: '레이어', view: '보기', settings: '설정'),
  'zh' when locale.scriptCode == 'Hant' => (
    file: '檔案',
    layer: '圖層',
    view: '檢視',
    settings: '設定',
  ),
  'zh' => (file: '文件', layer: '图层', view: '视图', settings: '设置'),
  'es' => (file: 'Archivo', layer: 'Capa', view: 'Ver', settings: 'Ajustes'),
  'fr' => (
    file: 'Fichier',
    layer: 'Calque',
    view: 'Affichage',
    settings: 'Paramètres',
  ),
  _ => (file: 'File', layer: 'Layer', view: 'View', settings: 'Settings'),
};
