import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// SettingsService.languageに保存されている言語コードからLocaleを組み立てる。
/// 繁体字中国語（'zh_Hant'）はscriptCodeを伴うロケールのため、単純な
/// Locale(code)コンストラクタでは正しく解決できず、
/// Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')で
/// 明示的に組み立てる必要がある。他の言語はlanguageCodeのみで解決できる。
Locale localeFromLanguageCode(String code) {
  if (code == 'zh_Hant') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  return Locale(code);
}

/// [locale]に最も近い対応言語の文言を返す。対応していない言語なら英語。
///
/// `AppLocalizations.of(context)`が使えない場所（MaterialAppの外側や、
/// 壊れた画面の代わりに出すエラー表示）から文言を引くために使う。
/// 台湾・香港・マカオの中国語は、scriptCodeが無くても繁体字にする。
AppLocalizations appLocalizationsFor(Locale? locale) {
  return lookupAppLocalizations(
    localeFromLanguageCode(appLanguageCodeFor([?locale])),
  );
}

/// 端末の言語の並び（優先する順）から、対応する7言語のうち最初に当てはまる
/// 言語のコード（`SettingsService.language`の値）を返す。どれにも当てはまら
/// なければ英語（ユーザー指定。ドイツ語・ポルトガル語等の端末で日本語より
/// 読める人が多い）。中国語は繁体字（Hant、または文字の指定が無い台湾・
/// 香港・マカオ）なら'zh_Hant'、ほかは'zh'。
String appLanguageCodeFor(Iterable<Locale> locales) {
  for (final locale in locales) {
    if (locale.languageCode == 'zh') {
      final traditional = switch (locale.scriptCode) {
        'Hant' => true,
        'Hans' => false,
        _ => const {'TW', 'HK', 'MO'}.contains(locale.countryCode),
      };
      return traditional ? 'zh_Hant' : 'zh';
    }
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
    if (supported) return locale.languageCode;
  }
  return 'en';
}
