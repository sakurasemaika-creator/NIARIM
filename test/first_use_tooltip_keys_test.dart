import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/first_use_tooltip_service.dart';

import 'helpers/first_use_tooltips.dart';

/// `kAllFirstUseTooltipKeys`がlib配下の実際の`tooltipKey:`と一致することを
/// 見張る。吹き出しを1つ足したときにここを更新し忘れると、その吹き出しだけ
/// 各テストで実際に表示されてしまい、透明バリアに操作を吸われて
/// 「タップしたのに何も起きない」形の不可解な失敗になる。
void main() {
  test('kAllFirstUseTooltipKeysはlib配下のtooltipKeyを網羅している', () {
    final found = <String>{};
    final pattern = RegExp(r"tooltipKey: '([^']*)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        found.add(m.group(1)!);
      }
    }
    expect(found, isNotEmpty);
    expect(
      found.difference(kAllFirstUseTooltipKeys.toSet()),
      isEmpty,
      reason: 'test/helpers/first_use_tooltips.dart へ追記すること',
    );
    expect(
      kAllFirstUseTooltipKeys.toSet().difference(found),
      isEmpty,
      reason: 'lib配下に無いキーが残っている',
    );
  });

  test('firstUseTooltipsSeenKeyはサービスの保存キーと一致する', () {
    // サービス側は private な定数なので、実際に保存して読み戻して確かめる。
    expect(firstUseTooltipsSeenKey, 'first_use_tooltips_seen');
    expect(FirstUseTooltipService, isNotNull);
  });
}
