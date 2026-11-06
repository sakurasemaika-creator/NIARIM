import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/asset_tags.dart';
import '../../../widgets/dispose_on_unmount.dart';

/// ブラシ・トーン・スタンプへ分類タグを付け外しするダイアログ。
///
/// 3つのパネルが同じものを使う。[currentTags]を初期値として編集し、
/// 保存時に正規化済みのタグ列を[onSave]へ渡す。
///
/// [suggestions]には、その素材種別で既に使われているタグを渡す
/// （`XxxService.allTags()`）。表記ゆれで似たタグが増えるのを防ぐため、
/// 入力欄の下にワンタップで足せるチップとして並べる。
Future<void> showAssetTagDialog(
  BuildContext context, {
  required String assetName,
  required List<String> currentTags,
  required List<String> suggestions,
  required ValueChanged<List<String>> onSave,
}) {
  final l10n = AppLocalizations.of(context)!;
  // 既存タグはカンマ区切りの1行として編集させる。チップの×で消すだけの
  // UIだと、打ち間違いの修正に一度消して打ち直す手間がかかるため。
  final controller = TextEditingController(text: currentTags.join(', '));

  return showDialog<void>(
    context: context,
    // ダイアログの閉じるトランジション中にcontrollerが破棄されると
    // 「used after being disposed」で落ちるため、破棄はStateへ委ねる。
    builder: (ctx) => DisposeOnUnmount(
      controller: controller,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entered = splitTagInput(controller.text);
          return AlertDialog(
            title: Text(
              l10n.creativePanelTagsLabel,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assetName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.creativePanelTagsHint,
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        for (final tag in suggestions)
                          FilterChip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: entered.any(
                              (t) => t.toLowerCase() == tag.toLowerCase(),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (selected) {
                              final next = [...entered];
                              if (selected) {
                                next.add(tag);
                              } else {
                                next.removeWhere(
                                  (t) => t.toLowerCase() == tag.toLowerCase(),
                                );
                              }
                              final text = normalizeTags(next).join(', ');
                              controller.text = text;
                              controller.selection = TextSelection.collapsed(
                                offset: text.length,
                              );
                              setDialogState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  onSave(splitTagInput(controller.text));
                  Navigator.pop(ctx);
                },
                child: Text(l10n.commonSave),
              ),
            ],
          );
        },
      ),
    ),
  );
}
