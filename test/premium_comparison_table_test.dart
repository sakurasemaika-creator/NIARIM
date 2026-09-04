import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// プレミアム紹介ページの比較表で、**行内の全セルが同じ高さ**になることを
/// 実レンダリングで検証する。
///
/// `Table`の縦位置揃えは既定が`top`で、各セルは自分の中身ぶんの高さしか
/// 持たない。そのため機能名が2行に折り返した行だけ、他の列の背景色が
/// 行の下端まで届かず**白い帯**が残っていた（「アニメ制作・描画機能」の行）。
/// `TableCellVerticalAlignment.intrinsicHeight`で解消している。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('比較表は折り返した行でも全セルが行の高さいっぱいに塗られる', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim_premium_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    // 幅を狭くして機能名を確実に折り返させる（不具合が出る条件）。
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle({int rounds = 5}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await settle();
    appRouter.go('/premium');
    await settle();
    tester.takeException();

    final table = tester.renderObject<RenderTable>(find.byType(Table));
    expect(table.rows, greaterThan(3));
    var wrappedRows = 0;
    for (var y = 0; y < table.rows; y++) {
      final heights = table.row(y).map((c) => c.size.height).toSet();
      expect(
        heights.length,
        1,
        reason: '$y行目のセルの高さが揃っていない（背景が行の下端まで塗られない）: $heights',
      );
      // 1行ぶんの文字高＋上下パディングを明らかに超えていれば折り返した行。
      if (heights.first > 48) wrappedRows++;
    }
    expect(wrappedRows, greaterThan(0), reason: '折り返した行が1つも無く、不具合の条件を再現できていない');
  });
}
