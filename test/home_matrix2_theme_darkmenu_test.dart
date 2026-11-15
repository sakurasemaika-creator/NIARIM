import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';
import 'helpers/home_matrix2_suites.dart';

/// ホームの表示マトリクスの続き：メニューが暗い自作テーマ
/// （`home_display_matrix_test.dart`の自作テーマ。本文の文字色はメニューの
/// 地の上では読めず、アプリは起動画面に救済ボタンを出す。DISC199）で、
/// 24幅×スマホ(844)/PC(900)の全セルを確かめる
/// （プロジェクトのタブは7言語、ほかのタブと引き出しはja/en/fr/ko/zh）。
///
/// `home_display_matrix_test.dart`はテーマを390・1280の2幅でしか撮って
/// いない。各セルで表示マトリクスと同じ確かめと、
/// `helpers/home_matrix_checks.dart`の続きの確かめ（読める色はアプリ自身の
/// 判定で、文字・印ごとにその下の面の色と比べる）を行い、画像と一覧を
/// `build/home-matrix2/theme-darkmenu`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  defineThemeMatrix(_run, 'custom');
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/theme-darkmenu'),
  knownProblems: homeMatrix2Known(const ['DISC212', 'DISC219']),
);
