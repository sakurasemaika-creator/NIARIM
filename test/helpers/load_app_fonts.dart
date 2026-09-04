import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// スクリーンショットを撮るテストで、同梱フォントとMaterialアイコンを
/// 読み込む。
///
/// `flutter test`は既定でフォントを一切読み込まないため、撮ったPNGは
/// 文字もアイコンも豆腐（□）になり、**文字が読めない＝目視監査にならない**。
/// 画像を焼くテストからは必ずこれを呼ぶこと。
///
/// 実際のフォント読み込みは本物の非同期I/Oなので`tester.runAsync`の中で
/// 行う必要がある（FakeAsyncの下では完了しない）。
Future<void> loadAppFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    Future<void> loadFamily(String family, String needle) async {
      final matches = assets.where((a) => a.contains(needle)).toList();
      if (matches.isEmpty) return;
      final loader = FontLoader(family)
        ..addFont(rootBundle.load(matches.first));
      await loader.load();
    }

    Future<void> loadSdkMaterialIcons() async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot == null) return;
      final file = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      );
      if (!file.existsSync()) return;
      final data = ByteData.sublistView(
        Uint8List.fromList(await file.readAsBytes()),
      );
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(data));
      await loader.load();
    }

    await Future.wait([
      loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
      loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
      loadFamily('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
      loadFamily('FontAwesomeSolid', 'fa-solid-900.ttf'),
      loadFamily('FontAwesomeRegular', 'fa-regular-400.ttf'),
      loadFamily('FontAwesomeBrands', 'fa-brands-400.ttf'),
      loadSdkMaterialIcons(),
    ]);
  });
}
