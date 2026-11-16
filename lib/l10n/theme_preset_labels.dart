import 'dart:ui';

import '../models/app_theme_preset.dart';
import '../services/theme_service.dart';

String themePresetLabel(AppThemePreset preset, Locale locale) {
  if (!ThemeService.usesBuiltInName(preset)) return preset.name;
  final language = switch ((locale.languageCode, locale.scriptCode)) {
    ('zh', 'Hant') => 'zh_Hant',
    (final language, _) => language,
  };
  final labels = _colorLabels[language];
  if (labels == null) return preset.name;

  final splitAt = preset.id.lastIndexOf('_');
  final hue = preset.id.substring(0, splitAt);
  final color = labels[hue == 'default' ? 'red' : hue];
  if (color == null) return preset.name;
  final dark = preset.id.endsWith('_dark');
  return switch (language) {
    'es' => '$color (modo ${dark ? 'oscuro' : 'claro'})',
    'fr' => '$color (mode ${dark ? 'sombre' : 'clair'})',
    'ko' => '$color (${dark ? '다크' : '라이트'})',
    'zh' => '$color（${dark ? '深色' : '浅色'}）',
    'zh_Hant' => '$color（${dark ? '深色' : '淺色'}）',
    _ => '$color (${dark ? 'Dark' : 'Light'})',
  };
}

const _colorLabels = {
  'en': {
    'red': 'Red',
    'orange': 'Orange',
    'yellow': 'Yellow',
    'green': 'Green',
    'blue': 'Blue',
    'indigo': 'Indigo',
    'purple': 'Purple',
    'pink': 'Pink',
    'light_purple': 'Light Purple',
    'light_blue': 'Light Blue',
    'emerald': 'Emerald Green',
    'dusty_pink': 'Dusty Pink',
    'dusty_blue': 'Dusty Blue',
    'dusty_green': 'Dusty Green',
  },
  'es': {
    'red': 'Rojo',
    'orange': 'Naranja',
    'yellow': 'Amarillo',
    'green': 'Verde',
    'blue': 'Azul',
    'indigo': 'Índigo',
    'purple': 'Púrpura',
    'pink': 'Rosa',
    'light_purple': 'Púrpura pastel',
    'light_blue': 'Azul pastel',
    'emerald': 'Verde esmeralda',
    'dusty_pink': 'Rosa empolvado',
    'dusty_blue': 'Azul apagado',
    'dusty_green': 'Verde apagado',
  },
  'fr': {
    'red': 'Rouge',
    'orange': 'Orange',
    'yellow': 'Jaune',
    'green': 'Vert',
    'blue': 'Bleu',
    'indigo': 'Indigo',
    'purple': 'Violet',
    'pink': 'Rose',
    'light_purple': 'Violet pastel',
    'light_blue': 'Bleu pastel',
    'emerald': 'Vert émeraude',
    'dusty_pink': 'Rose poudré',
    'dusty_blue': 'Bleu grisé',
    'dusty_green': 'Vert grisé',
  },
  'ko': {
    'red': '레드',
    'orange': '오렌지',
    'yellow': '옐로',
    'green': '그린',
    'blue': '블루',
    'indigo': '인디고',
    'purple': '퍼플',
    'pink': '핑크',
    'light_purple': '라이트 퍼플',
    'light_blue': '라이트 블루',
    'emerald': '에메랄드 그린',
    'dusty_pink': '더스티 핑크',
    'dusty_blue': '더스티 블루',
    'dusty_green': '더스티 그린',
  },
  'zh': {
    'red': '红色',
    'orange': '橙色',
    'yellow': '黄色',
    'green': '绿色',
    'blue': '蓝色',
    'indigo': '靛蓝色',
    'purple': '紫色',
    'pink': '粉色',
    'light_purple': '淡紫色',
    'light_blue': '淡蓝色',
    'emerald': '翡翠绿',
    'dusty_pink': '灰粉色',
    'dusty_blue': '灰蓝色',
    'dusty_green': '灰绿色',
  },
  'zh_Hant': {
    'red': '紅色',
    'orange': '橙色',
    'yellow': '黃色',
    'green': '綠色',
    'blue': '藍色',
    'indigo': '靛藍色',
    'purple': '紫色',
    'pink': '粉色',
    'light_purple': '淡紫色',
    'light_blue': '淡藍色',
    'emerald': '翡翠綠',
    'dusty_pink': '灰粉色',
    'dusty_blue': '灰藍色',
    'dusty_green': '灰綠色',
  },
};
