import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// プロジェクトの保存先を読めなかったとき（`ProjectService.projectsLoadFailed`）
/// の知らせと「再試行」。保存先から読む一覧（ホームのプロジェクト・共有の
/// 受け取ったもの・ゴミ箱、設定の引き継ぎのプロジェクト）に出す（空の
/// 一覧だけだと、作品が消えたように見える）。
///
/// 「再試行」は読み直しの途中も押せるままにする（押しても同じ読み直しを
/// 待つだけ）。押せなくすると、キーボードのフォーカスが前にフォーカスの
/// あった部品（Tabで来る途中のゴミ箱のタブ等）へ移り、続けて押した
/// Enterでそれが動いた。
class ProjectsLoadFailureNotice extends StatefulWidget {
  const ProjectsLoadFailureNotice({
    super.key,
    required this.onRetry,
    this.screenFocus,
  });

  final Future<void> Function() onRetry;

  /// 読み直せて知らせが消えるとき、フォーカスが知らせの中にあれば
  /// ここ（画面のフォーカス。ホームでは画面のショートカットを受ける
  /// フォーカス）へ戻す。nullなら、その画面（ルート）のフォーカスの範囲へ
  /// 戻す（設定の引き継ぎ・単独で開いたゴミ箱と共有）。
  final FocusNode? screenFocus;

  @override
  State<ProjectsLoadFailureNotice> createState() =>
      _ProjectsLoadFailureNoticeState();
}

class _ProjectsLoadFailureNoticeState extends State<ProjectsLoadFailureNotice> {
  // フォーカスが知らせの中にあるかを見るだけのノード（自分ではフォーカスを
  // 取らず、Tabでも止まらない）。
  final _noticeFocus = FocusNode(debugLabel: 'ProjectsLoadFailureNotice');

  @override
  void deactivate() {
    // 知らせが消えると、Flutterはフォーカスを前にフォーカスのあった部品
    // （ゴミ箱のタブ等）へ移し、次のEnterでそのタブが開いた。中の部品が
    // 外れる前に（親から先に呼ばれる）画面のフォーカスへ戻す。戻す先を
    // 受け取っていない画面でも前の部品へは移さない（引き継ぎでは最後の
    // チェックが外れ、狭い画面では書き出しが始まった）。
    if (_noticeFocus.hasFocus) {
      final screen = widget.screenFocus;
      if (screen != null) {
        screen.requestFocus();
      } else {
        _noticeFocus.unfocus();
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _noticeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _noticeFocus,
      canRequestFocus: false,
      skipTraversal: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                Icon(Icons.folder_off_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                // 入りきらない幅（狭い画面・大きな文字・長い言語）では
                // 「再試行」を文の下へ回す（横に並べたままだとはみ出した）。
                Expanded(
                  child: OverflowBar(
                    spacing: 8,
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.start,
                    children: [
                      Text(l10n.homeProjectsLoadFailed),
                      TextButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.communityRetry),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
