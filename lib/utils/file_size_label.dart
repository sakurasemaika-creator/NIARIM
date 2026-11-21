import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// バイト数を、表示の言語の書き方の大きさにする（ja「1.4KB」・en「1.4 KB」・
/// fr「1,4 Ko」）。
///
/// 数は言語の小数点で書き（intl）、単位とのつなぎ方・単位の名前は言語ごとの
/// 文（`fileSize*`）で決める。数と単位の間の空白は改行しない空白なので、
/// 数と単位が別の行へ分かれない。1024ごとに単位を上げ、B以外は小数1桁
/// （1桁目で丸めると1024になるときは次の単位：1023.96KB→1.0MB）。
String fileSizeLabel(AppLocalizations l10n, num bytes) {
  const step = 1024;
  const lastUnit = 4;
  var value = bytes.toDouble();
  var unit = 0;
  while (unit < lastUnit && value >= step) {
    value /= step;
    unit++;
  }
  if (unit > 0 &&
      unit < lastUnit &&
      double.parse(value.toStringAsFixed(1)) >= step) {
    value /= step;
    unit++;
  }
  final number = NumberFormat(
    unit == 0 ? '0' : '0.0',
    l10n.localeName,
  ).format(value);
  return switch (unit) {
    0 => l10n.fileSizeBytes(number),
    1 => l10n.fileSizeKilobytes(number),
    2 => l10n.fileSizeMegabytes(number),
    3 => l10n.fileSizeGigabytes(number),
    _ => l10n.fileSizeTerabytes(number),
  };
}
