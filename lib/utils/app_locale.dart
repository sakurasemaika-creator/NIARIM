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

/// [locale]に最も近い対応言語の文言を返す。対応していない言語なら日本語。
///
/// `AppLocalizations.of(context)`が使えない場所（MaterialAppの外側や、
/// 壊れた画面の代わりに出すエラー表示）から文言を引くために使う。
/// 台湾・香港・マカオの中国語は、scriptCodeが無くても繁体字にする。
AppLocalizations appLocalizationsFor(Locale? locale) {
  if (locale == null) return lookupAppLocalizations(const Locale('ja'));
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
  if (traditional) {
    return lookupAppLocalizations(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
  }
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(Locale(supported ? locale.languageCode : 'ja'));
}
