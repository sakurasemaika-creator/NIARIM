import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'keep_together_text.dart';

/// ゴミ箱アイコンタップ時に一発で削除せず、確認ダイアログを挟む共通ヘルパー
/// （アプリ全体で誤操作による削除を防止する）。[itemName]を
/// 指定すると確認文に対象名を含める。trueが返れば削除確定・falseまたは
/// nullなら取り消し。
Future<bool> confirmDelete(BuildContext context, {String? itemName}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.commonDelete),
      // 韓国語の語・数と単位は、1行に入れば途中で折らない。
      content: messageText(
        itemName == null
            ? l10n.confirmDeleteGenericBody
            : l10n.confirmDeleteNamedBody(itemName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return result ?? false;
}
