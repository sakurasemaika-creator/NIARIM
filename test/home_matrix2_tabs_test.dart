import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';

/// ホームの表示マトリクスの続き（1）：作品一覧・共有（受け取ったもの・
/// 自分が作成したもの）・ゴミ箱の中身のある一覧と、開いた引き出しを、
/// 24幅×スマホ(844)/PC(900)×7言語の全セルで確かめる。
///
/// `home_display_matrix_test.dart`はこれらを境目の9幅でしか撮っていない
/// （プロジェクトのタブだけが24幅）。各セルで、表示マトリクスと同じ確かめ
/// （例外・はみ出し・タブ・押せる操作・必ずある操作・浮かぶボタンの下・
/// その回の中身）に加えて、`helpers/home_matrix_checks.dart`の続きの確かめ
/// （文の切れ・語の途中の折り返し・その言語の文か・読める色・押せる大きさ
/// 48×48・一番下まで送ったとき浮かぶボタンの下に星・メニュー・絵・名前が
/// 無いこと・フォーカスの順）を行い、画像と一覧を
/// `build/home-matrix2/tabs`へ出す。
///
/// 直していない不具合は`helpers/home_matrix2_known_problems.dart`の表で
/// 見込み（番号と理由つき）、それ以外の問題が1つでも出たら失敗にする。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  for (final language in kHomeMatrixLanguages) {
    testWidgets('seeded Home ($language): Works, Shared received/created, '
        'Trash and the drawer at 24 widths x phone/PC', (tester) async {
      final m = HomeMatrix(tester, language, _run)..extended = true;
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        for (final pc in const [false, true]) {
          await m.setPc(pc);
          for (final w in kHomeMatrixWidths) {
            await m.resize(
              Size(
                w.toDouble(),
                pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
              ),
            );
            for (final view in HomeView.values.skip(1)) {
              await m.cell(
                'tabs',
                view,
                captureEnd: kHomeMatrixBoundaryWidths.contains(w),
              );
            }
            await m.show(HomeView.projects);
            await m.drawerCell('tabs');
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/tabs'),
  knownProblems: homeMatrix2Known(const ['NEW-1']),
);
