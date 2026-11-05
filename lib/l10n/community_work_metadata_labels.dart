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
  String get youtubeTitle => values[10];
  String get copyTitleToYoutube => values[11];
  String get copyTitleToNiarim => values[12];
  String get copyDescriptionToYoutube => values[13];
  String get copyDescriptionToNiarim => values[14];
  String copyTooLong(int maximum) =>
      values[15].replaceAll('{max}', '$maximum');
  String get youtubeTitleRequired => values[16];

  static const labels = <String,List<String>>{
    'ja': ['作品タイトル','作品の概要欄','作品の説明や制作について（任意）',
      'タイトル・概要欄を編集','タイトルと概要欄を保存しました',
      'NIARIM内の情報を編集します。YouTube上のタイトル・概要欄は変わりません。',
      '概要欄を読み込めませんでした',
      'YouTubeの説明欄（任意）',
      'YouTube動画の説明。NIARIMの概要欄とは別に管理されます',
      'YouTubeの説明欄は5,000バイト以内で入力し、< と > は使用しないでください',
      'YouTubeのタイトル',
      'YouTubeのタイトルにコピー',
      'NIARIMのタイトルにコピー',
      'YouTubeの説明欄にコピー',
      'NIARIMの概要欄にコピー',
      'コピー先の上限（{max}文字）を超えるためコピーできません',
      'YouTubeのタイトルを入力してください'],
    'en': ['Work title','Work description','About the work (optional)',
      'Edit title and description','Title and description saved',
      'This changes the NIARIM listing only, not the YouTube video details.',
      'Could not load the description',
      'YouTube description (optional)',
      'Separate from your NIARIM work description',
      'YouTube descriptions must be at most 5,000 bytes and cannot contain < or >',
      'YouTube title',
      'Copy to YouTube title',
      'Copy to NIARIM title',
      'Copy to YouTube description',
      'Copy to NIARIM description',
      'Cannot copy: exceeds the destination limit of {max} characters',
      'Enter a YouTube title'],
    'es': ['Título de la obra','Descripción','Acerca de la obra (opcional)',
      'Editar título y descripción','Título y descripción guardados',
      'Solo cambia los datos en NIARIM, no los de YouTube.',
      'No se pudo cargar la descripción',
      'Descripción de YouTube (opcional)',
      'Se gestiona por separado de la descripción en NIARIM',
      'La descripción de YouTube debe tener como máximo 5.000 bytes y no puede contener < ni >',
      'Título de YouTube',
      'Copiar al título de YouTube',
      'Copiar al título de NIARIM',
      'Copiar a la descripción de YouTube',
      'Copiar a la descripción de NIARIM',
      'No se puede copiar: supera el límite de {max} caracteres',
      'Introduce un título para YouTube'],
    'fr': ['Titre de l’œuvre','Description','À propos de l’œuvre (facultatif)',
      'Modifier le titre et la description','Titre et description enregistrés',
      'Ces changements concernent NIARIM, pas YouTube.',
      'Impossible de charger la description',
      'Description YouTube (facultative)',
      'Distincte de la description de votre œuvre dans NIARIM',
      'La description YouTube doit faire au maximum 5 000 octets et ne pas contenir < ni >',
      'Titre YouTube',
      'Copier vers le titre YouTube',
      'Copier vers le titre NIARIM',
      'Copier vers la description YouTube',
      'Copier vers la description NIARIM',
      'Copie impossible : limite de {max} caractères dépassée',
      'Saisissez un titre YouTube'],
    'ko': ['작품 제목','작품 설명','작품과 제작 과정에 대한 설명 (선택)',
      '제목과 설명 수정','제목과 설명을 저장했습니다',
      'NIARIM 표시만 변경하며 YouTube의 제목과 설명은 변경되지 않습니다.',
      '작품 설명을 불러오지 못했습니다',
      'YouTube 설명 (선택)',
      'NIARIM 작품 설명과 별도로 관리됩니다',
      'YouTube 설명은 5,000바이트 이하여야 하며 < 또는 >를 포함할 수 없습니다',
      'YouTube 제목',
      'YouTube 제목으로 복사',
      'NIARIM 제목으로 복사',
      'YouTube 설명으로 복사',
      'NIARIM 작품 설명으로 복사',
      '복사 대상의 {max}자 제한을 초과하여 복사할 수 없습니다',
      'YouTube 제목을 입력해 주세요'],
    'zh': ['作品标题','作品简介','关于作品（选填）',
      '编辑标题和简介','标题和简介已保存',
      '仅修改 NIARIM 中的信息，不修改 YouTube 视频信息。',
      '无法加载作品简介',
      'YouTube 描述（选填）',
      '与 NIARIM 作品简介分别管理',
      'YouTube 描述不得超过 5,000 字节，也不能包含 < 或 >',
      'YouTube 标题',
      '复制到 YouTube 标题',
      '复制到 NIARIM 标题',
      '复制到 YouTube 描述',
      '复制到 NIARIM 简介',
      '超过目标的 {max} 字符限制，无法复制',
      '请输入 YouTube 标题'],
    'zh_Hant': ['作品標題','作品簡介','關於作品（選填）',
      '編輯標題與簡介','標題與簡介已儲存',
      '僅修改 NIARIM 的資訊，不修改 YouTube 影片資訊。',
      '無法載入作品簡介',
      'YouTube 說明（選填）',
      '與 NIARIM 作品簡介分開管理',
      'YouTube 說明不得超過 5,000 位元組，也不可包含 < 或 >',
      'YouTube 標題',
      '複製到 YouTube 標題',
      '複製到 NIARIM 標題',
      '複製到 YouTube 說明',
      '複製到 NIARIM 簡介',
      '超過目標的 {max} 字元限制，無法複製',
      '請輸入 YouTube 標題'],
  };
}
