import 'package:flutter/widgets.dart';

/// Manual YouTube channel profile refresh: one successful request per JST day.
class CommunityChannelRefreshLabels {
  const CommunityChannelRefreshLabels._(this._values);
  final List<String> _values;

  static CommunityChannelRefreshLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final key = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant'
        : locale.languageCode;
    return CommunityChannelRefreshLabels._(
      _translations[key] ?? _translations['en']!,
    );
  }

  String get button => _values[0];
  String get success => _values[1];
  String get noToken => _values[2];
  String get unavailable => _values[3];
  String get failed => _values[4];
}

const Map<String, List<String>> _translations = {
  'ja': ['YouTube名・アイコンを更新（1日1回）',
    'YouTubeの名前・アイコンを更新しました',
    'YouTubeの認証が必要です',
    'ログインとサーバー接続が必要です',
    'YouTube情報を更新できませんでした'],
  'en': ['Refresh YouTube name & icon (once daily)',
    'YouTube name and icon updated',
    'YouTube authorization is required',
    'Please sign in and connect to the server',
    'Could not refresh YouTube channel information'],
  'es': ['Actualizar nombre e icono de YouTube (una vez al día)',
    'Nombre e icono de YouTube actualizados',
    'Se requiere autorización de YouTube',
    'Inicia sesión y conéctate al servidor',
    'No se pudo actualizar el canal de YouTube'],
  'fr': ['Actualiser le nom et l’icône YouTube (1 fois/jour)',
    'Nom et icône YouTube mis à jour',
    'Autorisation YouTube nécessaire',
    'Connectez-vous et connectez le serveur',
    'Impossible de mettre à jour les informations YouTube'],
  'ko': ['YouTube 이름·아이콘 갱신 (하루 1회)',
    'YouTube 이름과 아이콘을 갱신했습니다',
    'YouTube 인증이 필요합니다',
    '로그인 및 서버 연결이 필요합니다',
    'YouTube 채널 정보를 갱신하지 못했습니다'],
  'zh': ['更新 YouTube 名称和头像（每天一次）',
    'YouTube 名称和头像已更新',
    '需要 YouTube 授权',
    '请先登录并连接服务器',
    '无法更新 YouTube 频道信息'],
  'zh_Hant': ['更新 YouTube 名稱和頭像（每日一次）',
    'YouTube 名稱和頭像已更新',
    '需要 YouTube 授權',
    '請先登入並連線伺服器',
    '無法更新 YouTube 頻道資訊'],
};
