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
    'DISC215',
    '画面の下にジェスチャーの帯（34px）・3ボタンの帯（48px）がある縦の'
        'スマホ（390x844）で、プロジェクトの一覧を一番下まで送っても、右下の'
        '＋が最後の行の右のカードの名前の下の端に重なる（浮かぶボタンは帯の'
        '分だけ上がるが、一覧の末尾の余白は帯の分を足していない）。'
        'DISC181（一覧の途中で左下の名前が「↑」に隠れる）とは別。',
    RegExp(r'^text under a floating button: '),
    where: _bottomInsetOnly,
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
  HomeMatrixKnownProblem(
    'DISC217',
    '新しいフォルダの名前のダイアログの説明（projectListFolderHint、'
        'project_list_widget.dartの_folderNameDialog）が、韓国語で語の途中'
        'で折り返す（幅320で「정리하 / 는」）。ほかの韓国語の文が使う'
        '語結合子（messageText・KoreanWordsText）を通していない。',
    RegExp(r'^word split: "[가-힣]+" in .*\[AlertDialog\]$'),
  ),
  HomeMatrixKnownProblem(
    'DISC218',
    '共有の「受け取ったもの」で、絵の無い作品のカードの表紙は作品の用紙の色'
        '（Color(project.backgroundColor)）に、テーマのアイコンの色の'
        'movie_creation_outlinedを置く（home_screen.dartの'
        '_receivedShareProjectTileのcover）。組み込みのダークテーマでは'
        'アイコンが#F5F1F0、白い用紙の上で見えず（Lc 0）、カードが白い板に'
        'なる。プロジェクトのタブの同じ表紙（FramePreviewBackground、'
        'onSurfaceの38%）も同じ見た目だが、このマトリクスの確かめは用紙の'
        '見本（FramePreviewBackground）の上の印を飾りとして見ない。',
    RegExp(r'^unreadable: "\u{F1F3}" .*\[home-shared\]$', unicode: true),
  ),
  HomeMatrixKnownProblem(
    'DISC219',
    '作品一覧のカード（ExportedWorkCard）で、絵を出さない作品の表紙'
        '（exportedWorkThumbnailArea）は用紙側の色'
        '（colorScheme.surfaceContainerHighest：パネルの背景色を本文の'
        '文字色へ寄せた色）で塗るのに、種類の印（movie_outlined・'
        'movie_filter_outlined）はメニューの文字色で描く'
        '（exported_work_card.dartのthumbnail()とforeground）。メニューを'
        '暗く・メニューの文字を明るくした自作テーマ（customdark：#EDEFF2 on '
        '#E2E0D9、Lc -7.5）で印が見えない。DISC193（カードの中の文字が本文の'
        '文字色）とは向きが逆の組み合わせ。',
    RegExp(r'^unreadable: .*\[exportedWorkThumbnailArea\]$'),
  ),
];

bool _bottomInsetOnly(HomeMatrix m, String what) =>
    m.tester.view.padding.bottom > 0 &&
    m.tester.view.padding.left == 0 &&
    m.tester.view.padding.right == 0;

bool _sideInsets(HomeMatrix m, String what) =>
    m.tester.view.padding.left > 0 || m.tester.view.padding.right > 0;

/// [ids]の不具合（[kHomeMatrix2KnownProblems]の番号）。
List<HomeMatrixKnownProblem> homeMatrix2Known(List<String> ids) => [
  for (final id in ids) kHomeMatrix2KnownProblems.firstWhere((k) => k.id == id),
];
