import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/name_collation.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../widgets/typing_dialog_inset.dart';

/// [typed]が確かめの言葉[word]か。前後の空白・大文字と小文字・全角と半角の
/// 違いは問わない（日本語の入力のまま打った「ＤＥＬＥＴＥ」も通す）。
bool eraseConfirmWordMatches(String typed, String word) =>
    foldName(typed).trim() == foldName(word).trim();

/// 文の中の、括弧でくくった空白の無い語（「（初期化）」「(reset)」）。行の
/// 途中で切らずに1つのかたまりにする（「全データを削除（初 / 期化）」と括弧の
/// 中で折れた）。1行に入らない幅では[KeepTogetherText]がつながずに普通に
/// 折る。空白を含む括弧の中（「(remise à zéro)」）はかたまりにしない（語の
/// 間で折れる方が読める）。
List<String> bracketedWords(String text) => [
  for (final match in RegExp(r'[（(][^（）()\s]+[）)]').allMatches(text))
    match.group(0)!,
];

/// 「全データを削除」の確かめ。消えるもの・残るものを並べ、決めた言葉を
/// 打つまで削除のボタンを押せない（押し間違い・読み飛ばしで入れたばかりの
/// 状態へ戻さない）。言葉が合っていればEnterでも削除できる。`true`で
/// 閉じたら削除する。
class EraseAllDataDialog extends StatefulWidget {
  const EraseAllDataDialog({super.key});

  /// 削除のボタン（`FilledButton`）のキー。
  static const confirmKey = Key('storageEraseAllConfirm');

  /// 確かめの言葉を打つ欄のキー。
  static const wordFieldKey = Key('storageEraseAllWord');

  @override
  State<EraseAllDataDialog> createState() => _EraseAllDataDialogState();
}

class _EraseAllDataDialogState extends State<EraseAllDataDialog> {
  // ダイアログ自身が持ち、ツリーから外れるとき（閉じ終えた後）に破棄する。
  final _controller = TextEditingController();
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(AppLocalizations l10n) => eraseConfirmWordMatches(
    _controller.text,
    l10n.storageEraseAllConfirmWord,
  );

  void _confirm() {
    if (_closing || !_matches(AppLocalizations.of(context)!)) return;
    _closing = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // 欄の周りの空き：低い窓（横向き・分割）では上下を詰める。キーボードの
    // 間は上下の空きを取らない。
    final compact = MediaQuery.sizeOf(context).height < 320;
    final inset = typingDialogInsetPadding(
      context,
      usual: compact
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
          : null,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        // 欄の隣のボタンや空いた所を押しても欄のフォーカスを外さない
        // （続けて打てるように）。
        child: TextFieldTapRegion(child: _buildAlert(context, inset, compact)),
      ),
    );
  }

  Widget _buildAlert(BuildContext context, EdgeInsets? inset, bool compact) {
    final l10n = AppLocalizations.of(context)!;
    final matches = _matches(l10n);
    final word = l10n.storageEraseAllConfirmWord;
    return AlertDialog(
      insetPadding: inset,
      constraints: const BoxConstraints(maxWidth: 560),
      // 文・欄・ボタンを1つのスクロールに入れる（低い窓・大きな文字・
      // キーボードでも、読んでから打って押せる）。
      scrollable: true,
      titlePadding: compact ? const EdgeInsets.fromLTRB(16, 12, 16, 0) : null,
      contentPadding: compact ? const EdgeInsets.fromLTRB(16, 8, 16, 12) : null,
      title: Text(l10n.storageEraseAllConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          messageText(l10n.storageEraseAllConfirmBody, keepLineStarts: true),
          const SizedBox(height: 16),
          _ItemList(
            title: l10n.storageEraseAllErasedTitle,
            items: l10n.storageEraseAllErasedItems.split('\n'),
          ),
          const SizedBox(height: 12),
          _ItemList(
            title: l10n.storageEraseAllKeptTitle,
            items: l10n.storageEraseAllKeptItems.split('\n'),
          ),
          const SizedBox(height: 20),
          messageText(
            l10n.storageEraseAllConfirmPrompt(word),
            keepLineStarts: true,
            keep: [word],
          ),
          const SizedBox(height: 8),
          TextField(
            key: EraseAllDataDialog.wordFieldKey,
            controller: _controller,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            // 合っていないままEnterを押しても欄から抜けず、続けて打てる。
            onEditingComplete: () {},
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              hintText: word,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    l10n.commonCancel,
                    style: TextStyle(shadows: cancelLabelShadows(context)),
                  ),
                ),
                // 主な操作の塗り（エラーの色にしない）。言葉が合うまでは
                // 押せない。
                FilledButton(
                  key: EraseAllDataDialog.confirmKey,
                  style: FilledButton.styleFrom(
                    padding: eraseAllButtonPadding(context),
                    // 文字が折れたときの上下の空きは上の余白で取る。
                    foregroundBuilder: (context, states, child) =>
                        child ?? const SizedBox.shrink(),
                  ),
                  onPressed: matches ? _confirm : null,
                  child: KeepTogetherText(
                    l10n.storageEraseAllButton,
                    keep: bracketedWords(l10n.storageEraseAllButton),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 見出しと、点で始まる項目の並び（消えるもの・残るもの）。
class _ItemList extends StatelessWidget {
  const _ItemList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = DefaultTextStyle.of(context).style;
    final dotColor = theme.colorScheme.onSurfaceVariant;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(body.fontSize ?? 14) *
        (body.height ?? 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: localizedHeadingStyle(
              context,
              TextStyle(fontSize: 14, height: 1.4, color: body.color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 点は1行目の真ん中に置く（文が何行になっても動かない）。
                SizedBox(
                  width: 16,
                  height: math.max(lineHeight, 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 5),
                    ),
                  ),
                ),
                Expanded(child: messageText(item, keepLineStarts: true)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 「全データを削除」の確かめのボタンの余白。文字が大きく名前が2行以上に
/// 折れたとき、上下に余白が無いと文字がボタンの縁に付いて見えた（既定の
/// 上下の余白は0）。ボタンは表示の詰め方（VisualDensity）の分だけ上下の
/// 余白を減らす（PC〔Linux 等〕の詰めた表示は8pxずつで、文字2倍では字と
/// 縁の間が2〜4pxになった）ので、減らされる分を足しておく。高さの低い
/// 画面（横向き・分割の窓）では、警告と操作欄を続けて読めるように、上下の
/// 余白を足さない。左右は既定と同じく文字の大きさで縮める。
EdgeInsetsGeometry eraseAllButtonPadding(BuildContext context) {
  final squeezed = math.max(
    0.0,
    -Theme.of(context).visualDensity.baseSizeAdjustment.dy,
  );
  final vertical = MediaQuery.sizeOf(context).height >= 480
      ? 10 + squeezed
      : 0.0;
  return ButtonStyleButton.scaledPadding(
    EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
    EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
    EdgeInsets.symmetric(horizontal: 6, vertical: vertical),
    MediaQuery.textScalerOf(context).scale(14) / 14,
  );
}
