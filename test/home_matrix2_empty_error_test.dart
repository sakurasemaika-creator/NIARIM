import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';

/// ホームの表示マトリクスの続き（2）：空のホームと、保存先を読めない
/// ホームの全タブ（プロジェクト・作品一覧・共有の2つの一覧・ゴミ箱）を、
/// 24幅×スマホ(844)/PC(900)×7言語の全セルで確かめる。
///
/// `home_display_matrix_test.dart`は空・読めないを境目の9幅でしか撮って
/// いない。空なら各タブの「ありません」の表示、読めないなら知らせと押せる
/// 「再試行」がその言語で出ること（[HomeContents]）に加えて、
/// `home_matrix2_tabs_test.dart`と同じ続きの確かめを行い、画像と一覧を
/// `build/home-matrix2/empty-error`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  for (final language in kHomeMatrixLanguages) {
    for (final contents in const [HomeContents.empty, HomeContents.failing]) {
      testWidgets('${contents.name} Home ($language): every tab at 24 widths '
          'x phone/PC', (tester) async {
        final m = HomeMatrix(tester, language, _run, contents: contents)
          ..extended = true;
        await m.begin();
        try {
          await m.start(failing: contents == HomeContents.failing);
          for (final pc in const [false, true]) {
            await m.setPc(pc);
            for (final w in kHomeMatrixWidths) {
              await m.resize(
                Size(
                  w.toDouble(),
                  pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
                ),
              );
              for (final view in HomeView.values) {
                await m.cell(contents.name, view);
              }
              await m.show(HomeView.projects);
            }
          }
        } finally {
          debugDisableShadows = true;
        }
        m.expectNoFailures();
      }, timeout: const Timeout(Duration(minutes: 40)));
    }
  }
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/empty-error'),
  knownProblems: homeMatrix2Known(const []),
);
