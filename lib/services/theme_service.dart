import '../config/accent_text_theme.dart';
import '../config/font_fallback.dart';
import '../config/signal_colors.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme_preset.dart';
import '../utils/color_contrast.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';
import '../utils/warning_color.dart';
import '../widgets/button_label_room.dart';
import '../widgets/menu_surface.dart';

class ThemeService extends ChangeNotifier {
  static const _prefsPresetsKey = 'theme_presets';

  // One-time rollback of the BUILT-IN palette to the original 28 examples
  // (before the independent-foreground review). The source definitions
  // already retain that original base palette; persisted built-in snapshots
  // could nevertheless keep a later proposed revision indefinitely.
  // Custom themes, their ordering, and the custom current theme are untouched.
  static const _originalBuiltInPaletteRestoreKey =
      'theme_original_builtin_palette_restored_v1';

  /// 現在の色そのもの（JSON）。テーマ一覧から配色だけ取り込んだ状態は
  /// どのプリセットとも一致しないため、IDだけでは復元できない。
  static const _prefsCurrentJsonKey = 'theme_current_json';
  static const _unreadableCurrentKey = 'theme_unreadable_current_json';

  /// テーマ一覧から配色だけ取り込んだ「現在の色」に付けるID。
  /// プリセット一覧には現れないIDなので、この状態では一覧のどのテーマにも
  /// チェックマークが付かず、色を編集してもどのテーマも書き換わらない。
  static const String customCurrentId = 'theme_custom_current';

  /// このサービスが持つ保存のキー。引き継ぎ（.niatra）の「端末保存データ」
  /// では扱わない（「テーマ」の項目が[mergeTransferred]で一覧と突き合わせて
  /// 取り込む。保存を直接書き換えると、動いている一覧の次の保存で戻り、
  /// 起動し直すとこの端末にしか無いテーマが消える。移行の印は端末ごと）。
  static const Set<String> savedPreferenceKeys = {
    _prefsPresetsKey,
    _prefsCurrentJsonKey,
    _unreadableCurrentKey,
    _originalBuiltInPaletteRestoreKey,
  };

  final List<AppThemePreset> _presets = [];
  AppThemePreset _current = AppThemePreset.defaultLight;

