import 'package:flutter/widgets.dart';

class CommunityYoutubeCommentLabels {
  const CommunityYoutubeCommentLabels._(this.values);
  final List<String> values;
  static CommunityYoutubeCommentLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant' : locale.languageCode;
    return CommunityYoutubeCommentLabels._(labels[language] ?? labels['en']!);
  }
  String get heading => values[0];
  String get loadMore => values[1];
  String get noComments => values[2];
  String get unavailable => values[3];
  String get retry => values[4];
  String get replies => values[5];
  String get attribution => values[6];
  static const labels = <String,List<String>>{
    'ja': ['YouTubeのコメントを見る','さらに20件表示',
      'コメントはまだありません','YouTubeコメントを取得できませんでした',
      '再読み込み','返信', 'コメントはYouTubeから取得しています。投稿・返信はできません。'],
    'en': ['View YouTube comments','Load 20 more','No comments yet',
      'YouTube comments are unavailable','Retry','Replies',
      'Comments come from YouTube. Posting and replying are not available.'],
    'es': ['Ver comentarios de YouTube','Cargar 20 más','Aún no hay comentarios',
      'Comentarios de YouTube no disponibles','Reintentar','Respuestas',
      'Los comentarios vienen de YouTube. No se puede publicar ni responder.'],
    'fr': ['Voir les commentaires YouTube','Charger 20 commentaires',
      'Aucun commentaire','Commentaires YouTube indisponibles',
      'Réessayer','Réponses',
      'Les commentaires viennent de YouTube. Publication et réponse indisponibles.'],
    'ko': ['YouTube 댓글 보기','20개 더 불러오기','아직 댓글이 없습니다',
      'YouTube 댓글을 불러올 수 없습니다','다시 시도','답글',
      '댓글은 YouTube에서 가져옵니다. 작성 및 답글은 지원하지 않습니다.'],
    'zh': ['查看 YouTube 评论','再加载20条','暂无评论',
      '无法加载 YouTube 评论','重试','回复',
      '评论来自 YouTube。暂不支持发布和回复。'],
    'zh_Hant': ['查看 YouTube 留言','再載入20則','尚無留言',
      '無法載入 YouTube 留言','重試','回覆',
      '留言來自 YouTube。暫不支援發佈與回覆。'],
  };
}
