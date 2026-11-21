import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/theme_service.dart';
import 'keep_together_text.dart';
import 'typing_dialog_inset.dart';

/// 起動画面と「テーマ・外観」設定で共通利用する復旧ボタン。
/// 通常UIと違い、復旧経路だけ黒・白の固定色を使う。
/// テーマの変更は確認ダイアログ内のリセット確定時だけ行う。
class ThemeRescueButton extends StatelessWidget {
  const ThemeRescueButton({super.key, this.iconOnly = false});

  /// 設定画面の狭いAppBarではアイコンだけにして操作領域を確保する。
  /// その場合もスクリーンリーダー用のラベルと確認動作は変えない。
  final bool iconOnly;

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ThemeService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: ThemeService.rescueThemeDataFor(
          Localizations.localeOf(dialogContext),
        ),
        child: AlertDialog(
          // 救済のテーマで包むと、画面の印がテーマに入れる狭い画面の空き
          // （NarrowDialogInset）が隠れ、320pxの画面では最小の幅より狭い
          // 240pxになっていた。空きは色を持たないので、ここで直に渡す
          // （360px以上は null＝今までどおり）。
          insetPadding: dialogInsetPadding(dialogContext),
          // 題の韓国語の語は、1行に入れば途中で折らない（普通のTextでは
          // 「초기화하시겠습니 / 까?」と折れた）。
          title: messageText(l10n.themeResetConfirmTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.themeResetConfirmAction),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await service.resetToDefault();
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.themeUnreadableResetDone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: Color(0xFF000000), width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: Color(0xFFFFFFFF), width: 2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            child: Semantics(
              button: true,
              label: l10n.themeUnreadableResetButton,
              child: InkWell(
                customBorder: const StadiumBorder(),
                splashColor: const Color(0x33000000),
                highlightColor: const Color(0x33FFFFFF),
                onTap: () => _confirmReset(context),
                child: ConstrainedBox(
                  // The icon and label are visually compact, but the actual
                  // interactive area must still meet the 48dp touch target.
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            height: 26,
                            width: 29,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 2,
                                  child: Icon(
                                    Icons.palette_outlined,
                                    size: 24,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                                Positioned(
                                  left: 2,
                                  top: 4,
                                  child: Icon(
                                    Icons.palette_outlined,
                                    size: 20,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Icon(
                                    Icons.restart_alt,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                                Positioned(
                                  right: 1,
                                  top: 1,
                                  child: Icon(
                                    Icons.restart_alt,
                                    size: 12,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!iconOnly) ...[
                            const SizedBox(width: 4),
                            Stack(
                              children: [
                                Text(
                                  l10n.themeUnreadableResetButton,
                                  style: TextStyle(
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 3.5
                                      ..strokeJoin = StrokeJoin.round
                                      ..color = const Color(0xFFFFFFFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  l10n.themeUnreadableResetButton,
                                  style: const TextStyle(
                                    color: Color(0xFF000000),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
