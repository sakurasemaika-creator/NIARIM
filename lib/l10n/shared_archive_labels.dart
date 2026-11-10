import 'package:flutter/widgets.dart';

/// Short labels for the received/created switch and native-file share action.
abstract final class SharedArchiveLabels {
  static Map<String, String> of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final key = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant'
        : locale.languageCode;
    return _labels[key] ?? _labels['en']!;
  }

  static const _labels = <String, Map<String, String>>{
    'ja': {
      'received': '受け取った',
      'created': '作成した',
      'share': '共有する',
      'empty': '作成した共有ファイルはまだありません',
    },
    'en': {
      'received': 'Received',
      'created': 'Created',
      'share': 'Share',
      'empty': 'No shared files created yet',
    },
    'es': {
      'received': 'Recibidos',
      'created': 'Creados',
      'share': 'Compartir',
      'empty': 'Todavía no hay archivos compartidos',
    },
    'fr': {
      'received': 'Reçus',
      'created': 'Créés',
      'share': 'Partager',
      'empty': 'Aucun fichier de partage créé',
    },
    'ko': {
      'received': '받은 항목',
      'created': '만든 항목',
      'share': '공유하기',
      'empty': '생성한 공유 파일이 없습니다',
    },
    'zh': {
      'received': '收到的',
      'created': '创建的',
      'share': '分享',
      'empty': '尚未创建共享文件',
    },
    'zh_Hant': {
      'received': '收到的',
      'created': '建立的',
      'share': '分享',
      'empty': '尚未建立分享檔案',
    },
  };
}