  /// 引き継ぎでもう1台の版を足した複製の記録（[init]で読む）。
  TransferCopyRecord _transferCopies = TransferCopyRecord.none();

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
    seedColor: AppThemePreset.defaultLight.accentColor,
  );

  /// [activeColorScheme]と同じく、BuildContextの無い所（描画クラス等）から
  /// 「アクセントの文字・アイコン色」を読むための値。themeDataを作るたびに
  /// 更新する。
  static Color activeAccentText = const Color(0xFFFF5C7A);

  /// 復旧確認ダイアログ専用。現在のテーマから独立している。
  /// プリセットの色をここで複製せず、正式なレッド（ライト）を利用する。
  static ThemeData rescueThemeDataFor(Locale? locale) =>
      ThemeService()._buildTheme(AppThemePreset.defaultLight, locale: locale);

  /// 利用者が確認した場合のみ、現在の配色を既定に戻して永続化する。
  /// 保存済みのユーザープリセット自体は削除・書き換えない。
  Future<void> resetToDefault() async {
    _current = AppThemePreset.defaultLight;
    notifyListeners();
    await _persist();
  }

  ThemeData get themeData => themeDataFor(null);

  /// 表示言語[locale]の画面に使うテーマ。本文の書体の列だけが言語で変わる
  /// （中国語は Noto Serif SC を主にする。[bodyFontFamilyFor]）。
  ThemeData themeDataFor(Locale? locale) {
    final data = _buildTheme(_current, locale: locale);
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
  // 組み込み28種の元の配色を正規値として保持する。
  // 比較用の代替配色を元の配色へ誤適用しないよう、全9色を
  // test/built_in_theme_original_palette_test.dart で固定検証する。
  // 警告色（warningColor）は後から足した役目で、各テーマの背景・差し色・
  // 更新マーク色から defaultWarningColorFor の決め方で決めた値
  // （test/theme_warning_color_test.dart が計算し直して見張る）。
  // 保存済みの編集版は現行の永続化仕様どおり保持する。
  static const List<AppThemePreset> _builtInPresets = [
    AppThemePreset.defaultLight, // 赤（ライト・既定選択）
    AppThemePreset.defaultDark, // 赤（ダーク）
    AppThemePreset(
      id: 'orange_light',
      name: 'オレンジ（ライト）',
      accentColor: Color(0xFFFF8A3D),
      textColor: Color(0xFF2E2013),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF2E2013),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFFFF6EE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFFF8A3D),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDD2119),
    ),
    AppThemePreset(
      id: 'orange_dark',
      name: 'オレンジ（ダーク）',
      accentColor: Color(0xFFFF8A3D),
      textColor: Color(0xFFFAF0E6),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFFAF0E6),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF1F160E),
      menuBgColor: Color(0xFF2A1D12),
      selectionColor: Color(0xFFFF8A3D),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF998A),
    ),
    AppThemePreset(
      id: 'yellow_light',
      name: 'イエロー（ライト）',
      accentColor: Color(0xFFF2B90F),
      textColor: Color(0xFF2E2A12),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF2E2A12),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFFFFBEA),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFF2B90F),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFE1261D),
    ),
    AppThemePreset(
      id: 'yellow_dark',
      name: 'イエロー（ダーク）',
      accentColor: Color(0xFFF2B90F),
      textColor: Color(0xFFFAF6E6),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFFAF6E6),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF1E1B0C),
      menuBgColor: Color(0xFF292410),
      selectionColor: Color(0xFFF2B90F),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
    ),
    AppThemePreset(
      id: 'green_light',
      name: 'グリーン（ライト）',
      accentColor: Color(0xFF3DDC97),
      textColor: Color(0xFF16291F),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF16291F),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFF1FBF6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF3DDC97),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDF241B),
    ),
    AppThemePreset(
      id: 'green_dark',
      name: 'グリーン（ダーク）',
      accentColor: Color(0xFF3DDC97),
      textColor: Color(0xFFF1FAF5),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFF1FAF5),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF101A15),
      menuBgColor: Color(0xFF17251D),
      selectionColor: Color(0xFF3DDC97),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
    ),
    AppThemePreset(
      id: 'blue_light',
      name: 'ブルー（ライト）',
      accentColor: Color(0xFF3AA6FF),
      textColor: Color(0xFF16232E),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF16232E),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFF1F7FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF3AA6FF),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDD2119),
    ),
    AppThemePreset(
      id: 'blue_dark',
      name: 'ブルー（ダーク）',
      accentColor: Color(0xFF3AA6FF),
      textColor: Color(0xFFF2F6FA),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFF2F6FA),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF11181F),
      menuBgColor: Color(0xFF182430),
      selectionColor: Color(0xFF3AA6FF),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
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
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
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
      warningColor: Color(0xFFFF998A),
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
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
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
      warningColor: Color(0xFFFF998A),
    ),
    // ここから追加のパステル・ニュアンスカラー。
    AppThemePreset(
      id: 'pink_light',
      name: 'ピンク（ライト）',
      accentColor: Color(0xFFFF7EB3),
      textColor: Color(0xFF33202A),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF33202A),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFFFF1F6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFFF7EB3),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
    ),
    AppThemePreset(
      id: 'pink_dark',
      name: 'ピンク（ダーク）',
      accentColor: Color(0xFFFF7EB3),
      textColor: Color(0xFFFAEEF3),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFFAEEF3),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF1F1418),
      menuBgColor: Color(0xFF2B1B22),
      selectionColor: Color(0xFFFF7EB3),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF998A),
    ),
    AppThemePreset(
      id: 'light_purple_light',
      name: 'ライトパープル（ライト）',
      accentColor: Color(0xFFB39DDB),
      textColor: Color(0xFF272233),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF272233),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFF6F2FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFB39DDB),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
    ),
    AppThemePreset(
      id: 'light_purple_dark',
      name: 'ライトパープル（ダーク）',
      accentColor: Color(0xFFB39DDB),
      textColor: Color(0xFFF2EFF9),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFF2EFF9),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF19171F),
      menuBgColor: Color(0xFF211E2C),
      selectionColor: Color(0xFFB39DDB),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF998A),
    ),
    AppThemePreset(
      id: 'light_blue_light',
      name: 'ライトブルー（ライト）',
      accentColor: Color(0xFF90CAF9),
      textColor: Color(0xFF1D2733),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF1D2733),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFF0F8FE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF90CAF9),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDD2119),
    ),
    AppThemePreset(
      id: 'light_blue_dark',
      name: 'ライトブルー（ダーク）',
      accentColor: Color(0xFF90CAF9),
      textColor: Color(0xFFEDF5FB),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFEDF5FB),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF141A1F),
      menuBgColor: Color(0xFF1C2530),
      selectionColor: Color(0xFF90CAF9),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
    ),
    AppThemePreset(
      id: 'emerald_light',
      name: 'エメラルドグリーン（ライト）',
      accentColor: Color(0xFF10B981),
      textColor: Color(0xFF13291F),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFF13291F),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFFECFAF4),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF10B981),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDD2119),
    ),
    AppThemePreset(
      id: 'emerald_dark',
      name: 'エメラルドグリーン（ダーク）',
      accentColor: Color(0xFF10B981),
      textColor: Color(0xFFE9FAF3),
      buttonTextColor: Color(0xFFFFFFFF),
      menuTextColor: Color(0xFFE9FAF3),
      selectionTextColor: Color(0xFFFFFFFF),
      panelBgColor: Color(0xFF0D1815),
      menuBgColor: Color(0xFF13221D),
      selectionColor: Color(0xFF10B981),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF998A),
    ),
    // くすみカラー（色名は「くすみ（カラー名）」表記）。
    AppThemePreset(
      id: 'dusty_pink_light',
      name: 'くすみピンク（ライト）',
      accentColor: Color(0xFFD8A0A6),
      textColor: Color(0xFF2E2325),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF2E2325),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFFAF2F2),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFD8A0A6),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
    ),
    AppThemePreset(
      id: 'dusty_pink_dark',
      name: 'くすみピンク（ダーク）',
      accentColor: Color(0xFFD8A0A6),
      textColor: Color(0xFFF5ECED),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFF5ECED),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF1C1516),
      menuBgColor: Color(0xFF261C1E),
      selectionColor: Color(0xFFD8A0A6),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF998A),
    ),
    AppThemePreset(
      id: 'dusty_blue_light',
      name: 'くすみブルー（ライト）',
      accentColor: Color(0xFF8DA9C4),
      textColor: Color(0xFF212B33),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF212B33),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFF1F5F9),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF8DA9C4),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDB1E16),
    ),
    AppThemePreset(
      id: 'dusty_blue_dark',
      name: 'くすみブルー（ダーク）',
      accentColor: Color(0xFF8DA9C4),
      textColor: Color(0xFFEDF1F5),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFEDF1F5),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF151A1E),
      menuBgColor: Color(0xFF1C232B),
      selectionColor: Color(0xFF8DA9C4),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
    ),
    AppThemePreset(
      id: 'dusty_green_light',
      name: 'くすみグリーン（ライト）',
      accentColor: Color(0xFF8FB89D),
      textColor: Color(0xFF20281F),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFF20281F),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFFF2F8F3),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF8FB89D),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFDD2119),
    ),
    AppThemePreset(
      id: 'dusty_green_dark',
      name: 'くすみグリーン（ダーク）',
      accentColor: Color(0xFF8FB89D),
      textColor: Color(0xFFEEF4EF),
      buttonTextColor: Color(0xFF17161C),
      menuTextColor: Color(0xFFEEF4EF),
      selectionTextColor: Color(0xFF17161C),
      panelBgColor: Color(0xFF151A16),
      menuBgColor: Color(0xFF1D251F),
      selectionColor: Color(0xFF8FB89D),
      updateMarkColor: Color(0xFFFFB020),
      warningColor: Color(0xFFFF9C8D),
    ),
  ];

  static bool isBuiltInPreset(String id) =>
      _builtInPresets.any((preset) => preset.id == id);

  /// A renamed preset keeps its user-supplied name in every language.
  static bool usesBuiltInName(AppThemePreset preset) => _builtInPresets.any(
    (original) => original.id == preset.id && original.name == preset.name,
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _transferCopies = TransferCopyRecord.readFrom(
      prefs,
      TransferCopyRecord.themes,
    );
    final shouldRestoreBuiltIns =
        prefs.readBool(_originalBuiltInPaletteRestoreKey) != true;
    final originalBuiltIns = {
      for (final preset in _builtInPresets) preset.id: preset,
    };
    final raw = prefs.readStringList(_prefsPresetsKey);
    // A corrupt saved entry must not be rewritten during initialization.
    // Startup recovery tests require the original bytes to remain available
    // for diagnostics and future recovery. Defer migration in that case.
    var storedDataIsValid = true;
    // 型の違う値が入っている一覧・現在の色も、起動では書き換えない。
    // （移行済みの印は利用者の内容を持たない記録なので、読めなければ
    // 起動が書き直す。書き直さないと、組み込みテーマを元の配色へ戻す
    // 移行が起動のたびに走り、利用者の変更を毎回戻してしまう。）
    if (prefs.holdsUnreadableStringList(_prefsPresetsKey) ||
        (prefs.containsKey(_prefsCurrentJsonKey) &&
            prefs.get(_prefsCurrentJsonKey) is! String)) {
      storedDataIsValid = false;
    }
    final restoredPresets = readSavedJsonList(
      raw ?? const [],
      AppThemePreset.fromJson,
      onSkipped: () => storedDataIsValid = false,
      listKey: _prefsPresetsKey,
    );
    if (raw == null || raw.isEmpty) {
      _presets.addAll(_builtInPresets);
    } else {
      _presets.addAll(restoredPresets);
      // 保存済みプリセット一覧に、組み込みプリセット（パステル・
      // ニュアンス・くすみカラー等）を反映する（同IDが既に存在する場合は
      // 追加しない。利用者が付けた名前は保存済みデータを優先する）。
      final existingIds = _presets.map((p) => p.id).toSet();
      final missing = _builtInPresets.where((p) => !existingIds.contains(p.id));
      if (missing.isNotEmpty) _presets.addAll(missing);
    }
    if (shouldRestoreBuiltIns) {
      // The built-in ID denotes a shipped palette, even when an older
      // revision was written to SharedPreferences. Restore its original
      // colors in the same slot, while keeping the favorite flag and list
      // order. User-created presets with independent IDs are never modified.
      for (var i = 0; i < _presets.length; i++) {
        final stored = _presets[i];
        final original = originalBuiltIns[stored.id];
        if (original != null) {
          _presets[i] = original.copyWith(
            name: stored.name,
            isFavorite: stored.isFavorite,
          );
        }
      }
    }
    // 現在の色は「一覧のどれか」とは限らないため、保存したJSONから復元する。
    final currentJson = prefs.readString(_prefsCurrentJsonKey);
    final restoredCurrent = readSavedJsonList(
      [?currentJson],
      AppThemePreset.fromJson,
      onSkipped: () => storedDataIsValid = false,
      listKey: _prefsCurrentJsonKey,
    ).firstOrNull;
    if (restoredCurrent != null) {
      // Only an explicitly selected built-in should follow the rollback.
      // A color-sampled/current-custom theme is a separate saved creation,
      // so preserve all of its foreground tokens exactly.
      final original = shouldRestoreBuiltIns
          ? originalBuiltIns[restoredCurrent.id]
          : null;
      _current = original == null
          ? restoredCurrent
          : original.copyWith(
              name: restoredCurrent.name,
              isFavorite: restoredCurrent.isFavorite,
            );
    } else if (_presets.isNotEmpty) {
      _current = _presets.first;
    }
    if (shouldRestoreBuiltIns && storedDataIsValid) {
      // Persist before marking the migration. Never rewrite a malformed
      // theme entry or current JSON on startup: a later recovery attempt
      // still needs the original stored bytes.
      await _persist();
      await prefs.setBool(_originalBuiltInPaletteRestoreKey, true);
    }
  }

  Future<void> _persist() async {
    await _persistPresets();
    await _persistCurrent();
  }

  Future<void> _persistPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setSavedJsonList(
      _prefsPresetsKey,
      _presets.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final unreadable = SavedListCarryOver.keep(_prefsCurrentJsonKey, []);
    if (unreadable.isNotEmpty) {
      final recovered = prefs.readStringList(_unreadableCurrentKey) ?? [];
      final preserved = await prefs.setStringList(_unreadableCurrentKey, [
        ...{...recovered, ...unreadable},
      ]);
      if (!preserved) return;
    }
    final saved = await prefs.setString(
      _prefsCurrentJsonKey,
      jsonEncode(_current.toJson()),
    );
    if (saved) SavedListCarryOver.remember(_prefsCurrentJsonKey, const []);
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

  /// 引き継ぎ（.niatra）で受け取ったテーマを、この端末の一覧へ合わせて
  /// 保存する。この端末の内容は黙って失わない（決まりは
  /// [mergeTransferredItems]）：同じIDで色か名前が違えば、この端末のテーマを
  /// 残し、受け取った方を「名前 (コピー)」として足す。組み込みのテーマは、
  /// この端末で元の配色のままなら受け取った方で置き換える。
  ///
  /// 一覧に無い、この端末の今の色と同じ配色で名前が同じか複製どうしの
  /// テーマ（もう1台がこの端末の今の色を一覧へ足し、戻ってきた複製）は
  /// 足さない。
  ///
  /// [current]（元の端末の今の色）も同じ決まりで扱う：
  /// - この端末の今の色が自分の色（どの組み込みのテーマの配色とも違う）なら
  ///   そのまま。元の端末の今の色も自分の色で、合わせた後の一覧のどの
  ///   テーマにも無ければ、一覧へ「名前 (コピー)」として足す（ブラシ・
  ///   パレットと同じく、食い違ったらこの端末の方を使い、もう1台の方は
  ///   一覧から選べる）。
  /// - この端末の今の色が組み込みの配色なら、元の端末の今の色にする。元の
  ///   端末で一覧のテーマを編集していたなら、合わせた後の一覧で同じ配色の
  ///   そのテーマ（この端末のテーマを残して足した複製のこともある）の編集に
  ///   し、無ければどのテーマの編集でもない色として持つ（受け取った色で
  ///   この端末のテーマを上書き保存しない）。
  ///
  /// 変えた保存だけを書く（何も変わらなければ書かない。読めない項目の
  /// 入った保存を、読めた分だけで書き直さない）。
  Future<void> mergeTransferred(
    List<AppThemePreset> incoming, {
    required TransferCopyNames copyNames,
    AppThemePreset? current,
  }) async {
    final shipped = {for (final p in _builtInPresets) p.id: p};
    Object? colours(AppThemePreset p) => p.toJson()
      ..remove('id')
      ..remove('name')
      ..remove('isFavorite');
    String key(AppThemePreset p) => jsonEncode(colours(p));
    final shippedColours = {for (final p in _builtInPresets) key(p)};
    final mine = _current;
    // もう1台がこの端末の今の色を一覧へ足した複製（行き来して戻ってきた
    // この端末の色）は、一覧には無くても、この端末に既にある。
    final known = {for (final p in _presets) p.id};
    bool myOwnColours(AppThemePreset p) =>
        !known.contains(p.id) &&
        key(p) == key(mine) &&
        TransferCopyNames.related(p.name, mine.name);
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    // 一覧と今の色は待たずに合わせる（起動のときに読んでおいた記録）。
    final copies = _transferCopies;
    var listChanged = mergeTransferredItems(
      _presets,
      [
        for (final p in incoming)
          if (!myOwnColours(p)) p,
      ],
      TransferMergeRules<AppThemePreset>(
        idOf: (p) => p.id,
        nameOf: (p) => p.name,
        contentOf: colours,
        organizationOf: (p) =>
            (favorite: p.isFavorite, tags: const [], folderId: null),
        withOrganization: (p, o) => p.copyWith(isFavorite: o.favorite),
        asCopy: (p, id, name) => p.copyWith(id: id, name: name),
        newId: (attempt) =>
            'theme_${DateTime.now().microsecondsSinceEpoch}_$attempt',
        copyNames: copyNames,
        shippedOf: (id) => shipped[id],
      ),
      copies: copies,
    );
    var next = mine;
    if (current != null && key(current) != key(mine)) {
      final theirs = key(current);
      bool sameColours(AppThemePreset p) => key(p) == theirs;
      if (!shippedColours.contains(key(mine))) {
        // この端末の今の色はそのまま。元の端末の自分の色は一覧から選べる
        // ように足す。
        if (!shippedColours.contains(theirs) && !_presets.any(sameColours)) {
          _presets.add(
            current.copyWith(
              id: 'theme_${DateTime.now().microsecondsSinceEpoch}_current',
              name: copyNames.next(current.name, {
                for (final p in _presets) p.name,
              }),
              isFavorite: false,
            ),
          );
          listChanged = true;
        }
      } else {
        final editing = incoming.any(
          (p) => p.id == current.id && sameColours(p),
        );
        next = editing
            ? _presets
                      .where((p) => p.id == current.id && sameColours(p))
                      .firstOrNull ??
                  _presets
                      .where(
                        (p) =>
                            sameColours(p) &&
                            TransferCopyNames.related(p.name, current.name),
                      )
                      .firstOrNull ??
                  current.copyWith(id: customCurrentId)
            // 一覧のテーマの編集ではない（配色だけ取り込んだ、または元の
            // 端末では消したテーマの）色は、この端末の同じIDのテーマの
            // 編集にしない。
            : current.copyWith(id: customCurrentId);
      }
    }
    // 一覧のテーマの編集なら、合わせた後の項目（お気に入り）を写す。
    final edited = next;
    next =
        _presets
            .where((p) => p.id == edited.id && key(p) == key(edited))
            .firstOrNull ??
        edited;
    final currentChanged =
        jsonEncode(next.toJson()) != jsonEncode(mine.toJson());
    if (!listChanged && !currentChanged) return;
    _current = next;
    notifyListeners();
    if (listChanged) await _persistPresets();
    if (currentChanged) await _persistCurrent();
    await copies.save();
  }

  void renamePreset(String id, String name) {
    final preset = _presets.where((entry) => entry.id == id).firstOrNull;
    if (preset != null) savePreset(preset.copyWith(name: name));
  }

  void resetPresetColors(String id) {
    final original = _builtInPresets
        .where((entry) => entry.id == id)
        .firstOrNull;
    final stored = _presets.where((entry) => entry.id == id).firstOrNull;
    if (original == null || stored == null) return;
    savePreset(
      original.copyWith(name: stored.name, isFavorite: stored.isFavorite),
    );
  }

  void deletePreset(String id) {
    final index = _presets.indexWhere((preset) => preset.id == id);
    if (index < 0 || _presets[index].isFavorite || isBuiltInPreset(id)) return;
    _presets.removeAt(index);
    if (_current.id == id) _current = _current.copyWith(id: customCurrentId);
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

  /// ダイアログ・ボトムシートの中身（メニューの面）のテーマを作る配色：
  /// 本文の文字色をメニューの文字色に、用紙をメニューの背景色（[popupColor]、
  /// 実際に見えている不透明な色）にする。面・線・明暗もメニューの背景色から
  /// 作るので、シートの中の入れ物も暗い面の上で読める。差し色・選択色は
  /// 画面と同じ色に見えるよう、画面の用紙（[panelColor]）の上で平たくして
  /// おく（ユーザーの選んだ色を差し替えない）。
  static AppThemePreset _menuSurfacePreset(
    AppThemePreset preset,
    Color panelColor,
    Color popupColor,
  ) => preset.copyWith(
    textColor: preset.menuTextColor,
    panelBgColor: popupColor,
    menuBgColor: popupColor,
    accentColor: opaqueOver(preset.accentColor, panelColor),
    accentTextColor: opaqueOver(preset.effectiveAccentTextColor, panelColor),
    selectionColor: opaqueOver(preset.selectionColor, panelColor),
  );

  /// ポップなフラットデザインのThemeDataを構築する。
  /// Material標準の角丸・階調をそのまま使わず、フラット・大きめタップ領域・
  /// 丸みの強い形状で統一し、スマホでの誤タップを減らす。
  ThemeData _buildTheme(
    AppThemePreset preset, {
    Locale? locale,
    SignalColors? signals,
  }) {
    final bodyFont = bodyFontFamilyFor(locale);
    final headingFont = headingFontFamilyFor(locale);
    final headingFallback = headingFontFallbackFor(locale);
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
    // 警告色（取り消せない操作・作品が失われうる失敗）と注意色（更新マーク
    // 色）。どちらもテーマ・外観で選ぶ色で、上の文字はテーマ自身の文字色・
    // 背景色から読める方を選ぶ（黒・白に決め打ちしない）。メニューの面の
    // テーマ（[_menuSurfacePreset]）は画面と同じ組を受け取る。
    final inks = themeInksOf(preset);
    final warning = opaqueOver(preset.warningColor, panelColor);
    final caution = opaqueOver(preset.updateMarkColor, panelColor);
    final signalColors =
        signals ??
        SignalColors(
          warning: warning,
          onWarning: readableInkOn(warning, inks),
          caution: caution,
          onCaution: readableInkOn(caution, inks),
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
      // Materialの誤りの状態（入力欄の枠・文字）も警告色で描く。
      error: signalColors.warning,
      onError: signalColors.onWarning,
      errorContainer: Color.alphaBlend(
        signalColors.warning.withValues(alpha: 0.16),
        popupColor,
      ),
      onErrorContainer: signalColors.warning,
      primary: accentColor,
      onPrimary: preset.buttonTextColor,
      primaryContainer: Color.alphaBlend(
        accentColor.withValues(alpha: 0.16),
        popupColor,
      ),
      secondary: selectionColor,
      onSecondary: preset.selectionTextColor,
      secondaryContainer: Color.alphaBlend(
        selectionColor.withValues(alpha: 0.16),
        popupColor,
      ),
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
          fontFamily: bodyFont,
          bodyColor: preset.textColor,
          displayColor: preset.textColor,
        ),
        bodyFontFallbackFor(locale),
      ),
    );
    // フォントの使い分け：項目名・見出しなど文字サイズが
    // 大きく目立たせたい箇所（display/headline/title）はくらむぼん、
    // それ以外の説明文・通常サイズの文字（body/label）はすべて白光明朝、
    // という切り分けに変更した（従来はくらむぼんをチュートリアル説明の
    // 吹き出し専用にしていたが、それは廃止しこの規則へ統一する）。
    final headingTextTheme = _applyHeadingFont(
      bodyTextTheme,
      headingFont,
      headingFallback,
    );
    // 入力欄に打った文字（Material 3 の TextField は bodyLarge で書く）。
    // 入力欄はメニューの背景色で塗る（inputDecorationTheme）ので、メニューの
    // 文字色で書く。本文の文字色のままだと、メニューを暗く・本文の文字を
    // 暗くしたテーマで打った字が読めなかった。lib配下で bodyLarge を画面の
    // 文に使っている所は無い（一覧の行の名前は listTileTheme の titleMedium）。
    // 画面の色で塗った入力欄（ヘルプ・活用Tips・フォントの検索）は、欄の
    // 側で本文の文字色を渡している。
    final textTheme = headingTextTheme.copyWith(
      bodyLarge: headingTextTheme.bodyLarge?.copyWith(color: menuForeground),
    );
    // Kuramubon's accented capitals and descenders extend beyond its 1em
    // metrics. Give wrapped action labels room between their baselines.
    final buttonLabelStyle = (textTheme.labelLarge ?? const TextStyle())
        .copyWith(
          fontFamily: headingFont,
          fontFamilyFallback: headingFallback,
          fontWeight: FontWeight.w700,
          height: 1.4,
        );
    // メニューの背景色で塗る入力欄の中の薄い文字・アイコン（Material 3 の
    // onSurfaceVariant と、押せないときの onSurface の38%に当たる色）。
    Color fieldInk(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? menuForeground.withValues(alpha: 0.38)
        : menuForeground.withValues(alpha: 0.7);
    // ダイアログ・ボトムシートの中身のテーマ（[MenuSurfaceTheme]）。本文と
    // メニューの文字色が同じテーマ（組み込みのテーマ）では要らない。
    final menuSurface = preset.textColor == preset.menuTextColor
        ? null
        : _buildTheme(
            _menuSurfacePreset(preset, panelColor, popupColor),
            locale: locale,
            signals: signalColors,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: bodyFont,
      textTheme: textTheme,
      extensions: [
        AccentTextTheme(accentText),
        signalColors,
        MenuSurfaceTheme(menuSurface),
      ],
      // 画面から開いたダイアログ・ボトムシートの中身を、メニューの面の
      // テーマ（上の menuSurface）で描く。動きは Flutter の既定のまま。
      pageTransitionsTheme: menuSurfacePageTransitionsTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: preset.textColor),
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
        // Align the title inset with the app's 16dp content/input gutter.
        // FitOrHideTitle handles constrained widths without truncating labels.
        titleSpacing: 16,
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
              fontFamily: headingFont,
              fontFamilyFallback: headingFallback,
              color: menuForeground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
      ),
      // PopupMenuItem labels do not automatically use AppBar foreground.
      // Match text/icon foreground to the same menu token as the top bar.
      popupMenuTheme: PopupMenuThemeData(
        // Flat popup surface: the default Material elevation looked like
        // a thick black border against light workspace themes.
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        color: popupColor,
        surfaceTintColor: popupColor,
        textStyle: textTheme.bodyMedium?.copyWith(color: menuForeground),
        // Material 3 のメニューの項目は textStyle ではなく labelTextStyle を
        // 見る。指定しないと項目名が本文の文字色（onSurface）で書かれ、
        // メニューの文字色を本文と分けたテーマ（暗いメニュー）で読めなかった。
        // 書体・大きさは今までどおり labelLarge。
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => textTheme.labelLarge?.copyWith(
            color: states.contains(WidgetState.disabled)
                ? menuForeground.withValues(alpha: 0.38)
                : menuForeground,
          ),
        ),
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
          // Material chooses onPrimary or onSecondaryContainer per variant.
          minimumSize: const Size(64, 48),
          // ラベルが折り返したら上下に余白を取ってボタンを伸ばす（くらむぼんの
          // 字は行の外へ出るので、余白が0だと字が枠を越える）。
          foregroundBuilder: buttonLabelRoomBuilder(minHeight: 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: buttonLabelStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: accentText,
          // 最小の高さはMaterial 3の既定（40）。
          foregroundBuilder: buttonLabelRoomBuilder(minHeight: 40),
          textStyle: buttonLabelStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(64, 48),
          foregroundBuilder: buttonLabelRoomBuilder(minHeight: 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: buttonLabelStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(48, 44),
          foregroundBuilder: buttonLabelRoomBuilder(minHeight: 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: buttonLabelStyle,
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
        // 一覧の行の先頭アイコンは補助の文字色（差し色にしない。差し色は押す
        // 主な操作・選んでいる状態・リンクのため。全部の行の印が差し色だと、
        // どれも同じ強さに見えて意味が無くなった）。選んだ行は selectedColor。
        // ホームの引き出しは所有者の判断で案Aの色を自分で渡している。
        iconColor: scheme.onSurfaceVariant,
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
        // 欄の中のヒント（前後の文字もヒントの書式）・名前・アイコンも、
        // メニューの背景色の上に書くのでメニューの文字色（薄さ・押せない時・
        // 入力中・誤りの色は Material 3 の既定と同じ）。欄の下の補足・文字数は
        // 欄の外なので既定のまま。
        hintStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(color: fieldInk(states)),
        ),
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) =>
              !states.contains(WidgetState.disabled) &&
                  (states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.error))
              ? const TextStyle()
              : TextStyle(color: fieldInk(states)),
        ),
        // 入力のある欄で上に浮いた名前も同じ。指定しないと Material 3 の既定
        // （本文の文字色70%）で描かれ、メニューを暗く・本文の文字を暗くした
        // テーマで読めなかった。欄ごとに labelStyle を渡すときは
        // floatingLabelStyle も渡すこと（テーマのこちらが先に使われる）。
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) =>
              !states.contains(WidgetState.disabled) &&
                  (states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.error))
              ? const TextStyle()
              : TextStyle(color: fieldInk(states)),
        ),
        prefixIconColor: WidgetStateColor.resolveWith(fieldInk),
        suffixIconColor: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.error) &&
                  !states.contains(WidgetState.disabled)
              ? (states.contains(WidgetState.hovered)
                    ? scheme.onErrorContainer
                    : scheme.error)
              : fieldInk(states),
        ),
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
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        // 題はダイアログの下地（メニューの背景色）の上に書くので、メニューの
        // 文字色。本文（contentTextStyle）は既定のまま：既定は言語ごとの字の
        // 大きさ・行の高さを持った bodyMedium で、ここで書くとそれが外れて
        // 行の高さが変わる。本文の色は MenuSurfaceTheme（中身全体のテーマ）で
        // メニューの文字色になる。
        titleTextStyle: textTheme.titleLarge?.copyWith(color: menuForeground),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: popupColor,
        modalBackgroundColor: popupColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // 中身をシートの形で切り抜く（既定は切り抜かない）。切り抜かないと、
        // スクロールして上の縁まで来た中身（トーンの四角い枠・色の付いた行）の
        // 角が、上の角の丸みの外に描かれた。
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: popupColor,
        // Target only the heavy black SnackBar shadow without flattening
        // unrelated raised surfaces or other dialogs.
        elevation: 0,
        // AppBarのtitleTextStyle・FilledButtonのtextStyleとまったく同じ罠。
        // 素のTextStyle()を渡すとそれが本文の書式を丸ごと決めてしまい、
        // ThemeData.fontFamily='HakkouMincho'は継承されない。その結果
        // **アプリ中のSnackBarの文字だけ**端末標準フォント（Roboto等）で
        // 描かれ、同梱フォントの周囲から明確に浮く（日本語以外の端末では
        // 字形が別物になる）。SnackBarの文は説明文なので本文の書体
        // （textTheme.bodyMedium＝白光明朝）を土台にして色だけ上書きする。
        // 操作ボタン（「元に戻す」等）はlabelLargeで描かれ、小さく、
        // くらむぼんの太字だと潰れるので白光明朝のまま（ユーザー指定）。
        // 下地はポップアップの色（メニューの背景色）なので、文はメニューの
        // 文字色（本文の文字色だと、メニューを暗く・本文の文字を暗くした
        // テーマで読めなかった）。閉じるボタンも同じ。
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: menuForeground),
        closeIconColor: menuForeground,
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
        triggerMode: TooltipTriggerMode.longPress,
        textStyle: textTheme.bodySmall?.copyWith(color: preset.menuTextColor),
        decoration: BoxDecoration(
          color: popupColor,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.menuBgColor,
        selectedColor: selectionColor,
        // RawChip resolves a WidgetStateColor for every chip type. A static
        // secondaryLabelStyle reaches ChoiceChip but misses Filter/InputChip.
        labelStyle: textTheme.labelLarge?.copyWith(
          color: WidgetStateColor.resolveWith((states) {
            // RawChip applies the standard disabled opacity while painting.
            if (states.contains(WidgetState.disabled)) return preset.textColor;
            return states.contains(WidgetState.selected)
                ? preset.selectionTextColor
                : preset.menuTextColor;
          }),
        ),
        checkmarkColor: preset.selectionTextColor,
        // 完全な丸み（ピル型）：日本のアプリでよく使われる柔らかいタグ・
        // フィルターチップの形状。
        shape: const StadiumBorder(),
        // 選んでいないチップは下地がメニューの背景色なので、同じ色の面
        // （シート・ダイアログ）の上では形が消えた。細い線で縁取る。
        // 選んだチップも同じ太さの線（選択色＝塗りと同じ色で見えない）にして、
        // 選ぶ・外すでチップの大きさを変えない（変えると押すたびに並びが動く）。
        // 線は縁の外側に描く（内側に描くとチップが線の太さだけ広がり、外側に
        // 描くフォーカスの輪〔ChipFocusRing〕と大きさが食い違った）。
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? selectionColor
                : scheme.outlineVariant,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      // All selected check marks share the explicit selection background and
      // selected foreground from Theme & Appearance. Unselected states keep
      // Flutter's normal themed fill (no forced contrast correction).
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) =>
              states.contains(WidgetState.selected) ? selectionColor : null,
        ),
        checkColor: WidgetStatePropertyAll(preset.selectionTextColor),
      ),
      // Keep the unused track visible on editing sheets and panels.
      sliderTheme: SliderThemeData(inactiveTrackColor: scheme.outline),
      // オンのスイッチは塗りの差し色の通り道に、塗りのボタンの文字色の
      // つまみ（塗りのボタンと同じ組み合わせで、救済判定が見張っている）。
      // 以前は差し色と半透明の差し色で、つまみが通り道に溶けて見えた。
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? scheme.onPrimary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? scheme.primary
              : null,
        ),
      ),
      // Selected labels/icons use a separate foreground *only* when their
      // background is the user's selected-surface color. Unselected segments
      // are filled with the menu background, so their labels/icons use the
      // menu text token (the same pair as unselected chips). The body text
      // token on the menu background vanished in themes that pair a dark
      // menu with dark body text.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // 切り替えボタンのラベルも他のボタンと同じくくらむぼん。
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontFamily: headingFont,
              fontFamilyFallback: headingFallback,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? selectionColor
                : preset.menuBgColor,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? preset.selectionTextColor
                : preset.menuTextColor,
          ),
          iconColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? preset.selectionTextColor
                : preset.menuTextColor,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: selectionColor,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? preset.selectionTextColor
                : preset.textColor,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? preset.selectionTextColor
                : preset.textColor,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // Remove the thick Material shadow for standard, mini and extended
        // FABs, including pressed/hovered/focused/disabled states. Do not
        // affect shadows on unrelated cards or intentional thin outlines.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        // 完全な円形：角丸四角より親しみやすく、LINE等の日本製アプリで
        // 定番のFAB形状。
        shape: const CircleBorder(),
        // 文字つきの浮かぶボタン（FloatingActionButton.extended）のラベルも
        // ほかのボタンと同じくくらむぼん。指定しないとMaterialの既定の
        // labelLarge（本文の書体の白光明朝）で描かれた。大きさは labelLarge の
        // まま、色はボタンが前景色で上書きする。
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          fontFamily: headingFont,
          fontFamilyFallback: headingFallback,
          fontWeight: FontWeight.w700,
        ),
      ),
      // タブは上部バー（メニューの背景色）の下に並べる（ヘルプ・活用Tips・
      // フォント・作品広場・特典）。選んでいない名前もメニューの文字色から
      // 作る（本文の文字色だと、メニューを暗く・本文の文字を暗くしたテーマで
      // 読めなかった）。用紙の色の面（PCのドック）に置くタブは
      // PanelSurfaceが本文の文字色へ戻す。
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: accentText,
        unselectedLabelColor: menuForeground.withValues(alpha: 0.6),
      ),
      // 数の印（作品広場の通知の数）は更新の印なので注意色（Materialの既定は
      // エラーの色＝警告色）。
      badgeTheme: BadgeThemeData(
        backgroundColor: signalColors.caution,
        textColor: signalColors.onCaution,
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
  TextTheme _applyHeadingFont(
    TextTheme textTheme,
    String fontFamily,
    List<String> fontFamilyFallback,
  ) {
    // 見出し用フォント（くらむぼん）は本文用より収録文字が少ないため、
    // 代替フォント列は消さずに引き継ぐ（以前はnullで消しており、
    // くらむぼんに無い文字が豆腐（□）になっていた）。
    TextStyle? heading(TextStyle? style) => style?.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
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
