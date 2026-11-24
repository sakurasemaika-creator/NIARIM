import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/first_that_fits.dart';

/// ブラシ・トーン・スタンプのパネルの「フォルダ・新規・読込」の行。
///
/// 3つの名前が入る幅では名前つきのボタン、入らない幅ではアイコンだけの
/// ボタン（名前は長押し・ホバーの吹き出しと読み上げ）にする。文字は縮めず、
/// 行を横にスクロールさせてパネルの端で切ることもしない（所有者の判断3）。
/// どちらにするかは測った幅で決める（[FirstThatFits]）。アイコンも1行に
/// 入らない幅では、アイコンを次の行へ折り返す。
class AssetPanelActions extends StatelessWidget {
  const AssetPanelActions({
    super.key,
    required this.onFolder,
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onFolder;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  /// フォルダ・新規・読込の3つ（印・名前・押したとき）。
  static List<AssetPanelAction> list(
    AppLocalizations l10n, {
    required VoidCallback onFolder,
    required VoidCallback onCreate,
    required VoidCallback onImport,
  }) => [
    (
      icon: Icons.folder_outlined,
      name: l10n.creativePanelFolderButton,
      onPressed: onFolder,
    ),
    (
      icon: Icons.add_photo_alternate_outlined,
      name: l10n.creativePanelCreateButton,
      onPressed: onCreate,
    ),
    (
      icon: Icons.file_upload_outlined,
      name: l10n.creativePanelImportButton,
      onPressed: onImport,
    ),
  ];

  /// 名前つきのボタンの並び（文字は縮めない）。
  static Widget labelled(BuildContext context, List<AssetPanelAction> actions) {
    final labelStyle = localizedHeadingStyle(
      context,
      const TextStyle(fontSize: 11),
    );
    final ink = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: ink),
            icon: Icon(action.icon, size: 15),
            label: Text(action.name, style: labelStyle),
            onPressed: action.onPressed,
          ),
      ],
    );
  }

  /// アイコンだけのボタン（名前は長押し・ホバーの吹き出しと読み上げ）。
  /// [wrap]では入らない幅で次の行へ折り返す。
  static Widget iconOnly(
    BuildContext context,
    List<AssetPanelAction> actions, {
    bool wrap = false,
  }) {
    final ink = Theme.of(context).colorScheme.onSurfaceVariant;
    final buttons = [
      for (final action in actions)
        IconButton(
          icon: Icon(action.icon, size: 20),
          color: ink,
          tooltip: action.name,
          onPressed: action.onPressed,
        ),
    ];
    return wrap
        ? Wrap(children: buttons)
        : Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  @override
  Widget build(BuildContext context) {
    final actions = list(
      AppLocalizations.of(context)!,
      onFolder: onFolder,
      onCreate: onCreate,
      onImport: onImport,
    );
    // 管理の操作（よく使うのは一覧から選ぶこと）なので、差し色ではなく
    // 中立の色で描く。
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FirstThatFits(
        children: [
          labelled(context, actions),
          // 最後の形：アイコンも1行に入らないほど狭い（ドックを縮めた等）
          // ときは次の行へ折り返す（はみ出さない）。
          iconOnly(context, actions, wrap: true),
        ],
      ),
    );
  }
}

/// ブラシ・トーン・スタンプのパネルの管理の操作（フォルダ・新規・読込）。
typedef AssetPanelAction = ({
  IconData icon,
  String name,
  VoidCallback onPressed,
});
