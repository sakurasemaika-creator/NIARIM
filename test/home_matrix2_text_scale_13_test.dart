import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';
import 'helpers/home_matrix2_suites.dart';

/// ホームの表示マトリクスの続き：文字の大きさ1.3倍で、24幅×スマホ(844)/
/// PC(900)×7言語の全タブ（プロジェクト・作品一覧・共有の2つの一覧・
/// ゴミ箱）と引き出しを確かめる。
///
/// `home_display_matrix_test.dart`は大きな文字をスマホの320・360・390・
/// 760でしか撮っていない（PCは無い）。各セルで表示マトリクスと同じ確かめと
/// `helpers/home_matrix_checks.dart`の続きの確かめを行い、画像と一覧を
/// `build/home-matrix2/text-13`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  defineTextScaleMatrix(_run, 1.3);
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/text-13'),
  knownProblems: homeMatrix2Known(const ['DISC212']),
);
