import 'package:flutter/widgets.dart';

/// Posting visibility must be explicit: unlisted does not mean private.
class CommunityPostVisibilityLabels {
  const CommunityPostVisibilityLabels._(this._texts);
  final List<String> _texts;

  static CommunityPostVisibilityLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final key = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant'
        : locale.languageCode;
    return CommunityPostVisibilityLabels._(
      _translations[key] ?? _translations['en']!,
    );
  }

  String get heading => _texts[0];
  String get unlistedTitle => _texts[1];
  String get unlistedHelp => _texts[2];
  String get publicTitle => _texts[3];
  String get publicHelp => _texts[4];
  String get unlistedDisclosure => _texts[5];
}

const Map<String, List<String>> _translations = {
  'ja': [
    'YouTubeでの公開範囲',
    '作品広場にのみ投稿する',
    '※YouTube上では限定公開になります。NIARIMのブックマークランキングには参加できます。',
    'YouTubeにも同時投稿する',
    '※YouTube上では全体公開になります。NIARIMのブックマークランキングには参加できます。',
    '※ 限定公開は非公開ではありません。動画のURLを知る人は、NIARIM外でも視聴・共有できます。',
  ],
  'en': [
    'YouTube visibility',
    'Post for NIARIM (Unlisted on YouTube)',
    'Visible in the NIARIM plaza and eligible for bookmark rankings.',
    'Also publish on YouTube (Public)',
    'May appear in YouTube search/recommendations and is eligible for NIARIM bookmark rankings.',
    'Note: Unlisted is not private. Anyone with the link can watch and share the video outside NIARIM.',
  ],
  'es': [
    'Visibilidad en YouTube',
    'Publicar para NIARIM (no listado en YouTube)',
    'Visible en NIARIM y apto para la clasificación por marcadores.',
    'Publicar también en YouTube (público)',
    'Puede aparecer en búsquedas y recomendaciones de YouTube y en la clasificación de marcadores de NIARIM.',
    'Nota: no listado no significa privado. Cualquiera con el enlace puede ver y compartir el video fuera de NIARIM.',
  ],
  'fr': [
    'Visibilité sur YouTube',
    'Publier pour NIARIM (non répertorié sur YouTube)',
    'Visible dans NIARIM et éligible au classement des favoris.',
    'Publier aussi sur YouTube (public)',
    'Peut apparaître dans les recherches et recommandations YouTube et participer au classement des favoris NIARIM.',
    'Attention : non répertorié ne signifie pas privé. Toute personne ayant le lien peut regarder et partager la vidéo hors de NIARIM.',
  ],
  'ko': [
    'YouTube 공개 범위',
    'NIARIM용 게시 (YouTube 일부 공개)',
    'NIARIM 작품 광장에 표시되며 북마크 랭킹에 참여할 수 있습니다.',
    'YouTube에도 공개 (전체 공개)',
    'YouTube 검색 및 추천에 표시될 수 있으며 NIARIM 북마크 랭킹에 참여할 수 있습니다.',
    '참고: 일부 공개는 비공개가 아닙니다. 링크를 아는 사람은 NIARIM 밖에서도 시청하고 공유할 수 있습니다.',
  ],
  'zh': [
    'YouTube 公开范围',
    '发布到 NIARIM（YouTube 不公开列出）',
    '在 NIARIM 作品广场展示，并可参与书签排名。',
    '同时公开到 YouTube',
    '可能出现在 YouTube 搜索和推荐中，也可参与 NIARIM 书签排名。',
    '注意：不公开列出不等于私密。知道链接的人也能在 NIARIM 外观看和分享。',
  ],
  'zh_Hant': [
    'YouTube 公開範圍',
    '發佈至 NIARIM（YouTube 不公開列出）',
    '在 NIARIM 作品廣場顯示，並可參與書籤排名。',
    '同時公開至 YouTube',
    '可能出現在 YouTube 搜尋及推薦中，也可參與 NIARIM 書籤排名。',
    '注意：不公開列出不等於私人。知道連結的人也能在 NIARIM 以外觀看和分享。',
  ],
};
