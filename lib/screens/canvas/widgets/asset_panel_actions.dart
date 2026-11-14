import 'package:flutter/material.dart';

import '../../../config/accent_text_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      (Icons.folder_outlined, l10n.creativePanelFolderButton, onFolder),
      (
        Icons.add_photo_alternate_outlined,
        l10n.creativePanelCreateButton,
        onCreate,
      ),
      (Icons.file_upload_outlined, l10n.creativePanelImportButton, onImport),
    ];
    const labelStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FirstThatFits(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (icon, name, onPressed) in actions)
                TextButton.icon(
                  icon: Icon(icon, size: 15),
                  label: Text(name, style: labelStyle),
                  onPressed: onPressed,
                ),
            ],
          ),
          // 最後の形：アイコンも1行に入らないほど狭い（ドックを縮めた等）
          // ときは次の行へ折り返す（はみ出さない）。
          Wrap(
            children: [
              for (final (icon, name, onPressed) in actions)
                IconButton(
                  icon: Icon(icon, size: 20),
                  color: AccentTextTheme.of(context),
                  tooltip: name,
                  onPressed: onPressed,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
