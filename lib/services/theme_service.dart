import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_preset.dart';

class ThemeService extends ChangeNotifier {
  static const _prefsPresetsKey = 'theme_presets';
  static const _prefsCurrentIdKey = 'theme_current_id';

  final List<AppThemePreset> _presets = [];
  AppThemePreset _current = AppThemePreset.defaultLight;

  List<AppThemePreset> get presets => List.unmodifiable(_presets);
  AppThemePreset get current => _current;

  ThemeData get themeData => _buildTheme(_current);

  // 虹7色（赤・橙・黄・緑・青・藍・紫）のテーマプリセットを、それぞれ
  // ライト/ダーク両方用意する（仕様書24・タスク#93）。「赤」はアプリの
  // 既定色である珊瑚ピンク（defaultLight/defaultDark）が該当する。
  // デフォルトで選択されるのはdefaultLight（見た目はライト基調）と
  // なるよう、リストの先頭に置く。
  static const List<AppThemePreset> _builtInPresets = [
    AppThemePreset.defaultLight, // 赤（ライト・既定選択）
    AppThemePreset.defaultDark, // 赤（ダーク）
    AppThemePreset(
      id: 'orange_light',
      name: 'オレンジ（ライト）',
      accentColor: Color(0xFFFF8A3D),
      textColor: Color(0xFF2E2013),
      panelBgColor: Color(0xFFFFF6EE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFFF8A3D),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'orange_dark',
      name: 'オレンジ（ダーク）',
      accentColor: Color(0xFFFF8A3D),
      textColor: Color(0xFFFAF0E6),
      panelBgColor: Color(0xFF1F160E),
      menuBgColor: Color(0xFF2A1D12),
      selectionColor: Color(0xFFFF8A3D),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'yellow_light',
      name: 'イエロー（ライト）',
      accentColor: Color(0xFFF2B90F),
      textColor: Color(0xFF2E2A12),
      panelBgColor: Color(0xFFFFFBEA),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFF2B90F),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'yellow_dark',
      name: 'イエロー（ダーク）',
      accentColor: Color(0xFFF2B90F),
      textColor: Color(0xFFFAF6E6),
      panelBgColor: Color(0xFF1E1B0C),
      menuBgColor: Color(0xFF292410),
      selectionColor: Color(0xFFF2B90F),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'green_light',
      name: 'グリーン（ライト）',
      accentColor: Color(0xFF3DDC97),
      textColor: Color(0xFF16291F),
      panelBgColor: Color(0xFFF1FBF6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF3DDC97),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'green_dark',
      name: 'グリーン（ダーク）',
      accentColor: Color(0xFF3DDC97),
      textColor: Color(0xFFF1FAF5),
      panelBgColor: Color(0xFF101A15),
      menuBgColor: Color(0xFF17251D),
      selectionColor: Color(0xFF3DDC97),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'blue_light',
      name: 'ブルー（ライト）',
      accentColor: Color(0xFF3AA6FF),
      textColor: Color(0xFF16232E),
      panelBgColor: Color(0xFFF1F7FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF3AA6FF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'blue_dark',
      name: 'ブルー（ダーク）',
      accentColor: Color(0xFF3AA6FF),
      textColor: Color(0xFFF2F6FA),
      panelBgColor: Color(0xFF11181F),
      menuBgColor: Color(0xFF182430),
      selectionColor: Color(0xFF3AA6FF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'indigo_light',
      // 同じ藍色系統を指す馴染み深い和名（藍色）を名前に使う。
      name: '藍色（ライト）',
      accentColor: Color(0xFF5C6BFF),
      textColor: Color(0xFF1E2033),
      panelBgColor: Color(0xFFF3F3FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF5C6BFF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'indigo_dark',
      name: '藍色（ダーク）',
      accentColor: Color(0xFF5C6BFF),
      textColor: Color(0xFFF0F1FA),
      panelBgColor: Color(0xFF14151F),
      menuBgColor: Color(0xFF1C1E2D),
      selectionColor: Color(0xFF5C6BFF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'purple_light',
      name: 'パープル（ライト）',
      accentColor: Color(0xFFB15CFF),
      textColor: Color(0xFF2B2033),
      panelBgColor: Color(0xFFF8F1FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFB15CFF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'purple_dark',
      name: 'パープル（ダーク）',
      accentColor: Color(0xFFB15CFF),
      textColor: Color(0xFFF6F1FA),
      panelBgColor: Color(0xFF19141F),
      menuBgColor: Color(0xFF241C2D),
      selectionColor: Color(0xFFB15CFF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    // ここから追加のパステル・ニュアンスカラー。
    AppThemePreset(
      id: 'pink_light',
      name: 'ピンク（ライト）',
      accentColor: Color(0xFFFF7EB3),
      textColor: Color(0xFF33202A),
      panelBgColor: Color(0xFFFFF1F6),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFFF7EB3),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'pink_dark',
      name: 'ピンク（ダーク）',
      accentColor: Color(0xFFFF7EB3),
      textColor: Color(0xFFFAEEF3),
      panelBgColor: Color(0xFF1F1418),
      menuBgColor: Color(0xFF2B1B22),
      selectionColor: Color(0xFFFF7EB3),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'light_purple_light',
      name: 'ライトパープル（ライト）',
      accentColor: Color(0xFFB39DDB),
      textColor: Color(0xFF272233),
      panelBgColor: Color(0xFFF6F2FC),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFB39DDB),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'light_purple_dark',
      name: 'ライトパープル（ダーク）',
      accentColor: Color(0xFFB39DDB),
      textColor: Color(0xFFF2EFF9),
      panelBgColor: Color(0xFF19171F),
      menuBgColor: Color(0xFF211E2C),
      selectionColor: Color(0xFFB39DDB),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'light_blue_light',
      name: 'ライトブルー（ライト）',
      accentColor: Color(0xFF90CAF9),
      textColor: Color(0xFF1D2733),
      panelBgColor: Color(0xFFF0F8FE),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF90CAF9),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'light_blue_dark',
      name: 'ライトブルー（ダーク）',
      accentColor: Color(0xFF90CAF9),
      textColor: Color(0xFFEDF5FB),
      panelBgColor: Color(0xFF141A1F),
      menuBgColor: Color(0xFF1C2530),
      selectionColor: Color(0xFF90CAF9),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'emerald_light',
      name: 'エメラルドグリーン（ライト）',
      accentColor: Color(0xFF10B981),
      textColor: Color(0xFF13291F),
      panelBgColor: Color(0xFFECFAF4),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF10B981),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'emerald_dark',
      name: 'エメラルドグリーン（ダーク）',
      accentColor: Color(0xFF10B981),
      textColor: Color(0xFFE9FAF3),
      panelBgColor: Color(0xFF0D1815),
      menuBgColor: Color(0xFF13221D),
      selectionColor: Color(0xFF10B981),
      updateMarkColor: Color(0xFFFFB020),
    ),
    // くすみカラー（色名は「くすみ（カラー名）」表記）。
    AppThemePreset(
      id: 'dusty_pink_light',
      name: 'くすみピンク（ライト）',
      accentColor: Color(0xFFD8A0A6),
      textColor: Color(0xFF2E2325),
      panelBgColor: Color(0xFFFAF2F2),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFFD8A0A6),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'dusty_pink_dark',
      name: 'くすみピンク（ダーク）',
      accentColor: Color(0xFFD8A0A6),
      textColor: Color(0xFFF5ECED),
      panelBgColor: Color(0xFF1C1516),
      menuBgColor: Color(0xFF261C1E),
      selectionColor: Color(0xFFD8A0A6),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'dusty_blue_light',
      name: 'くすみブルー（ライト）',
      accentColor: Color(0xFF8DA9C4),
      textColor: Color(0xFF212B33),
      panelBgColor: Color(0xFFF1F5F9),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF8DA9C4),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'dusty_blue_dark',
      name: 'くすみブルー（ダーク）',
      accentColor: Color(0xFF8DA9C4),
      textColor: Color(0xFFEDF1F5),
      panelBgColor: Color(0xFF151A1E),
      menuBgColor: Color(0xFF1C232B),
      selectionColor: Color(0xFF8DA9C4),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'dusty_green_light',
      name: 'くすみグリーン（ライト）',
      accentColor: Color(0xFF8FB89D),
      textColor: Color(0xFF20281F),
      panelBgColor: Color(0xFFF2F8F3),
      menuBgColor: Color(0xFFFFFFFF),
      selectionColor: Color(0xFF8FB89D),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'dusty_green_dark',
      name: 'くすみグリーン（ダーク）',
      accentColor: Color(0xFF8FB89D),
      textColor: Color(0xFFEEF4EF),
      panelBgColor: Color(0xFF151A16),
      menuBgColor: Color(0xFF1D251F),
      selectionColor: Color(0xFF8FB89D),
      updateMarkColor: Color(0xFFFFB020),
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsPresetsKey);
    if (raw == null || raw.isEmpty) {
      _presets.addAll(_builtInPresets);
    } else {
      _presets.addAll(raw.map((s) => AppThemePreset.fromJson(jsonDecode(s) as Map<String, dynamic>)));
      // 保存済みプリセット一覧に、組み込みプリセット（パステル・
      // ニュアンス・くすみカラー等）を反映する（同IDが既に存在する場合は
      // 追加しない。プリセット名は同一IDであれば保存済みデータ側が優先
      // されるため、名称を変更したい場合はプリセットの削除→再度組み込み
      // 一覧から選び直すことで反映できる）。
      final existingIds = _presets.map((p) => p.id).toSet();
      final missing = _builtInPresets.where((p) => !existingIds.contains(p.id));
      if (missing.isNotEmpty) _presets.addAll(missing);
    }
    final currentId = prefs.getString(_prefsCurrentIdKey);
    if (currentId != null) {
      _current = _presets.firstWhere((p) => p.id == currentId, orElse: () => _presets.first);
    } else if (_presets.isNotEmpty) {
      _current = _presets.first;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsPresetsKey, _presets.map((p) => jsonEncode(p.toJson())).toList());
    await prefs.setString(_prefsCurrentIdKey, _current.id);
  }

