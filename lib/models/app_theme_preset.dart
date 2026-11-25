import 'dart:ui';

import '../utils/warning_color.dart';

/// UIテーマプリセットモデル。
///
/// 明暗（Brightness）はプリセット自身の背景色（panelBgColor）の明るさから
/// 自動的に、かつ常に矛盾なく決まる（`ThemeService._buildTheme()`参照）。
class AppThemePreset {
  final String id;
  final String name;
  final Color accentColor;
  final Color textColor;

  /// These are first-class user-defined foreground colors, never auto-corrected.
  final Color buttonTextColor;
  final Color menuTextColor;
  final Color selectionTextColor;
  final Color panelBgColor;
  final Color menuBgColor;
  final Color selectionColor;
  final Color updateMarkColor;

  /// 差し色で背景の上に直接描く文字・アイコン（選択中のタブ名・枠や文字の
  /// ボタン・空の表示のアイコン等）の色。塗りの上の文字（[buttonTextColor]）
  /// とは別に選べる。nullなら差し色と同じ（既存のテーマ・保存データの
  /// 見た目を変えない）。明るい差し色を選んだときに、読める色を自分で
  /// 指定するためのもので、自動では決めない。
  final Color? accentTextColor;

  /// 保存・引き継ぎに警告色が無かったプリセットは[warningColor]が決め方で
  /// 決める（[defaultWarningColorFor]）。
  final Color? _warningColor;
  final bool isFavorite;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
    required this.menuTextColor,
    required this.selectionTextColor,
    required this.panelBgColor,
    required this.menuBgColor,
    required this.selectionColor,
    required this.updateMarkColor,
    this.accentTextColor,
    this._warningColor,
    this.isFavorite = false,
  });

  /// 実際に使う[accentTextColor]（未指定なら差し色）。
  Color get effectiveAccentTextColor => accentTextColor ?? accentColor;

  /// 警告色：取り消せない操作（削除・完全削除・上書き・全データの削除）の
  /// 確かめのボタン・メニューの項目と、作品が保存できない・失われうる失敗の
  /// 知らせだけに使う色。ほかの色と同じく利用者が選べ、選んだ色は自動で
  /// 差し替えない。持たない（警告色より前の版の保存・引き継ぎ・書き出した
  /// テーマ）ときは、そのテーマの背景・差し色・更新マーク色から決める
  /// （[defaultWarningColorFor]。組み込みのテーマの値と同じ決め方）。
  /// [copyWith]・[toJson]はこの値を写すので、一度決めた警告色はほかの色を
  /// 変えても変わらない。
  Color get warningColor =>
      _warningColor ?? (_derivedWarning[this] ??= defaultWarningColorFor(this));

  static final Expando<Color> _derivedWarning = Expando('warningColor');

  AppThemePreset copyWith({
    String? id,
    String? name,
    Color? accentColor,
    Color? textColor,
    Color? buttonTextColor,
    Color? menuTextColor,
    Color? selectionTextColor,
    Color? panelBgColor,
    Color? menuBgColor,
    Color? selectionColor,
    Color? updateMarkColor,
    Object? accentTextColor = _unset,
    Color? warningColor,
    bool? isFavorite,
  }) {
    return AppThemePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      buttonTextColor: buttonTextColor ?? this.buttonTextColor,
      menuTextColor: menuTextColor ?? this.menuTextColor,
      selectionTextColor: selectionTextColor ?? this.selectionTextColor,
      panelBgColor: panelBgColor ?? this.panelBgColor,
      menuBgColor: menuBgColor ?? this.menuBgColor,
      selectionColor: selectionColor ?? this.selectionColor,
      updateMarkColor: updateMarkColor ?? this.updateMarkColor,
      accentTextColor: identical(accentTextColor, _unset)
          ? this.accentTextColor
          : accentTextColor as Color?,
      warningColor: warningColor ?? this.warningColor,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static const Object _unset = Object();

  // 既定テーマ：珊瑚ピンク（虹7色の「赤」に相当）を差し色にしたポップな
  // フラットデザイン（Material標準色をそのまま使わず、暖色寄りの配色で
  // オリジナリティを出す）。defaultDarkは「常にダーク」を選びたい場合の
  // 独立した選択肢として残す。
  static const defaultDark = AppThemePreset(
    id: 'default_dark',
    // 何色を指すか伝わる名前にするため、実際の差し色（珊瑚ピンク・虹7色で
    // いう「赤」）が分かる名前にしている。
    name: 'レッド（ダーク）',
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFFF5F1F0),
    buttonTextColor: Color(0xFFFFFFFF),
    menuTextColor: Color(0xFFF5F1F0),
    selectionTextColor: Color(0xFFFFFFFF),
    panelBgColor: Color(0xFF17161C),
    menuBgColor: Color(0xFF201F27),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
    warningColor: Color(0xFFFF998A),
  );

  static const defaultLight = AppThemePreset(
    id: 'default_light',
    name: 'レッド（ライト）',
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFF2B2730),
    buttonTextColor: Color(0xFFFFFFFF),
    menuTextColor: Color(0xFF2B2730),
    selectionTextColor: Color(0xFFFFFFFF),
    panelBgColor: Color(0xFFFAF7F5),
    menuBgColor: Color(0xFFFFFFFF),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
    warningColor: Color(0xFFDD2119),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'accentColor': accentColor.toARGB32(),
    'textColor': textColor.toARGB32(),
    'buttonTextColor': buttonTextColor.toARGB32(),
    'menuTextColor': menuTextColor.toARGB32(),
    'selectionTextColor': selectionTextColor.toARGB32(),
    'panelBgColor': panelBgColor.toARGB32(),
    'menuBgColor': menuBgColor.toARGB32(),
    'selectionColor': selectionColor.toARGB32(),
    'updateMarkColor': updateMarkColor.toARGB32(),
    if (accentTextColor != null) 'accentTextColor': accentTextColor!.toARGB32(),
    'warningColor': warningColor.toARGB32(),
    'isFavorite': isFavorite,
  };

  factory AppThemePreset.fromJson(Map<String, dynamic> json) => AppThemePreset(
    id: json['id'] as String,
    name: json['name'] as String,
    accentColor: Color(json['accentColor'] as int),
    textColor: Color(json['textColor'] as int),
    buttonTextColor: Color(json['buttonTextColor'] as int),
    menuTextColor: Color(json['menuTextColor'] as int),
    selectionTextColor: Color(json['selectionTextColor'] as int),
    panelBgColor: Color(json['panelBgColor'] as int),
    menuBgColor: Color(json['menuBgColor'] as int),
    selectionColor: Color(json['selectionColor'] as int),
    updateMarkColor: Color(json['updateMarkColor'] as int),
    accentTextColor: switch (json['accentTextColor']) {
      final int value => Color(value),
      _ => null,
    },
    // 警告色より前の版の保存・引き継ぎ・書き出したテーマには無い。無ければ
    // そのテーマの色から決める（[warningColor]）。
    warningColor: switch (json['warningColor']) {
      final int value => Color(value),
      _ => null,
    },
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}
