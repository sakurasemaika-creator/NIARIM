import 'home_matrix_harness.dart';

/// ホームの表示マトリクスの続き（`home_matrix2_*_test.dart`）で見つかり、
/// まだ直していない不具合。番号・理由・問題の文に当てる式・出るセル。
///
/// 番号は監査の台帳（docs/work-audit/state/AUDIT_ROUTE.md）のDISC番号。
/// 新しく見つけたものは台帳に載せてから、その番号で足す。
///
/// 各テストファイルは、自分のセルで出るものだけを[homeMatrix2Known]で
/// 選んで見込む。見込んだのに一度も出なかったもの（直った・作りが
/// 変わった）は、そのファイルの最後に失敗になる。
final kHomeMatrix2KnownProblems = <HomeMatrixKnownProblem>[
  HomeMatrixKnownProblem(
    'DISC212',
    'カードの丸い操作（星・メニュー・フォルダのメニュー）の押せる大きさが'
        '40×40で、Androidの決まり（48×48）より小さい。'
        'CollectionActionFrame.extent = 40（lib/widgets/'
        'collection_action_controls.dart）。プロジェクト・作品一覧・共有の'
        'すべてのカードで、どの幅・言語・テーマ・文字の大きさでも同じ。',
    RegExp(r'^tap target 40x40 \(card\): '),
  ),
  HomeMatrixKnownProblem(
    'DISC216',
    '横向きのスマホ（844x390）で左にカメラの切り欠き（安全な領域の左47px）'
        '・右に3ボタンの帯（右48px）があるとき、上部バーと引き出しは避けるが、'
        'タブの本文（お気に入り・並び順・ゴミ箱の種類・カードの星・名前・'
        'メニュー・ゴミ箱の操作）と右下の浮かぶボタンが、切り欠きと帯の下に'
        '描かれる（本文が左右の安全な領域を見ていない）。',
    RegExp(r'(outside the safe area|under the display cutout)'),
    where: _sideInsets,
  ),
];

bool _sideInsets(HomeMatrix m, String what) =>
    m.tester.view.padding.left > 0 || m.tester.view.padding.right > 0;

/// [ids]の不具合（[kHomeMatrix2KnownProblems]の番号）。
List<HomeMatrixKnownProblem> homeMatrix2Known(List<String> ids) => [
  for (final id in ids) kHomeMatrix2KnownProblems.firstWhere((k) => k.id == id),
];
