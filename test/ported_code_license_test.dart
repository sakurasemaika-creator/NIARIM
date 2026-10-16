// 移植したコード・データ（spectral.jsの分光データ、MIT License）の
// 著作権表示とライセンス本文が、アプリのライセンス一覧へ登録されている
// ことを確認する。pubのパッケージではないため自動収集されず、
// main.dartで明示的に登録している。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/ported_code_licenses.dart';
import 'package:niarim/engine/spectral_pigment_data.dart';

void main() {
  test('spectral.jsのMIT Licenseが著作権表示つきで登録される', () async {
    LicenseRegistry.reset();
    registerPortedCodeLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final spectral = entries.where((e) => e.packages.contains('spectral.js'));
    expect(spectral, hasLength(1));
    final text = spectral.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('MIT License'));
    expect(text, contains('Copyright (c) 2025 Ronald van Wijnen'));
    expect(text, contains('The above copyright notice and this permission'));
    expect(kSpectralJsLicense, contains('THE SOFTWARE IS PROVIDED "AS IS"'));
  });

  test('main.dartが起動時に登録を呼んでいる', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('registerPortedCodeLicenses();'));
  });

  test('データファイルの冒頭にもライセンス表示がある', () {
    final data = File(
      'lib/engine/spectral_pigment_data.dart',
    ).readAsStringSync();
    expect(data, contains('// Copyright (c) 2025 Ronald van Wijnen'));
    expect(data, contains('// MIT License'));
  });
}
