import 'package:flutter/foundation.dart';

import '../engine/spectral_pigment_data.dart';

/// 移植したコード・データの著作権表示とライセンス本文を、Flutter標準の
/// ライセンス一覧（設定 → 利用規約・ライセンス → オープンソース
/// ライセンス）へ登録する。
///
/// pubのパッケージではないためLicenseRegistryの自動収集に入らない。
/// 現在は、ブラシのアナログ風混色が使うspectral.js（MIT License）の
/// 分光データのみ。MIT Licenseは再配布時に著作権表示と許諾表示の同梱を
/// 求めている。
void registerPortedCodeLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['spectral.js'], kSpectralJsLicense);
  });
}
