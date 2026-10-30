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
  String get unavailablePlaceholder => _labels[11];
}

const Map<String, List<String>> _translations = {
  'ja': ['この作品を非表示にする', 'この作品の非表示を解除する', 'この作品は非表示対象です', 'この作品の非表示を常に解除しますか？', '常に解除する', '一時的に解除する', '非表示設定', '※OFFなら部分一致検索', 'この検索履歴を削除しますか？', '端末保存データ', '検索語を完全一致で検索する', 'この作品は削除または非公開です'],
  'en': ['Hide this work', 'Show this work again', 'This work is hidden', 'Always show this work again?', 'Always show', 'Show temporarily', 'Visibility filters', '※OFF: partial-match search', 'Delete this search history entry?', 'On-device data', 'Match search terms exactly', 'This work was deleted or made private'],
  'es': ['Ocultar esta obra', 'Volver a mostrar esta obra', 'Esta obra está oculta', '¿Mostrar siempre esta obra?', 'Siempre', 'Temporalmente', 'Opciones de ocultación', '※Desactivado: coincidencia parcial', '¿Eliminar esta búsqueda del historial?', 'Datos guardados en el dispositivo', 'Buscar coincidencias exactas', 'Esta obra se eliminó o es privada'],
  'fr': ['Masquer cette œuvre', 'Réafficher cette œuvre', 'Cette œuvre est masquée', 'Toujours réafficher cette œuvre ?', 'Toujours', 'Temporairement', 'Paramètres de masquage', '※Désactivé : recherche partielle', 'Supprimer cette recherche de l’historique ?', 'Données locales de l’appareil', 'Rechercher une correspondance exacte', 'Cette œuvre a été supprimée ou rendue privée'],
  'ko': ['이 작품 숨기기', '이 작품 다시 표시', '이 작품은 숨김 대상입니다', '이 작품을 항상 다시 표시할까요?', '항상 표시', '일시적으로 표시', '숨김 설정', '※OFF면 부분 일치 검색', '이 검색 기록을 삭제할까요?', '기기에 저장된 데이터', '검색어 완전 일치', '이 작품은 삭제되었거나 비공개입니다'],
  'zh': ['隐藏此作品', '重新显示此作品', '此作品已隐藏', '始终重新显示此作品吗？', '始终显示', '暂时显示', '隐藏设置', '※关闭时为部分匹配搜索', '删除这条搜索记录吗？', '设备本地数据', '搜索词完全匹配', '此作品已删除或设为私密'],
  'zh_Hant': ['隱藏此作品', '重新顯示此作品', '此作品已隱藏', '要永久重新顯示此作品嗎？', '永久顯示', '暫時顯示', '隱藏設定', '※關閉時使用部分相符搜尋', '要刪除這筆搜尋紀錄嗎？', '裝置本機資料', '搜尋詞完全相符', '此作品已刪除或設為私人'],
};
