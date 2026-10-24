import '../config/accent_text_theme.dart';
import '../config/font_fallback.dart';
import '../config/previous_theme_presets.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_preset.dart';
import '../utils/color_contrast.dart';
import '../utils/tolerant_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _prefsPresetsKey = 'theme_presets';

  /// 現在の色そのもの（JSON）。テーマ一覧から配色だけ取り込んだ状態は
  /// どのプリセットとも一致しないため、IDだけでは復元できない。
  static const _prefsCurrentJsonKey = 'theme_current_json';

  /// テーマ一覧から配色だけ取り込んだ「現在の色」に付けるID。
  /// プリセット一覧には現れないIDなので、この状態では一覧のどのテーマにも
  /// チェックマークが付かず、色を編集してもどのテーマも書き換わらない。
  static const String customCurrentId = 'theme_custom_current';

  final List<AppThemePreset> _presets = [];
  AppThemePreset _current = AppThemePreset.defaultLight;

  List<AppThemePreset> get presets => List.unmodifiable(_presets);
  AppThemePreset get current => _current;

  /// 色リセットの表示判定は現在のテーマオブジェクトにつき一度だけ。
  /// 色変更（プレビュー/適用/復元）の時だけオブジェクトが変わる。
  /// 毎フレームのbuildでは計算を行わずキャッシュを返す。
  AppThemePreset? _rescueCheckedPreset;
  bool _rescueCachedResult = false;

  bool get needsThemeRescue {
    if (!identical(_rescueCheckedPreset, _current)) {
      _rescueCachedResult = isThemeAtLockoutRisk(_current);
      _rescueCheckedPreset = _current;
    }
    return _rescueCachedResult;
  }


  static ColorScheme activeColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF5C7A),
  );

  /// [activeColorScheme]と同じく、BuildContextの無い所（描画クラス等）から
  /// 「アクセントの文字・アイコン色」を読むための値。themeDataを作るたびに
  /// 更新する。
  static Color activeAccentText = const Color(0xFFFF5C7A);

  /// 復旧確認ダイアログ専用。現在のテーマから独立している。
  /// プリセットの色をここで複製せず、正式なレッド（ライト）を利用する。
  static ThemeData get rescueThemeData =>
      ThemeService()._buildTheme(AppThemePreset.defaultLight);

  /// 利用者が確認した場合のみ、現在の配色を既定に戻して永続化する。
  /// 保存済みのユーザープリセット自体は削除・書き換えない。
  Future<void> resetToDefault() async {
    _current = AppThemePreset.defaultLight;
    notifyListeners();
    await _persist();
  }

  ThemeData get themeData {
    final data = _buildTheme(_current);
    activeColorScheme = data.colorScheme;
    activeAccentText =
        data.extension<AccentTextTheme>()?.color ?? data.colorScheme.primary;
    return data;
  }

  // 虹7色（赤・橙・黄・緑・青・藍・紫）のテーマプリセットを、それぞれ
  // ライト/ダーク両方用意する。「赤」はアプリの
  // 既定色である珊瑚ピンク（defaultLight/defaultDark）が該当する。
  // デフォルトで選択されるのはdefaultLight（見た目はライト基調）と
  // なるよう、リストの先頭に置く。
  //
  // 配色の決まり（APCAのLc、test/theme_preset_readability_test.dartが見張る）：
  // - 塗りのボタン・選択中の文字はライト・ダークとも白抜き。差し色はその
  //   文字がLc 60以上で読める濃さへ同じ色相のまま沈め、ライトとダークで
  //   同じ色にする。グリーンはエメラルドと、ライトブルーはくすみブルーと
  //   見分けがつくよう色相をずらした。
  // - アクセントの文字・アイコン色は、パネル背景・メニュー背景の上で
  //   ライトLc 75以上・ダークLc 70以上になる同じ色相の濃淡。
  // - 更新マーク色は背景の上でライトLc 50以上・ダークLc 60以上で、差し色と
  //   見分けがつく色（琥珀色が差し色に近い黄・橙は青緑、グリーンは朱色）。
  // 配色を変えたら、以前の配色を版としてprevious_theme_presets.dartへ足すこと
  // （手を加えていない保存済みのテーマを新しい配色にするため）。
  static const List<AppThemePreset> _builtInPresets = [
    AppThemePreset.defaultLight, // 赤（ライト・既定選択）
    AppThemePreset.defaultDark, // 赤（ダーク）
    AppThemePreset(
      id: 'orange_light',
      name: 'オレンジ（ライト）',
      accentColor: Color(0xFFEB7826),
      textColor: Color(0xFF2E2013),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF2E2013),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFFFF6EE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFEB7826),
      updateMarkColor: Color(0xFF0FAA93),
      accentTextColor: Color(0xFF9E4A05),
    ),
    AppThemePreset(
      id: 'orange_dark',
      name: 'オレンジ（ダーク）',
      accentColor: Color(0xFFEB7826),
      textColor: Color(0xFFFAF0E6),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFFAF0E6),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF1F160E),
      menuBgColor: Color(0xFF2A1D12),
      selectionColor: Color(0xFFEB7826),
      updateMarkColor: Color(0xFF24CAAF),
      accentTextColor: Color(0xFFFFB68D),
    ),
    AppThemePreset(
      id: 'yellow_light',
      name: 'イエロー（ライト）',
      accentColor: Color(0xFFBF910C),
      textColor: Color(0xFF2E2A12),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF2E2A12),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFFFFBEA),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFBF910C),
      updateMarkColor: Color(0xFF0FAF97),
      accentTextColor: Color(0xFF846302),
    ),
    AppThemePreset(
      id: 'yellow_dark',
      name: 'イエロー（ダーク）',
      accentColor: Color(0xFFBF910C),
      textColor: Color(0xFFFAF6E6),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFFAF6E6),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF1E1B0C),
      menuBgColor: Color(0xFF292410),
      selectionColor: Color(0xFFBF910C),
      updateMarkColor: Color(0xFF27CBB1),
      accentTextColor: Color(0xFFF0C152),
    ),
    AppThemePreset(
      id: 'green_light',
      name: 'グリーン（ライト）',
      accentColor: Color(0xFF46AD2B),
      textColor: Color(0xFF16291F),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF16291F),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF1FBF6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF46AD2B),
      updateMarkColor: Color(0xFFFF5A1F),
      accentTextColor: Color(0xFF237406),
    ),
    AppThemePreset(
      id: 'green_dark',
      name: 'グリーン（ダーク）',
      accentColor: Color(0xFF46AD2B),
      textColor: Color(0xFFF1FAF5),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF1FAF5),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF101A15),
      menuBgColor: Color(0xFF17251D),
      selectionColor: Color(0xFF46AD2B),
      updateMarkColor: Color(0xFFFE9C7F),
      accentTextColor: Color(0xFF78DE61),
    ),
    AppThemePreset(
      id: 'blue_light',
      name: 'ブルー（ライト）',
      accentColor: Color(0xFF2F9DF5),
      textColor: Color(0xFF16232E),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF16232E),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF1F7FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF2F9DF5),
      updateMarkColor: Color(0xFFCB8902),
      accentTextColor: Color(0xFF0464A5),
    ),
    AppThemePreset(
      id: 'blue_dark',
      name: 'ブルー（ダーク）',
      accentColor: Color(0xFF2F9DF5),
      textColor: Color(0xFFF2F6FA),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF2F6FA),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF11181F),
      menuBgColor: Color(0xFF182430),
      selectionColor: Color(0xFF2F9DF5),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFF97CCFF),
    ),
    AppThemePreset(
      id: 'indigo_light',
      // 同じ藍色系統を指す馴染み深い和名（藍色）を名前に使う。
      name: '藍色（ライト）',
      accentColor: Color(0xFF5C6BFF),
      textColor: Color(0xFF1E2033),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF1E2033),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF3F3FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF5C6BFF),
      updateMarkColor: Color(0xFFC88708),
      accentTextColor: Color(0xFF4248DA),
    ),
    AppThemePreset(
      id: 'indigo_dark',
      name: '藍色（ダーク）',
      accentColor: Color(0xFF5C6BFF),
      textColor: Color(0xFFF0F1FA),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF0F1FA),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF14151F),
      menuBgColor: Color(0xFF1C1E2D),
      selectionColor: Color(0xFF5C6BFF),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFB6C4FE),
    ),
    AppThemePreset(
      id: 'purple_light',
      name: 'パープル（ライト）',
      accentColor: Color(0xFFB15CFF),
      textColor: Color(0xFF2B2033),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF2B2033),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF8F1FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFB15CFF),
      updateMarkColor: Color(0xFFC68603),
      accentTextColor: Color(0xFF8324CB),
    ),
    AppThemePreset(
      id: 'purple_dark',
      name: 'パープル（ダーク）',
      accentColor: Color(0xFFB15CFF),
      textColor: Color(0xFFF6F1FA),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF6F1FA),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF19141F),
      menuBgColor: Color(0xFF241C2D),
      selectionColor: Color(0xFFB15CFF),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFD8B9FE),
    ),
    // ここから追加のパステル・ニュアンスカラー。
    AppThemePreset(
      id: 'pink_light',
      name: 'ピンク（ライト）',
      accentColor: Color(0xFFEB6CA1),
      textColor: Color(0xFF33202A),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF33202A),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFFFF1F6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFEB6CA1),
      updateMarkColor: Color(0xFFC8880B),
      accentTextColor: Color(0xFFA72C66),
    ),
    AppThemePreset(
      id: 'pink_dark',
      name: 'ピンク（ダーク）',
      accentColor: Color(0xFFEB6CA1),
      textColor: Color(0xFFFAEEF3),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFFAEEF3),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF1F1418),
      menuBgColor: Color(0xFF2B1B22),
      selectionColor: Color(0xFFEB6CA1),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFFFB0CD),
    ),
    AppThemePreset(
      id: 'light_purple_light',
      name: 'ライトパープル（ライト）',
      accentColor: Color(0xFFA48ECB),
      textColor: Color(0xFF272233),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF272233),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF6F2FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFA48ECB),
      updateMarkColor: Color(0xFFC78705),
      accentTextColor: Color(0xFF69548C),
    ),
    AppThemePreset(
      id: 'light_purple_dark',
      name: 'ライトパープル（ダーク）',
      accentColor: Color(0xFFA48ECB),
      textColor: Color(0xFFF2EFF9),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF2EFF9),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF19171F),
      menuBgColor: Color(0xFF211E2C),
      selectionColor: Color(0xFFA48ECB),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFD2BCFD),
    ),
    AppThemePreset(
      id: 'light_blue_light',
      name: 'ライトブルー（ライト）',
      accentColor: Color(0xFF2EA4C4),
      textColor: Color(0xFF1D2733),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF1D2733),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF0F8FE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF2EA4C4),
      updateMarkColor: Color(0xFFCC8A04),
      accentTextColor: Color(0xFF056B83),
    ),
    AppThemePreset(
      id: 'light_blue_dark',
      name: 'ライトブルー（ダーク）',
      accentColor: Color(0xFF2EA4C4),
      textColor: Color(0xFFEDF5FB),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFEDF5FB),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF141A1F),
      menuBgColor: Color(0xFF1C2530),
      selectionColor: Color(0xFF2EA4C4),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFF68D5F6),
    ),
    AppThemePreset(
      id: 'emerald_light',
      name: 'エメラルドグリーン（ライト）',
      accentColor: Color(0xFF01AC77),
      textColor: Color(0xFF13291F),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF13291F),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFECFAF4),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF01AC77),
      updateMarkColor: Color(0xFFCC8A04),
      accentTextColor: Color(0xFF05704D),
    ),
    AppThemePreset(
      id: 'emerald_dark',
      name: 'エメラルドグリーン（ダーク）',
      accentColor: Color(0xFF01AC77),
      textColor: Color(0xFFE9FAF3),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFE9FAF3),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF0D1815),
      menuBgColor: Color(0xFF13221D),
      selectionColor: Color(0xFF01AC77),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFF57DDA5),
    ),
    // くすみカラー（色名は「くすみ（カラー名）」表記）。
    AppThemePreset(
      id: 'dusty_pink_light',
      name: 'くすみピンク（ライト）',
      accentColor: Color(0xFFC08A90),
      textColor: Color(0xFF2E2325),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF2E2325),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFFAF2F2),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFC08A90),
      updateMarkColor: Color(0xFFC88708),
      accentTextColor: Color(0xFF825157),
    ),
    AppThemePreset(
      id: 'dusty_pink_dark',
      name: 'くすみピンク（ダーク）',
      accentColor: Color(0xFFC08A90),
      textColor: Color(0xFFF5ECED),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF5ECED),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF1C1516),
      menuBgColor: Color(0xFF261C1E),
      selectionColor: Color(0xFFC08A90),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFF0B8BE),
    ),
    AppThemePreset(
      id: 'dusty_blue_light',
      name: 'くすみブルー（ライト）',
      accentColor: Color(0xFF809CB6),
      textColor: Color(0xFF212B33),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF212B33),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF1F5F9),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF809CB6),
      updateMarkColor: Color(0xFFC8880B),
      accentTextColor: Color(0xFF48627A),
    ),
    AppThemePreset(
      id: 'dusty_blue_dark',
      name: 'くすみブルー（ダーク）',
      accentColor: Color(0xFF809CB6),
      textColor: Color(0xFFEDF1F5),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFEDF1F5),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF151A1E),
      menuBgColor: Color(0xFF1C232B),
      selectionColor: Color(0xFF809CB6),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFAECAE6),
    ),
    AppThemePreset(
      id: 'dusty_green_light',
      name: 'くすみグリーン（ライト）',
      accentColor: Color(0xFF79A187),
      textColor: Color(0xFF20281F),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF20281F),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF2F8F3),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF79A187),
      updateMarkColor: Color(0xFFCC8A04),
      accentTextColor: Color(0xFF446A52),
    ),
    AppThemePreset(
      id: 'dusty_green_dark',
      name: 'くすみグリーン（ダーク）',
      accentColor: Color(0xFF79A187),
      textColor: Color(0xFFEEF4EF),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFEEF4EF),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF151A16),
      menuBgColor: Color(0xFF1D251F),
      selectionColor: Color(0xFF79A187),
      updateMarkColor: Color(0xFFFFB020),
      accentTextColor: Color(0xFFA7D1B5),
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var upgradedAny = false;
    final raw = prefs.readStringList(_prefsPresetsKey);
    if (raw == null || raw.isEmpty) {
      _presets.addAll(_builtInPresets);
    } else {
      for (final encoded in raw) {
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is Map<String, dynamic>) {
            _presets.add(AppThemePreset.fromJson(decoded));
          }
        } on FormatException {
          // Keep malformed persisted JSON untouched; skip it for this session.
        } on TypeError {
          // Isolate structurally invalid presets instead of aborting startup.
        }
      }
      // 保存済みプリセット一覧に、組み込みプリセット（パステル・
      // ニュアンス・くすみカラー等）を反映する（同IDが既に存在する場合は
      // 追加しない。プリセット名は同一IDであれば保存済みデータ側が優先
      // されるため、名称を変更したい場合はプリセットの削除→再度組み込み
      // 一覧から選び直すことで反映できる）。
      // 組み込みテーマの配色を見直したので、以前の配色のまま（利用者が
      // 手を加えていない）組み込みテーマは新しい配色にする。
      for (var i = 0; i < _presets.length; i++) {
        final upgraded = _upgradedBuiltIn(_presets[i], _presets[i].id);
        if (upgraded != null) {
          _presets[i] = upgraded;
          upgradedAny = true;
        }
      }
      final existingIds = _presets.map((p) => p.id).toSet();
      final missing = _builtInPresets.where((p) => !existingIds.contains(p.id));
      if (missing.isNotEmpty) _presets.addAll(missing);
    }
    // 現在の色は「一覧のどれか」とは限らないため、保存したJSONから復元する。
    final currentJson = prefs.readString(_prefsCurrentJsonKey);
    AppThemePreset? restoredCurrent;
    if (currentJson != null) {
      try {
        final decoded = jsonDecode(currentJson);
        if (decoded is Map<String, dynamic>) {
          restoredCurrent = AppThemePreset.fromJson(decoded);
        }
      } on FormatException {
        // Keep the damaged raw value untouched and fall back below.
      } on TypeError {
        // Structurally invalid current theme must not abort app startup.
      }
    }
    if (restoredCurrent != null) {
      // 組み込みテーマそのもの（編集中）はそのIDで、一覧から配色だけ
      // 取り込んだ現在の色はどの組み込みテーマの以前の配色と同じかで探す。
      final restored = restoredCurrent;
      final upgraded = restored.id == customCurrentId
          ? kPreviousBuiltInThemeColors.keys
                .map((id) => _upgradedBuiltIn(restored, id))
                .nonNulls
                .firstOrNull
          : _upgradedBuiltIn(restored, restored.id);
      if (upgraded != null) upgradedAny = true;
      _current = upgraded ?? restored;
    } else if (_presets.isNotEmpty) {
      _current = _presets.first;
    }
    if (upgradedAny) await _persist();
  }

  /// [preset]が組み込みテーマ[builtInId]の以前のどれかの版の配色のまま
  /// （利用者が手を加えていない）なら、新しい配色にしたものを返す。
  /// ID・名前・お気に入りはそのまま。
  static AppThemePreset? _upgradedBuiltIn(
    AppThemePreset preset,
    String builtInId,
  ) {
    final versions = kPreviousBuiltInThemeColors[builtInId];
    if (versions == null) return null;
    final colours = [
      preset.accentColor.toARGB32(),
      preset.textColor.toARGB32(),
      preset.buttonTextColor.toARGB32(),
      preset.menuTextColor.toARGB32(),
      preset.selectionTextColor.toARGB32(),
      preset.panelBgColor.toARGB32(),
      preset.menuBgColor.toARGB32(),
      preset.selectionColor.toARGB32(),
      preset.updateMarkColor.toARGB32(),
      preset.accentTextColor?.toARGB32(),
    ];
    final untouched = versions.any((previous) {
      for (var i = 0; i < colours.length; i++) {
        if (colours[i] != previous[i]) return false;
      }
      return true;
    });
    if (!untouched) return null;
    return _builtInPresets
        .firstWhere((p) => p.id == builtInId)
        .copyWith(
          id: preset.id,
          name: preset.name,
          isFavorite: preset.isFavorite,
        );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsPresetsKey,
      _presets.map((p) => jsonEncode(p.toJson())).toList(),
    );
    await prefs.setString(_prefsCurrentJsonKey, jsonEncode(_current.toJson()));
  }

  /// テーマ一覧の三点メニュー「編集」から呼ぶ：そのテーマ自体を編集対象に
  /// する（一覧でチェックが付き、以後のカラーカスタマイズはこのテーマへ
  /// 上書き保存される）。
  void applyPreset(String id) {
    final preset = _presets.firstWhere(
      (p) => p.id == id,
      orElse: () => _current,
    );
    _current = preset;
    notifyListeners();
    _persist();
  }

  /// テーマ一覧のカードをタップしたときに呼ぶ：**配色だけ**を現在の色設定へ
  /// 取り込む。取り込んだあとにカラーカスタマイズで色を変えても、取り込み元の
  /// テーマは書き換わらない（＝一覧のテーマは「見本」として扱う）。
  /// 現在の色はどのプリセットとも一致しなくなるため、一覧のどのテーマにも
  /// チェックマークは付かない。
  void adoptPresetColors(String id) {
    final preset = _presets.firstWhere(
      (p) => p.id == id,
      orElse: () => _current,
    );
    _current = preset.copyWith(id: customCurrentId);
    notifyListeners();
    _persist();
  }

  /// 引き継ぎ（.niatra）から「現在の色」を復元する。一覧のどのテーマとも
  /// 一致しない配色（テーマ一覧から取り込んで手直しした状態）もそのまま
  /// 持ち込めるよう、プリセット一覧へは足さずに現在の色だけを差し替える。
  void restoreCurrent(AppThemePreset preset) {
    _current = preset;
    notifyListeners();
    _persist();
  }

  /// 現在の色が一覧のいずれかのテーマそのもの（＝編集対象）かどうか。
  /// falseなら配色だけ取り込んだ状態で、色を変えてもテーマは書き換わらない。
  bool get isEditingPreset => _presets.any((p) => p.id == _current.id);

  /// カラーピッカーでのライブプレビュー用（「変更はアプリ全体へ
  /// 即時反映される」）。ドラッグ中に毎回SharedPreferencesへ書き込むのを
  /// 避けるため、通知のみ行い永続化はしない。確定はcommitCurrent()で行う。
  void previewCurrent(AppThemePreset preset) {
    _current = preset;
    notifyListeners();
  }

  /// previewCurrent()でのライブプレビュー結果を確定保存する（プリセット
  /// 一覧にも反映：組み込みプリセットを編集した場合はそのプリセット自体が
  /// 上書きされる。これは「上書き保存」と同じ挙動）。
  void commitCurrent() {
    // 一覧から配色だけ取り込んだ状態は「どのテーマの編集でもない」ので、
    // プリセット一覧へは書き戻さず現在の色としてだけ保存する
    // （書き戻すと、見本のつもりでタップしたテーマが勝手に上書きされたり、
    // 一覧に見えないテーマが増えたりする）。
    if (!isEditingPreset) {
      notifyListeners();
      _persist();
      return;
    }
    savePreset(_current);
  }

  void savePreset(AppThemePreset preset) {
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      _presets[idx] = preset;
    } else {
      _presets.add(preset);
    }
    if (_current.id == preset.id) _current = preset;
    notifyListeners();
    _persist();
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
    _persist();
  }

  /// テーマプリセットの並び替え（「並び替え | ドラッグで順序変更」）。
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _presets.removeAt(oldIndex);
    _presets.insert(newIndex, item);
    notifyListeners();
    _persist();
  }

  void toggleFavorite(String id) {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _presets[idx] = _presets[idx].copyWith(
        isFavorite: !_presets[idx].isFavorite,
      );
      notifyListeners();
      _persist();
    }
  }

  /// ポップなフラットデザインのThemeDataを構築する。
  /// Material標準の角丸・階調をそのまま使わず、フラット・大きめタップ領域・
  /// 丸みの強い形状で統一し、スマホでの誤タップを減らす。
  ThemeData _buildTheme(AppThemePreset preset) {
    // 明暗（Brightness）は、以前は独立した「ベーステーマ」設定から決めて
    // いたが、プリセット自身の文字色・背景色と噛み合わない組み合わせを
    // 選べてしまい、暗い文字が暗い背景に埋もれて読めなくなる不具合の
    // 原因になっていた。プリセット自身の背景色（panelBgColor）の明るさ
    // から自動的に決めることで、常に矛盾のない組み合わせになるようにする。
    final brightness = preset.panelBgColor.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
    // ダイアログ・ボトムシート・トースト（SnackBar）・吹き出しのように画面の
    // 上へ重なって出るものの下地は、必ず不透明にする。テーマの色はカラー
    // ピッカーで透明度まで選べるため、メニュー背景色をそのまま使うと後ろの
    // 画面が透けて文字が読みにくくなる。パネル背景色の上に重ねたときの色
    // （＝パネルの上で実際に見えている色）へ平たくしてから使う。
    final panelColor = opaqueOver(preset.panelBgColor, Colors.black);
    final popupColor = opaqueOver(preset.menuBgColor, panelColor);
    // 初回の吹き出し・説明の吹き出しはアクセント色を下地にするので同様。
    final accentColor = opaqueOver(preset.accentColor, panelColor);
    final selectionColor = opaqueOver(preset.selectionColor, panelColor);
    // 差し色で背景の上に直接描く文字・アイコン（選択中のタブ名・枠や文字の
    // ボタン等）の色。未指定なら差し色と同じ（AccentTextTheme参照）。
    final accentText = opaqueOver(preset.effectiveAccentTextColor, panelColor);
    // 「本文・通常の文字色」はonSurface系にも反映し、
    // ColorScheme.fromSeedが自動算出する既定の文字色（accentColorから
    // 逆算される、ユーザーが選んだtextColorとは無関係の値）で上書きされて
    // しまわないようにする。
    final seedScheme = ColorScheme.fromSeed(
      seedColor: preset.accentColor,
      brightness: brightness,
    );
    // 差し色を変えたら差し色だけが変わるよう、fromSeedが差し色から作る
    // ほかの色は、それぞれ対応する設定から作り直す。選択色の淡い色と
    // 3つ目の色は選択色から（組み込みテーマは選択色＝差し色なので同じ値）、
    // カード・入力欄・区切り線などの面と線はパネル背景色と文字色から。
    final selectionSeedScheme = ColorScheme.fromSeed(
      seedColor: preset.selectionColor,
      brightness: brightness,
    );
    final surfaceInk = opaqueOver(preset.textColor, panelColor);
    Color towardText(double t) => Color.lerp(panelColor, surfaceInk, t)!;
    final light = brightness == Brightness.light;
    final scheme = seedScheme.copyWith(
      primary: accentColor,
      onPrimary: preset.buttonTextColor,
      secondary: selectionColor,
      onSecondary: preset.selectionTextColor,
      secondaryContainer: selectionSeedScheme.secondaryContainer,
      secondaryFixed: selectionSeedScheme.secondaryFixed,
      secondaryFixedDim: selectionSeedScheme.secondaryFixedDim,
      onSecondaryFixed: selectionSeedScheme.onSecondaryFixed,
      onSecondaryFixedVariant: selectionSeedScheme.onSecondaryFixedVariant,
      tertiary: selectionSeedScheme.tertiary,
      onTertiary: selectionSeedScheme.onTertiary,
      tertiaryContainer: selectionSeedScheme.tertiaryContainer,
      onTertiaryContainer: selectionSeedScheme.onTertiaryContainer,
      tertiaryFixed: selectionSeedScheme.tertiaryFixed,
      tertiaryFixedDim: selectionSeedScheme.tertiaryFixedDim,
      onTertiaryFixed: selectionSeedScheme.onTertiaryFixed,
      onTertiaryFixedVariant: selectionSeedScheme.onTertiaryFixedVariant,
      surface: panelColor,
      surfaceDim: light ? towardText(0.1) : panelColor,
      surfaceBright: light ? panelColor : towardText(0.2),
      surfaceContainerLowest: light
          ? Color.lerp(panelColor, Colors.white, 0.6)!
          : Color.lerp(panelColor, Colors.black, 0.3)!,
      surfaceContainerLow: towardText(light ? 0.025 : 0.04),
      surfaceContainer: towardText(light ? 0.045 : 0.06),
      surfaceContainerHigh: towardText(light ? 0.07 : 0.1),
      surfaceContainerHighest: towardText(light ? 0.095 : 0.15),
      outline: towardText(0.55),
      outlineVariant: towardText(light ? 0.2 : 0.22),
      inverseSurface: Color.lerp(surfaceInk, panelColor, 0.1),
      onInverseSurface: panelColor,
      // 浮いた面に差し色を薄く重ねるMaterial3の色。面が差し色で
      // 色づかないよう使わない。
      surfaceTint: Colors.transparent,
      // Material container shades are subtle surfaces, NOT primary
      // filled buttons. Text shown on them (e.g. creator avatar labels)
      // follows the normal text token, not the button foreground.
      // In particular, a light container must not acquire white labels
      // merely because button text is configured white.
      onPrimaryContainer: preset.textColor,
      onSecondaryContainer: preset.textColor,
      onSurface: preset.textColor,
      onSurfaceVariant: preset.textColor.withValues(alpha: 0.7),
    );
    // ユーザーが選んだ上部バー/メニューの文字色をそのまま描画する。
    final menuForeground = preset.menuTextColor;
    // 角丸を大きめにし、Google Material標準の角丸14pxよりも柔らかい印象にする
    // （LINE・メルカリ等、日本の人気アプリに共通するポップで丸みの強い形状）。
    const radius = 18.0;
    const minTapSize = Size(48, 48);
    // Text等が明示的に色指定していない場合に使うデフォルト文字色
    // （「文字色 | UI全体の文字色」）。
    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;
    // アプリ全体の基本フォント（白光明朝）。白光明朝に無い文字
    // （対応外の漢字・記号等）は、Android標準フォントへ直接落ちて浮いて
    // 見えないよう、まず源ノ明朝相当（Noto Serif JP）で穴埋めし、それでも
    // 無い場合のみ端末標準フォントへフォールバックする。数値表示は個別の
    // ウィジェット側でAndroid標準フォント（未指定＝Roboto/Noto Sans）を
    // 明示的に指定して上書きする。
    // 明朝体（白光明朝）は線が細く、通常の太さ（Regular）のままだと画面全体で
    // 文字が読みにくい。デフォルトの太さがRegular以下（未指定含む）の
    // スタイルはMedium以上へ底上げする（既に太字指定済みの箇所、例：
    // AppBarタイトルのBold等はそのまま維持される）。
    final bodyTextTheme = _boldenForReadability(
      _withFontFallback(
        baseTextTheme.apply(
          fontFamily: 'HakkouMincho',
          bodyColor: preset.textColor,
          displayColor: preset.textColor,
        ),
        kBodyFontFallback,
      ),
    );
    // フォントの使い分け：項目名・見出しなど文字サイズが
    // 大きく目立たせたい箇所（display/headline/title）はくらむぼん、
    // それ以外の説明文・通常サイズの文字（body/label）はすべて白光明朝、
    // という切り分けに変更した（従来はくらむぼんをチュートリアル説明の
    // 吹き出し専用にしていたが、それは廃止しこの規則へ統一する）。
    final textTheme = _applyHeadingFont(bodyTextTheme, 'Kuramubon');

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'HakkouMincho',
      textTheme: textTheme,
      extensions: [AccentTextTheme(accentText)],
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: preset.panelBgColor,
      // InkSparkle（Material Youの光るリップル）は「いかにも最新Android技術デモ」
      // 感が強く、GPU負荷も高いため、低スペック端末を考慮しつつ落ち着いた
      // タップフィードバックのInkRippleへ変更する。
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: preset.menuBgColor,
        foregroundColor: menuForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 画面名（AppBarタイトル）がデフォルトフォント（Roboto等の端末標準）
        // で表示されてしまう不具合を修正。ThemeData.fontFamily='HakkouMincho'
        // をルートで設定していても、appBarTheme.titleTextStyleへ独自の
        // TextStyle()をベタ書きするとfontFamilyが未指定のまま上書きされ、
        // 継承されない。textTheme.titleLarge（見出し用にくらむぼんへ差し替え
        // 済み）を土台にして色・サイズ・太さだけ上書きすることで、正しく
        // 適用されるようにした。
        titleTextStyle:
            textTheme.titleLarge?.copyWith(
              color: menuForeground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
              color: menuForeground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
      ),
      // PopupMenuItem labels do not automatically use AppBar foreground.
      // Match text/icon foreground to the same menu token as the top bar.
      popupMenuTheme: PopupMenuThemeData(
        color: popupColor,
        textStyle: textTheme.bodyMedium?.copyWith(color: menuForeground),
        iconColor: menuForeground,
      ),
      // カードはカラーピッカー等のダイアログの本体にも使う（Dialog側は透明に
      // してカードの角丸を見せている）ので、下地はポップアップと同じ不透明色。
      cardTheme: CardThemeData(
        elevation: 0,
        color: popupColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      // All action-button labels are headings in the design system:
      // Kuramubon for Filled / Elevated / Outlined / Text buttons.
      // Keep the user's foreground tokens unchanged.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontWeight: FontWeight.w700,
          ) ?? const TextStyle(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: accentText,
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minTapSize),
      ),
      // Material3のListTileはタイトルに既定でbodyLarge（＝白光明朝）を使う
      // 仕様のため、fontFamilyを明示していないtitle: Text(...)は軒並み
      // 明朝体になってしまっていた（項目名フォント回帰の主因の一つ）。
      // titleTextStyleをここで明示することで、SwitchListTile・
      // RadioListTile・CheckboxListTile（いずれも内部でListTileを使う）を
      // 含め、アプリ全体のリスト項目タイトルを一括でくらむぼんへ揃える。
      // 個別のTextウィジェットが独自styleを指定していれば、そちらが
      // 優先されるため既存の明示指定箇所への影響はない。
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        // 一覧の行の先頭アイコンは背景の上の差し色＝アクセントの文字・アイコン色。
        iconColor: accentText,
        selectedColor: preset.selectionTextColor,
        selectedTileColor: selectionColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: preset.textColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: preset.menuBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      // AlertDialogのtitleは既定でheadlineSmall（＝白光明朝）を使う仕様の
      // ため、fontFamilyを明示していないtitle: Text(...)は軒並み明朝体に
      // なってしまっていた（listTileThemeと同種の問題）。titleTextStyleを
      // ここで明示することで、アプリ全体のダイアログタイトルを一括で
      // くらむぼんへ揃える。個別のTextウィジェットが独自styleを指定して
      // いれば、そちらが優先されるため既存の明示指定箇所への影響はない。
      dialogTheme: DialogThemeData(
        backgroundColor: popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: preset.textColor),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: popupColor,
        modalBackgroundColor: popupColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: popupColor,
        // AppBarのtitleTextStyle・FilledButtonのtextStyleとまったく同じ罠。
        // 素のTextStyle()を渡すとそれが本文の書式を丸ごと決めてしまい、
        // ThemeData.fontFamily='HakkouMincho'は継承されない。その結果
        // **アプリ中のSnackBarの文字だけ**端末標準フォント（Roboto等）で
        // 描かれ、同梱フォントの周囲から明確に浮く（日本語以外の端末では
        // 字形が別物になる）。SnackBarの文は説明文なので本文の書体
        // （textTheme.bodyMedium＝白光明朝）を土台にして色だけ上書きする。
        // 操作ボタン（「元に戻す」等）はlabelLargeで描かれ、小さく、
        // くらむぼんの太字だと潰れるので白光明朝のまま（ユーザー指定）。
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: preset.textColor,
        ),
        // 操作ボタン（「元に戻す」等）の色。Material3の既定は暗い下地向けの
        // inversePrimaryで、このアプリのSnackBarは下地がポップアップの色
        // （明るいテーマでは白に近い）なので、ほとんど見えなかった。
        // ダイアログの文字ボタンと同じ色にする。
        actionTextColor: accentText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      // Flutter既定のツールチップは下地が90%の不透明度で、後ろの画面が
      // 透ける。色と形は既定のまま、不透明にする。
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? Colors.white
              : Colors.grey.shade700,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.menuBgColor,
        selectedColor: selectionColor,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: preset.selectionTextColor,
        ),
        // 完全な丸み（ピル型）：日本のアプリでよく使われる柔らかいタグ・
        // フィルターチップの形状。
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      // All selected check marks share the explicit selection background and
      // selected foreground from Theme & Appearance. Unselected states keep
      // Flutter's normal themed fill (no forced contrast correction).
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? selectionColor
              : null,
        ),
        checkColor: WidgetStatePropertyAll(preset.selectionTextColor),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.5)
              : null,
        ),
      ),
      // Selected labels/icons use a separate foreground *only* when their
      // background is the user's selected-surface color. Unselected content
      // continues to use the normal text token.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // 切り替えボタンのラベルも他のボタンと同じくくらむぼん。
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? selectionColor : preset.menuBgColor,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? preset.selectionTextColor : preset.textColor,
          ),
          iconColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? preset.selectionTextColor : preset.textColor,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: selectionColor,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? preset.selectionTextColor : preset.textColor,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? preset.selectionTextColor : preset.textColor,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // 完全な円形：角丸四角より親しみやすく、LINE等の日本製アプリで
        // 定番のFAB形状。
        shape: const CircleBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: accentText,
        unselectedLabelColor: preset.textColor.withValues(alpha: 0.6),
      ),
      dividerTheme: DividerThemeData(
        color: preset.textColor.withValues(alpha: 0.08),
      ),
    );
  }

  /// [textTheme]の全スタイルへ[fallback]（フォント未対応文字の代替フォント
  /// 列）を適用したコピーを返す。TextTheme.apply()にはfontFamilyFallback
  /// を指定するオプションが無いため、各スタイルへ個別にcopyWith()する。
  TextTheme _withFontFallback(TextTheme textTheme, List<String> fallback) {
    TextStyle? apply(TextStyle? style) =>
        style?.copyWith(fontFamilyFallback: fallback);
    return textTheme.copyWith(
      displayLarge: apply(textTheme.displayLarge),
      displayMedium: apply(textTheme.displayMedium),
      displaySmall: apply(textTheme.displaySmall),
      headlineLarge: apply(textTheme.headlineLarge),
      headlineMedium: apply(textTheme.headlineMedium),
      headlineSmall: apply(textTheme.headlineSmall),
      titleLarge: apply(textTheme.titleLarge),
      titleMedium: apply(textTheme.titleMedium),
      titleSmall: apply(textTheme.titleSmall),
      bodyLarge: apply(textTheme.bodyLarge),
      bodyMedium: apply(textTheme.bodyMedium),
      bodySmall: apply(textTheme.bodySmall),
      labelLarge: apply(textTheme.labelLarge),
      labelMedium: apply(textTheme.labelMedium),
      labelSmall: apply(textTheme.labelSmall),
    );
  }

  /// display/headline/title（見出し・項目名として使われるサイズ）のみ
  /// [fontFamily]（くらむぼん）へ差し替え、body/label（説明文・通常サイズの
  /// 文字）はそのまま（白光明朝）にする（フォントの使い分けルール）。
  TextTheme _applyHeadingFont(TextTheme textTheme, String fontFamily) {
    // 見出し用フォント（くらむぼん）は本文用より収録文字が少ないため、
    // 代替フォント列は消さずに引き継ぐ（以前はnullで消しており、
    // くらむぼんに無い文字が豆腐（□）になっていた）。
    TextStyle? heading(TextStyle? style) => style?.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: kHeadingFontFallback,
    );
    return textTheme.copyWith(
      displayLarge: heading(textTheme.displayLarge),
      displayMedium: heading(textTheme.displayMedium),
      displaySmall: heading(textTheme.displaySmall),
      headlineLarge: heading(textTheme.headlineLarge),
      headlineMedium: heading(textTheme.headlineMedium),
      headlineSmall: heading(textTheme.headlineSmall),
      titleLarge: heading(textTheme.titleLarge),
      titleMedium: heading(textTheme.titleMedium),
      titleSmall: heading(textTheme.titleSmall),
    );
  }

  /// 明朝体は線が細く視認性が低いため、太さがRegular（w400）以下、または
  /// 未指定のスタイルをMedium（w500）以上へ底上げする（
  /// 「全体的に明朝体の文字が読みにくいので太くする」）。既に太字指定済み
  /// のスタイルはそのまま維持する。
  TextTheme _boldenForReadability(TextTheme textTheme) {
    TextStyle? bolden(TextStyle? style) {
      if (style == null) return style;
      final weight = style.fontWeight ?? FontWeight.w400;
      if (weight.value >= FontWeight.w500.value) return style;
      return style.copyWith(fontWeight: FontWeight.w500);
    }

    return textTheme.copyWith(
      displayLarge: bolden(textTheme.displayLarge),
      displayMedium: bolden(textTheme.displayMedium),
      displaySmall: bolden(textTheme.displaySmall),
      headlineLarge: bolden(textTheme.headlineLarge),
      headlineMedium: bolden(textTheme.headlineMedium),
      headlineSmall: bolden(textTheme.headlineSmall),
      titleLarge: bolden(textTheme.titleLarge),
      titleMedium: bolden(textTheme.titleMedium),
      titleSmall: bolden(textTheme.titleSmall),
      bodyLarge: bolden(textTheme.bodyLarge),
      bodyMedium: bolden(textTheme.bodyMedium),
      bodySmall: bolden(textTheme.bodySmall),
      labelLarge: bolden(textTheme.labelLarge),
      labelMedium: bolden(textTheme.labelMedium),
      labelSmall: bolden(textTheme.labelSmall),
    );
  }
}
