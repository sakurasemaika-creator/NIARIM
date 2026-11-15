import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';
import 'helpers/home_matrix2_suites.dart';

/// ホームの表示マトリクスの続き：読める自作テーマ（本文・メニューの文字・
/// メニューの地・パネル・差し色・差し色の文字がどれも違う色、
/// [kHomeMatrix2ReadableTheme]）で、24幅×スマホ(844)/PC(900)の全セルを
/// 確かめる（プロジェクトのタブは7言語、ほかのタブと引き出しは
/// ja/en/fr/ko/zh）。
///
/// `home_display_matrix_test.dart`はテーマを390・1280の2幅でしか撮って
/// いない。各セルで表示マトリクスと同じ確かめと、
/// `helpers/home_matrix_checks.dart`の続きの確かめ（読める色はアプリ自身の
/// 判定で、文字・印ごとにその下の面の色と比べる）を行い、画像と一覧を
/// `build/home-matrix2/theme-readable`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  defineThemeMatrix(_run, 'readable');
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/theme-readable'),
  knownProblems: homeMatrix2Known(const ['DISC212']),
);
