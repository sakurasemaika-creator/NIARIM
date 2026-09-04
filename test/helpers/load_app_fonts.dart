import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// スクリーンショットを撮るテストで、同梱フォント・パッケージ同梱の
/// アイコンフォント・Materialアイコンをまとめて読み込む。
///
/// `flutter test`は既定でフォントを一切読み込まないため、撮ったPNGは
/// 文字もアイコンも豆腐（□）になり、**文字が読めない＝目視監査にならない**。
/// 画像を焼くテストからは必ずこれを呼ぶこと。
///
/// 同梱フォントの一覧は**`pubspec.yaml`から読む**。テスト側へ手で写すと、
/// フォントを足したときに更新し忘れてその字だけ豆腐で焼かれ、しかも
/// 「テストは緑」なので誰も気付かない（実際にDelaGothicOneと
/// ハングル・簡体字のサブセット4つが読み込まれていなかった）。
///
/// 実際のフォント読み込みは本物の非同期I/Oなので`tester.runAsync`の中で
/// 行う必要がある（FakeAsyncの下では完了しない）。
Future<void> loadAppFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    Future<void> loadFamily(String family, Iterable<String> paths) async {
      final loader = FontLoader(family);
      var added = 0;
      for (final path in paths) {
        if (!assets.contains(path)) continue;
        loader.addFont(rootBundle.load(path));
        added++;
      }
      if (added == 0) return;
      await loader.load();
    }

    // pubspec.yamlのfonts:から「ファミリー名→アセット」を読む。
    // yamlパッケージは直接の依存に入っていないため、この節の決まった
    // 書き方（`- family: X` の下に `- asset: path` が並ぶ）だけを拾う。
    final familyOf = <String, List<String>>{};
    String? currentFamily;
    for (final line in File('pubspec.yaml').readAsLinesSync()) {
      final family = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
      if (family != null) {
        currentFamily = family.group(1);
        familyOf[currentFamily!] = <String>[];
        continue;
      }
      final asset = RegExp(r'^\s*- asset:\s*(\S+)').firstMatch(line);
      if (asset != null && currentFamily != null) {
        familyOf[currentFamily]!.add(asset.group(1)!);
      }
    }
    final futures = <Future<void>>[
      for (final entry in familyOf.entries) loadFamily(entry.key, entry.value),
    ];

    // パッケージ同梱のフォントは、実行時のファミリー名が
    // `packages/<パッケージ名>/<ファミリー名>`になる。素のファミリー名で
    // 登録しても当たらず、そのアイコンだけ豆腐で焼かれてしまう
    // （ワークスペース設定のツールバー見本で消しゴム・バケツ等が
    // これになっていた）。ファイル名もパッケージの更新で変わるため、
    // マニフェストから拾って両方の名前で登録する。
    Future<void> loadPackageIconFont(String family, String needle) async {
      final match = assets.where((a) => a.contains(needle));
      if (match.isEmpty) return;
      final path = match.first;
      final package = RegExp(r'^packages/([^/]+)/').firstMatch(path)?.group(1);
      for (final name in [
        family,
        if (package != null) 'packages/$package/$family',
      ]) {
        await loadFamily(name, [path]);
      }
    }

    futures.addAll([
      loadPackageIconFont('FontAwesomeSolid', 'Free-Solid-900'),
      loadPackageIconFont('FontAwesomeRegular', 'Free-Regular-400'),
      loadPackageIconFont('FontAwesomeBrands', 'Brands-Regular-400'),
    ]);

    // Materialアイコンは同梱フォントではなくSDKのキャッシュから読む。
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final file = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      );
      if (file.existsSync()) {
        final data = ByteData.sublistView(file.readAsBytesSync());
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(data));
        futures.add(loader.load());
      }
    }

    await Future.wait(futures);
  });
}
