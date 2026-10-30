import 'package:flutter/widgets.dart';

/// Locale-aware UI labels for newly introduced plaza controls.
/// Keep translations aligned with lib/l10n/app_*.arb when migrating to gen-l10n.
class CommunityPlazaLabels {
  const CommunityPlazaLabels._(this._labels);
  final List<String> _labels;
  static CommunityPlazaLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final key = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant' : locale.languageCode;
    return CommunityPlazaLabels._(_translations[key] ?? _translations['en']!);
  }
  String get muteWork => _labels[0];
  String get unmuteWork => _labels[1];
  String get mutedPlaceholder => _labels[2];
  String get unmuteQuestion => _labels[3];
  String get unmuteAlways => _labels[4];
  String get unmuteTemporary => _labels[5];
  String get muteSettings => _labels[6];
  String get partialHint => _labels[7];
  String get deleteHistory => _labels[8];
  String get localData => _labels[9];
  String get exactTitle => _labels[10];
}

const Map<String, List<String>> _translations = {
  'ja': ['この作品をミュートする', 'この作品のミュートを解除する', 'この作品はミュート対象です', 'この作品のミュートを常に解除しますか？', '常に解除する', '一時的に解除する', 'ミュート設定', '※OFFなら部分一致検索', 'この検索履歴を削除しますか？', '端末保存データ', '検索語を完全一致で検索する'],
  'en': ['Mute this work', 'Unmute this work', 'This work is muted', 'Always unmute this work?', 'Always unmute', 'Temporarily unmute', 'Mute settings', '※OFF: partial-match search', 'Delete this search history entry?', 'On-device data', 'Match search terms exactly'],
  'es': ['Silenciar esta obra', 'Dejar de silenciar esta obra', 'Esta obra está silenciada', '¿Dejar de silenciar siempre esta obra?', 'Siempre', 'Temporalmente', 'Opciones de silencio', '※Desactivado: coincidencia parcial', '¿Eliminar esta búsqueda del historial?', 'Datos guardados en el dispositivo', 'Buscar coincidencias exactas'],
  'fr': ['Masquer cette œuvre', 'Réafficher cette œuvre', 'Cette œuvre est masquée', 'Toujours réafficher cette œuvre ?', 'Toujours', 'Temporairement', 'Paramètres de masquage', '※Désactivé : recherche partielle', 'Supprimer cette recherche de l’historique ?', 'Données locales de l’appareil', 'Rechercher une correspondance exacte'],
  'ko': ['이 작품 뮤트', '이 작품 뮤트 해제', '이 작품은 뮤트 대상입니다', '이 작품의 뮤트를 항상 해제할까요?', '항상 해제', '일시적으로 해제', '뮤트 설정', '※OFF면 부분 일치 검색', '이 검색 기록을 삭제할까요?', '기기에 저장된 데이터', '검색어 완전 일치'],
  'zh': ['静音此作品', '取消此作品静音', '此作品已设为静音', '始终取消此作品静音吗？', '始终取消', '暂时取消', '静音设置', '※关闭时为部分匹配搜索', '删除这条搜索记录吗？', '设备本地数据', '搜索词完全匹配'],
  'zh_Hant': ['靜音此作品', '取消此作品靜音', '此作品已設為靜音', '要永久取消此作品靜音嗎？', '永久取消', '暫時取消', '靜音設定', '※關閉時使用部分相符搜尋', '要刪除這筆搜尋紀錄嗎？', '裝置本機資料', '搜尋詞完全相符'],
};
