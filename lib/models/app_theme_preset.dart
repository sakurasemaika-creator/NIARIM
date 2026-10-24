import 'dart:ui';

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
    this.isFavorite = false,
  });

  /// 実際に使う[accentTextColor]（未指定なら差し色）。
  Color get effectiveAccentTextColor => accentTextColor ?? accentColor;

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
    accentColor: Color(0xFFFE8F9C),
    textColor: Color(0xFFF5F1F0),
    buttonTextColor: Color(0xFF17161C),
    menuTextColor: Color(0xFFF5F1F0),
    selectionTextColor: Color(0xFF17161C),
    panelBgColor: Color(0xFF17161C),
    menuBgColor: Color(0xFF201F27),
    selectionColor: Color(0xFFFE8F9C),
    updateMarkColor: Color(0xFFFFB020),
    accentTextColor: Color(0xFFFEB2B9),
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
    updateMarkColor: Color(0xFFCD8B07),
    accentTextColor: Color(0xFFBC0F45),
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
    if (accentTextColor != null)
      'accentTextColor': accentTextColor!.toARGB32(),
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
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}