  void applyPreset(String id) {
    final preset = _presets.firstWhere((p) => p.id == id, orElse: () => _current);
    _current = preset;
    notifyListeners();
    _persist();
  }

  /// カラーピッカーでのライブプレビュー用（仕様書24：「変更はアプリ全体へ
  /// 即時反映される」）。ドラッグ中に毎回SharedPreferencesへ書き込むのを
  /// 避けるため、通知のみ行い永続化はしない。確定はcommitCurrent()で行う。
  void previewCurrent(AppThemePreset preset) {
    _current = preset;
    notifyListeners();
  }

  /// previewCurrent()でのライブプレビュー結果を確定保存する（プリセット
  /// 一覧にも反映：組み込みプリセットを編集した場合はそのプリセット自体が
  /// 上書きされる。これは仕様書24の「上書き保存」と同じ挙動）。
  void commitCurrent() {
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

  /// テーマプリセットの並び替え（仕様書24：「並び替え | ドラッグで順序変更」）。
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
      _presets[idx] = _presets[idx].copyWith(isFavorite: !_presets[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  /// ポップなフラットデザインのThemeDataを構築する（仕様書24）。
  /// Material標準の角丸・階調をそのまま使わず、フラット・大きめタップ領域・
  /// 丸みの強い形状で統一し、スマホでの誤タップを減らす。
  ThemeData _buildTheme(AppThemePreset preset) {
    // 明暗（Brightness）は、以前は独立した「ベーステーマ」設定から決めて
    // いたが、プリセット自身の文字色・背景色と噛み合わない組み合わせを
    // 選べてしまい、暗い文字が暗い背景に埋もれて読めなくなる不具合の
    // 原因になっていた。プリセット自身の背景色（panelBgColor）の明るさ
    // から自動的に決めることで、常に矛盾のない組み合わせになるようにする。
    final brightness =
        preset.panelBgColor.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;
    // 「文字色」（仕様書24：UI全体の文字色）はonSurface系にも反映し、
    // ColorScheme.fromSeedが自動算出する既定の文字色（accentColorから
    // 逆算される、ユーザーが選んだtextColorとは無関係の値）で上書きされて
    // しまわないようにする。
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.accentColor,
      brightness: brightness,
    ).copyWith(
      primary: preset.accentColor,
      secondary: preset.selectionColor,
      onSurface: preset.textColor,
      onSurfaceVariant: preset.textColor.withValues(alpha: 0.7),
    );
    // 角丸を大きめにし、Google Material標準の角丸14pxよりも柔らかい印象にする
    // （LINE・メルカリ等、日本の人気アプリに共通するポップで丸みの強い形状）。
    const radius = 18.0;
    const minTapSize = Size(48, 48);
    // Text等が明示的に色指定していない場合に使うデフォルト文字色
    // （仕様書24「文字色 | UI全体の文字色」）。
    final baseTextTheme = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    // アプリ全体の基本フォント（仕様書24：白光明朝）。白光明朝に無い文字
    // （対応外の漢字・記号等）は、Android標準フォントへ直接落ちて浮いて
    // 見えないよう、まず源ノ明朝相当（Noto Serif JP）で穴埋めし、それでも
    // 無い場合のみ端末標準フォントへフォールバックする。数値表示は個別の
    // ウィジェット側でAndroid標準フォント（未指定＝Roboto/Noto Sans）を
    // 明示的に指定して上書きする。
    // 明朝体（白光明朝）は線が細く、通常の太さ（Regular）のままだと画面全体で
    // 文字が読みにくい。デフォルトの太さがRegular以下（未指定含む）の
    // スタイルはMedium以上へ底上げする（既に太字指定済みの箇所、例：
    // AppBarタイトルのBold等はそのまま維持される）。
    final bodyTextTheme = _boldenForReadability(_withFontFallback(
      baseTextTheme.apply(
        fontFamily: 'HakkouMincho',
        bodyColor: preset.textColor,
        displayColor: preset.textColor,
      ),
      const ['NotoSerifJP'],
    ));
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
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: preset.panelBgColor,
      // InkSparkle（Material Youの光るリップル）は「いかにも最新Android技術デモ」
      // 感が強く、GPU負荷も高いため、低スペック端末を考慮しつつ落ち着いた
      // タップフィードバックのInkRippleへ変更する。
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: preset.menuBgColor,
        foregroundColor: preset.textColor,
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
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: preset.textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ) ?? TextStyle(
          fontFamily: 'Kuramubon',
          color: preset.textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: preset.menuBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minTapSize),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: preset.menuBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: preset.menuBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: preset.menuBgColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: preset.menuBgColor,
        contentTextStyle: TextStyle(color: preset.textColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.menuBgColor,
        // 完全な丸み（ピル型）：日本のアプリでよく使われる柔らかいタグ・
        // フィルターチップの形状。
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.5) : null,
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
        labelColor: scheme.primary,
        unselectedLabelColor: preset.textColor.withValues(alpha: 0.6),
      ),
      dividerTheme: DividerThemeData(color: preset.textColor.withValues(alpha: 0.08)),
    );
  }

  /// [textTheme]の全スタイルへ[fallback]（フォント未対応文字の代替フォント
  /// 列）を適用したコピーを返す。TextTheme.apply()にはfontFamilyFallback
  /// を指定するオプションが無いため、各スタイルへ個別にcopyWith()する。
  TextTheme _withFontFallback(TextTheme textTheme, List<String> fallback) {
    TextStyle? apply(TextStyle? style) => style?.copyWith(fontFamilyFallback: fallback);
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
    TextStyle? heading(TextStyle? style) =>
        style?.copyWith(fontFamily: fontFamily, fontFamilyFallback: null);
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
  /// 未指定のスタイルをMedium（w500）以上へ底上げする（仕様書24：
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
