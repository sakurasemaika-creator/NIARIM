import 'package:flutter/widgets.dart';

class CommunityWorkMetadataLabels {
  const CommunityWorkMetadataLabels._(this.values);
  final List<String> values;

  static CommunityWorkMetadataLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant' : locale.languageCode;
    return CommunityWorkMetadataLabels._(labels[language] ?? labels['en']!);
  }

  String get title => values[0];
  String get description => values[1];
  String get descriptionHint => values[2];
  String get edit => values[3];
  String get saved => values[4];
  String get info => values[5];
  String get loadFailed => values[6];
  String get youtubeDescription => values[7];
  String get youtubeDescriptionHint => values[8];
  String get youtubeDescriptionInvalid => values[9];

  static const labels = <String,List<String>>{
    'ja': ['作品タイトル','作品の概要欄','作品の説明や制作について（任意）',
      'タイトル・概要欄を編集','タイトルと概要欄を保存しました',
      'NIARIM内の情報を編集します。YouTube上のタイトル・概要欄は変わりません。',
      '概要欄を読み込めませんでした',
      'YouTubeの説明欄（任意）',
      'YouTube動画の説明。NIARIMの概要欄とは別に管理されます',
      'YouTubeの説明欄は5,000バイト以内で入力し、< と > は使用しないでください'],
    'en': ['Work title','Work description','About the work (optional)',
      'Edit title and description','Title and description saved',
      'This changes the NIARIM listing only, not the YouTube video details.',
      'Could not load the description',
      'YouTube description (optional)',
      'Separate from your NIARIM work description',
      'YouTube descriptions must be at most 5,000 bytes and cannot contain < or >'],
    'es': ['Título de la obra','Descripción','Acerca de la obra (opcional)',
      'Editar título y descripción','Título y descripción guardados',
      'Solo cambia los datos en NIARIM, no los de YouTube.',
      'No se pudo cargar la descripción',
      'Descripción de YouTube (opcional)',
      'Se gestiona por separado de la descripción en NIARIM',
      'La descripción de YouTube debe tener como máximo 5.000 bytes y no puede contener < ni >'],
    'fr': ['Titre de l’œuvre','Description','À propos de l’œuvre (facultatif)',
      'Modifier le titre et la description','Titre et description enregistrés',
      'Ces changements concernent NIARIM, pas YouTube.',
      'Impossible de charger la description',
      'Description YouTube (facultative)',
      'Distincte de la description de votre œuvre dans NIARIM',
      'La description YouTube doit faire au maximum 5 000 octets et ne pas contenir < ni >'],
    'ko': ['작품 제목','작품 설명','작품과 제작 과정에 대한 설명 (선택)',
      '제목과 설명 수정','제목과 설명을 저장했습니다',
      'NIARIM 표시만 변경하며 YouTube의 제목과 설명은 변경되지 않습니다.',
      '작품 설명을 불러오지 못했습니다',
      'YouTube 설명 (선택)',
      'NIARIM 작품 설명과 별도로 관리됩니다',
      'YouTube 설명은 5,000바이트 이하여야 하며 < 또는 >를 포함할 수 없습니다'],
    'zh': ['作品标题','作品简介','关于作品（选填）',
      '编辑标题和简介','标题和简介已保存',
      '仅修改 NIARIM 中的信息，不修改 YouTube 视频信息。',
      '无法加载作品简介',
      'YouTube 描述（选填）',
      '与 NIARIM 作品简介分别管理',
      'YouTube 描述不得超过 5,000 字节，也不能包含 < 或 >'],
    'zh_Hant': ['作品標題','作品簡介','關於作品（選填）',
      '編輯標題與簡介','標題與簡介已儲存',
      '僅修改 NIARIM 的資訊，不修改 YouTube 影片資訊。',
      '無法載入作品簡介',
      'YouTube 說明（選填）',
      '與 NIARIM 作品簡介分開管理',
      'YouTube 說明不得超過 5,000 位元組，也不可包含 < 或 >'],
  };
}
