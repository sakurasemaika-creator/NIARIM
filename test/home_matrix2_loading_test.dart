import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';

/// ホームの表示マトリクスの続き（3）：起動し直した直後、端末の中のファイルの
/// 一覧（書き出した作品・作成した共有ファイル・ゴミ箱のファイル）をまだ
/// 読んでいる間の全タブを、24幅×スマホ(844)/PC(900)×7言語の全セルで
/// 確かめる。
///
/// 作品・フォルダ・共有・ゴミ箱に中身を入れてからアプリを閉じ、同じ保存先で
/// 起動し直して、起動し終えた後の書類フォルダの問い合わせを止める（端末の
/// 読み込みが遅いとき）。プロジェクトと受け取った共有は起動で読み終えて
/// いるので一覧が出る。作品一覧は読み込み中の印。作成した共有ファイルと
/// ゴミ箱は、端末の中にあるのに「ありません」と言わず、一部だけを出すなら
/// まだ読んでいることが分かる（[HomeMatrixChecks.loadingCell]）。最後に
/// 問い合わせを通し、どのタブも全部の一覧に替わることを確かめる。各セルで
/// `home_matrix2_tabs_test.dart`と同じ続きの確かめも行い、画像と一覧を
/// `build/home-matrix2/loading`へ出す。
///
/// `home_display_matrix_test.dart`の読み込み中は、空のホームの作品一覧と
/// ゴミ箱を3幅で撮るだけ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  for (final language in kHomeMatrixLanguages) {
    testWidgets('restarted Home ($language): every tab while the file lists '
        'are still loading, at 24 widths x phone/PC', (tester) async {
      final m = HomeMatrix(tester, language, _run)..extended = true;
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        await m.restartApp(holdAfterStart: true);
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
              await m.loadingCell('loading', view);
            }
            await m.show(HomeView.projects);
          }
        }
        // 読み終われば、どのタブも全部の一覧になる。
        m.holdDocuments!.complete();
        m.holdDocuments = null;
        for (final (w, pc) in const [(390, false), (1280, true)]) {
          await m.setPc(pc);
          await m.resize(
            Size(
              w.toDouble(),
              pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
            ),
          );
          for (final view in HomeView.values) {
            await m.cell('loaded', view);
            // 読み終えたら、ゴミ箱の先頭の「読み込み中」の行は消える。
            if (view == HomeView.trash &&
                find
                    .byKey(const Key('trashFilesLoading'))
                    .evaluate()
                    .isNotEmpty) {
              m.failures.add(
                '${m.cellName('loaded', view.name)}: trash still shows the '
                'files-loading row after listing the files',
              );
            }
          }
          await m.show(HomeView.projects);
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/loading'),
  knownProblems: homeMatrix2Known(const ['NEW-1']),
);
