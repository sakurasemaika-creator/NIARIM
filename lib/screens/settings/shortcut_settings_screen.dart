import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/brush.dart';
import '../../models/shortcut_binding.dart';
import '../../services/brush_service.dart';
import '../../services/shortcut_service.dart';
import '../../utils/line_break.dart' show containsHangul;
import '../../widgets/action_beside_or_below.dart' show widestUnbreakableWidth;
import '../../widgets/confirm_delete.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/help_button.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/responsive.dart';
import '../../widgets/stepped_slider.dart';
import '../../config/font_fallback.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/fit_or_hide_title.dart';

/// キーボード・左手デバイス用ショートカットの設定画面。
/// ツール選択（早替えツールと同じ粒度：ツール＋ブラシ＋太さ）と、
/// Undo/Redoなどの主要操作の両方を、キー＋修飾キーの組み合わせへ
/// 割り当てる。キャンバス・タイムライン両モードで共通の設定。
/// 主要操作コマンドの表示名（表示言語に追従する）。
///
/// 既定のショートカット（Undo/Redo/全選択/コピー/切り取り/貼り付け）は、
/// 初回起動時に英語のラベル（'Undo'等）を保存してしまうため、そのまま
/// 表示すると**日本語UIの中に英語だけが並ぶ**
/// （`build/all-route-screenshots/21_settings_shortcuts.png`で発覚）。
/// 一覧では、操作の割り当て（既定のものも利用者が足したものも）はこの表の
/// 名前で表示する（[shortcutDisplayLabel]）。
Map<ShortcutCommand, String> shortcutCommandLabels(AppLocalizations l10n) => {
  ShortcutCommand.undo: l10n.shortcutCommandUndo,
  ShortcutCommand.redo: l10n.shortcutCommandRedo,
  ShortcutCommand.toggleLayerPanel: l10n.shortcutCommandToggleLayerPanel,
  ShortcutCommand.playPause: l10n.shortcutCommandPlayPause,
  ShortcutCommand.previousFrame: l10n.shortcutCommandPreviousFrame,
  ShortcutCommand.nextFrame: l10n.shortcutCommandNextFrame,
  ShortcutCommand.selectAll: l10n.shortcutCommandSelectAll,
  ShortcutCommand.copy: l10n.shortcutCommandCopy,
  ShortcutCommand.cut: l10n.shortcutCommandCut,
  ShortcutCommand.paste: l10n.shortcutCommandPaste,
};

/// 一覧・確認・引き継ぎの知らせに出すショートカット名。
///
/// 操作（取り消し・コマ送り等）と、消しゴム・スポイト・バケツの割り当ては、
/// 保存した名前（[ShortcutBinding.label]）ではなく、操作・ツールの種類から
/// 表示のたびに今の言語で作る。保存した名前は足したときの言語の文
/// （既定のものは英語の「Undo」、利用者が足したものはそのときの表示言語の
/// 「后退1帧（时间轴）」等）なので、そのまま出すと、言語を切り替えても足した
/// ときの言語のまま残った。前の版で保存した割り当ても、保存した種類から
/// 読み直す。保存の形（`label`）は前の版が読めるよう今までどおり残す。
///
/// ブラシの割り当ての名前は、[brushes]の中のそのブラシの今の名前（利用者の
/// データなので訳さない）と決めた太さで作る（足したときのブラシの名前を
/// 保存したまま出すと、ブラシの名前を変えても古い名前のままだった）。
/// ブラシが無くなっていれば（[brushes]を渡さなければ）保存した名前。
String shortcutDisplayLabel(
  AppLocalizations l10n,
  ShortcutBinding binding, {
  Iterable<Brush> brushes = const [],
}) {
  final command = binding.command;
  if (command != null) {
    return shortcutCommandLabels(l10n)[command] ?? binding.label;
  }
  switch (binding.toolKey) {
    case 'eraser':
      return l10n.quickToolEraser;
    case 'eyedropper':
      return l10n.quickToolEyedropper;
    case 'bucket':
      return l10n.quickToolBucket;
    case 'pen':
      final brush = brushes.where((b) => b.id == binding.brushId).firstOrNull;
      if (brush == null) return binding.label;
      final size = binding.sizeOverride;
      return size == null ? brush.name : '${brush.name} ${size.round()}px';
  }
  return binding.label;
}

class ShortcutSettingsScreen extends StatelessWidget {
  const ShortcutSettingsScreen({super.key});

  /// 一覧の下端に取る、浮かぶボタンの分の余白（ボタン56・ボタンの下の
  /// 余白16・ボタンとの間16。ホームの一覧・空の表示と同じ）。
  static const double _floatingButtonClearance = 88;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<ShortcutService>();
    final bindings = service.bindings;
    // ブラシの名前を変えたら、ブラシの割り当ての名前も変わる（ブラシの一覧が
    // 無ければ保存した名前）。
    final brushes = context.watch<BrushService?>()?.brushes ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.shortcutSettingsTitle),
        actions: const [HelpButton(topic: 'ショートカット設定')],
      ),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              // 韓国語の語は、1行に入れば途中で折らない（「도 / 구」と折れた）。
              child: messageText(
                l10n.shortcutSettingsHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: bindings.isEmpty
                  ? Center(
                      child: Text(
                        l10n.shortcutEmpty,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      // 一覧の下端に「追加」の浮かぶボタンの分の余白を取る
                      // （取らないと、最後までスクロールしても最後の行の削除の
                      // ボタンが浮かぶボタンの下に入ったまま押せなかった）。
                      // 画面の下の帯（ジェスチャーの帯）の分は、一覧を包む
                      // SafeArea（desktopCentered）が一覧の外に取る。
                      padding: const EdgeInsets.only(
                        bottom: _floatingButtonClearance,
                      ),
                      itemCount: bindings.length,
                      itemBuilder: (context, index) {
                        final b = bindings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          // キーのチップが1行で項目名の前に入らない幅（大きな
                          // 文字・字の広い言語）では、項目名の上に置く（「…」で
                          // 切らない）。チップが入っても、残りの名前の欄に名前の
                          // いちばん広い語が入らないときも上に置く（英語320px・
                          // 文字2倍で「Re / do」と語の途中で折れた）。
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final chip = _KeyChip(b.comboLabel);
                              final label = shortcutDisplayLabel(
                                l10n,
                                b,
                                brushes: brushes,
                              );
                              // 韓国語の語は、1行に入れば途中で折らない。
                              final name = messageText(
                                label,
                                style: _nameStyle,
                              );
                              final chipWidth = _KeyChip.widthOf(
                                context,
                                b.comboLabel,
                              );
                              final beside =
                                  chipWidth <=
                                      math.max(120, box.maxWidth * 0.4) &&
                                  _widestWordOf(context, name, label) <=
                                      _nameWidthBeside(
                                        context,
                                        box.maxWidth,
                                        chipWidth,
                                      );
                              return ListTile(
                                leading: beside ? chip : null,
                                title: beside
                                    ? name
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          chip,
                                          const SizedBox(height: 6),
                                          name,
                                        ],
                                      ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.commonDelete,
                                  onPressed: () async {
                                    if (!await confirmDelete(
                                      context,
                                      itemName: label,
                                    )) {
                                      return;
                                    }
                                    service.removeBinding(b.id);
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startAddFlow(context, service),
        icon: const Icon(Icons.add),
        label: Text(l10n.commonAdd),
        // テーマ側のFAB共通形状（CircleBorder）を、拡張FAB本来の横長
        // カプセル形状（StadiumBorder）へ上書きする（community_screen.dart
        // の投稿ボタンと同じ理由）。
        shape: const StadiumBorder(),
      ),
    );
  }

  /// 一覧の行の名前の書式（行の題の書式に重ねる）。
  static const _nameStyle = TextStyle(
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  /// 一覧の行の名前[name]（文は[label]）の、折り返せないいちばん広い語の幅
  /// （行の題の書式で）。
  static double _widestWordOf(BuildContext context, Widget name, String label) {
    final style =
        (ListTileTheme.of(context).titleTextStyle ??
                Theme.of(context).textTheme.titleMedium ??
                const TextStyle())
            .merge(_nameStyle);
    final painter = TextPainter(
      text: name is KeepTogetherText
          ? name.joinedSpan(style)
          : TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final widest = widestUnbreakableWidth(
      painter,
      reported: painter.minIntrinsicWidth,
    );
    painter.dispose();
    return widest;
  }

  /// 幅[rowWidth]の行で、キーのチップ（幅[chipWidth]）を名前の前に置いたときの
  /// 名前の欄の幅（ListTileの並べ方：左右の余白、先頭のチップと間、削除の
  /// ボタンと間を除いた幅）。
  static double _nameWidthBeside(
    BuildContext context,
    double rowWidth,
    double chipWidth,
  ) {
    final tileTheme = ListTileTheme.of(context);
    final padding =
        (tileTheme.contentPadding ??
                const EdgeInsetsDirectional.only(start: 16, end: 24))
            .resolve(Directionality.of(context));
    final gap = tileTheme.horizontalTitleGap ?? 16;
    final leading = math.max(tileTheme.minLeadingWidth ?? 24, chipWidth);
    // 削除のボタン（押せる大きさの最小、48）。
    const deleteButton = kMinInteractiveDimension;
    return rowWidth -
        padding.horizontal -
        leading -
        gap -
        math.max(deleteButton + gap, 32);
  }

  /// 足すシートの題（キーの組[combo]を埋めた文。[_sentenceWithCombo]）。
  static Widget _chooseActionTitle(AppLocalizations l10n, String combo) =>
      _sentenceWithCombo(
        l10n.shortcutChooseActionTitle,
        combo,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      );

  /// キーの組[combo]を埋めた文（[sentence]で作る。足すシートの題・すでに
  /// 割り当てられているときの確かめの本文）。
  ///
  /// キーの組は、一覧のチップと同じく修飾キーの「+」の後だけで折り返す
  /// （普通の文のままだと「要为Ctrl+Shift+Alt+ / +分配什么？」とキーの「+」が
  /// 行の頭に来て、「Ctrl+S / hift」「Arrow / Left」と修飾キー・キーの名前の
  /// 途中でも折れた）。韓国語の語は、1行に入れば途中で折らない（「무 /
  /// 엇을」「할당하시겠습 / 니까?」と折れた）。キーの組の後に続く助詞
  /// （「Arrow Left에」の「에」）はキーの名前から離さない。読み上げは元の文。
  static Widget _sentenceWithCombo(
    String Function(String combo) sentence,
    String combo, {
    TextStyle? style,
  }) {
    final shownCombo = _KeyChip._breakable(combo);
    final shown = sentence(shownCombo);
    final semantics = sentence(combo);
    // キーの組と重なる語は、ここで決めたキーの名前と助詞だけをつなぐ（組の
    // 中の修飾キーの「+」の後では折り返せるままにする）。
    final keep = [
      ...koreanWordParts(shown, except: [shownCombo]),
    ];
    final at = shown.indexOf(shownCombo);
    if (at >= 0) {
      final end = at + shownCombo.length;
      var tail = end;
      while (tail < shown.length && shown[tail].trim().isNotEmpty) {
        tail++;
      }
      if (containsHangul(shown.substring(end, tail))) {
        keep.add(
          shown.substring(at + shownCombo.lastIndexOf('\u200b') + 1, tail),
        );
      }
    }
    if (keep.isEmpty) {
      return Text(shown, semanticsLabel: semantics, style: style);
    }
    return KeepTogetherText(
      shown,
      keep: keep,
      semanticsLabel: semantics,
      style: style,
    );
  }

  Future<void> _startAddFlow(
    BuildContext context,
    ShortcutService service,
  ) async {
    final captured = await _showKeyCaptureDialog(context);
    if (captured == null || !context.mounted) return;
    await _showActionPicker(context, service, captured);
  }

  /// 「キーを押してください」ダイアログ：次に押されたキー＋その時点の
  /// 修飾キー状態を記録して返す。
  Future<_CapturedKey?> _showKeyCaptureDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_CapturedKey>(
      context: context,
      builder: (ctx) => _KeyCaptureDialog(l10n: l10n),
    );
  }

  Future<void> _showActionPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final brushService = context.read<BrushService>();
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              // 題の中のキーの組は修飾キーの「+」の後だけで折り返し、韓国語の
              // 語は途中で折らない（[_chooseActionTitle]）。
              child: _chooseActionTitle(l10n, captured.comboLabel),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(
                l10n.shortcutActionTypeTool,
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showToolPicker(context, service, captured, brushService);
              },
            ),
            ListTile(
              title: Text(
                l10n.shortcutActionTypeCommand,
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showCommandPicker(context, service, captured);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToolPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    BrushService brushService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final brush in brushService.brushes)
              ListTile(
                leading: const Icon(Icons.brush),
                // 韓国語の語・数と単位は、1行に入れば途中で折らない（以下の
                // 行・ダイアログも同じ）。
                title: messageText(brush.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSizeDialog(
                    context,
                    service,
                    captured,
                    brush.id,
                    brush.name,
                    brush.size,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: messageText(l10n.quickToolEraser),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'eraser',
                label: l10n.quickToolEraser,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: messageText(l10n.quickToolEyedropper),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'eyedropper',
                label: l10n.quickToolEyedropper,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: messageText(l10n.quickToolBucket),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'bucket',
                label: l10n.quickToolBucket,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeDialog(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    String brushId,
    String brushName,
    double defaultSize,
  ) {
    double size = defaultSize;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: messageText(l10n.quickToolSizeDialogTitle(brushName)),
          // 項目名はダイアログのタイトルが兼ねるので、値だけを上の行の
          // 右端へ置き、スライダーは下の行で横幅いっぱいを使う。
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                // 鉛筆マークが値の右へはみ出して描かれるぶん空ける。
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: EditableSliderValue(
                    text: '${size.round()}px',
                    textAlign: TextAlign.right,
                    value: size,
                    min: 1,
                    max: 200,
                    onChanged: (v) => setS(() => size = v.toDouble()),
                  ),
                ),
              ),
              SteppedSlider(
                value: size.clamp(1, 200),
                min: 1,
                max: 200,
                compact: true,
                label: '${size.round()}px',
                onChanged: (v) => setS(() => size = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveToolBinding(
                  context,
                  service,
                  captured,
                  toolKey: 'pen',
                  brushId: brushId,
                  sizeOverride: size,
                  label: '$brushName ${size.round()}px',
                );
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommandPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final commands = shortcutCommandLabels(l10n);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in commands.entries)
              ListTile(
                title: messageText(entry.value),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveCommandBinding(
                    context,
                    service,
                    captured,
                    entry.key,
                    entry.value,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _saveToolBinding(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured, {
    required String toolKey,
    String? brushId,
    double? sizeOverride,
    required String label,
  }) {
    final binding = ShortcutBinding(
      id: 'sc_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      keyId: captured.key.keyId,
      control: captured.control,
      shift: captured.shift,
      alt: captured.alt,
      meta: captured.meta,
      toolKey: toolKey,
      brushId: brushId,
      sizeOverride: sizeOverride,
    );
    _confirmAndSave(context, service, binding);
  }

  void _saveCommandBinding(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    ShortcutCommand command,
    String label,
  ) {
    final binding = ShortcutBinding(
      id: 'sc_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      keyId: captured.key.keyId,
      control: captured.control,
      shift: captured.shift,
      alt: captured.alt,
      meta: captured.meta,
      command: command,
    );
    _confirmAndSave(context, service, binding);
  }

  Future<void> _confirmAndSave(
    BuildContext context,
    ShortcutService service,
    ShortcutBinding binding,
  ) async {
    final conflict = service.findConflict(binding);
    if (conflict != null) {
      final l10n = AppLocalizations.of(context)!;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: messageText(l10n.shortcutConflictTitle),
          // キーの組は修飾キーの「+」の後だけで折り、韓国語の語は途中で
          // 折らない（[_sentenceWithCombo]）。
          content: _sentenceWithCombo(
            (combo) => l10n.shortcutConflictBody(
              combo,
              shortcutDisplayLabel(
                l10n,
                conflict,
                brushes: context.read<BrushService?>()?.brushes ?? const [],
              ),
            ),
            binding.comboLabel,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.shortcutConflictOverwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
      service.removeBinding(conflict.id);
    }
    service.addBinding(binding);
  }
}

class _CapturedKey {
  final LogicalKeyboardKey key;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  const _CapturedKey({
    required this.key,
    required this.control,
    required this.shift,
    required this.alt,
    required this.meta,
  });

  String get comboLabel {
    final parts = <String>[
      if (control) 'Ctrl',
      if (shift) 'Shift',
      if (alt) 'Alt',
      if (meta) 'Meta',
      key.keyLabel,
    ];
    return parts.join('+');
  }
}

/// 「キーを押してください」ダイアログ本体。フォーカスを持つ間に押された
/// 最初のキーイベントを記録して閉じる（修飾キー単体は無視し、次に押された
/// 実キーとその時点の修飾キー状態を組み合わせて確定する）。
class _KeyCaptureDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _KeyCaptureDialog({required this.l10n});

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  static final _modifierKeys = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (_modifierKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    Navigator.pop(
      context,
      _CapturedKey(
        key: event.logicalKey,
        control:
            keys.contains(LogicalKeyboardKey.controlLeft) ||
            keys.contains(LogicalKeyboardKey.controlRight),
        shift:
            keys.contains(LogicalKeyboardKey.shiftLeft) ||
            keys.contains(LogicalKeyboardKey.shiftRight),
        alt:
            keys.contains(LogicalKeyboardKey.altLeft) ||
            keys.contains(LogicalKeyboardKey.altRight),
        meta:
            keys.contains(LogicalKeyboardKey.metaLeft) ||
            keys.contains(LogicalKeyboardKey.metaRight),
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      // 韓国語の語は、1行に入れば途中で折らない（説明の「함 / 께」
      // 「있습니 / 다）」「눌러주세 / 요」と折れた）。
      title: messageText(l10n.shortcutCaptureTitle),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, size: 40),
              const SizedBox(height: 12),
              messageText(
                l10n.shortcutCaptureHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

/// ショートカットのキー組み合わせ（例：Ctrl+Shift+Z）を表示する小さな
/// チップ。一覧の行では項目名の前（ListTileのleading）に置き、1行で入らない
/// ときは項目名の上に置く（[widthOf]で決める）。以前はleadingの中で幅120pxに
/// 抑えて1行で「…」と切っていて、字の広い中国語の本文の書体・大きな文字で
/// 「Ctrl+S…」になっていた。項目名の上でも入らない幅では「+」の後で次の行へ
/// 折り返す（キーの名前の途中では折らない）。
class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label);

  final String label;

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  /// チップの文の書式。leadingの既定（labelSmall・onSurfaceVariant）に太さと
  /// 大きさを足したもの。項目名の上に置いても同じに描く。
  static TextStyle _style(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        theme.listTileTheme.leadingAndTrailingTextStyle ??
        theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle();
    return base.copyWith(fontSize: 12, fontWeight: FontWeight.bold);
  }

  /// [label]のチップを1行で描いたときの幅。
  static double widthOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + _padding.horizontal;
    painter.dispose();
    return width;
  }

  /// キー組み合わせの文[label]（[ShortcutBinding.comboLabel]：修飾キーを
  /// Ctrl・Shift・Alt・Metaの順に「+」でつなぎ、最後にキーの名前）を、修飾
  /// キーの後の「+」の後ろだけで折り返せるようにした文。キーの名前の中
  /// （「Arrow Left」の空白）では折り返さない。キーが「+」のときは、その前
  /// （最後の修飾キーの「+」の後）でも折り返さない（「Ctrl+」の次の行に「+」
  /// だけが来ると、キーかつなぎの「+」か見分けられない）。
  static String _breakable(String label) {
    var rest = label;
    final modifiers = <String>[];
    for (final modifier in const ['Ctrl', 'Shift', 'Alt', 'Meta']) {
      if (!rest.startsWith('$modifier+')) continue;
      modifiers.add(modifier);
      rest = rest.substring(modifier.length + 1);
    }
    final out = StringBuffer();
    for (var i = 0; i < modifiers.length; i++) {
      final keepWithKey = i == modifiers.length - 1 && rest.startsWith('+');
      // 幅の無い空白（U+200B）：ここで折り返せる。語結合子（U+2060）：
      // 折り返さない。
      out
        ..write('${modifiers[i]}+')
        ..write(keepWithKey ? '\u2060' : '\u200b');
    }
    // キーの名前の空白は改行しない空白（U+00A0）にし、そこでは折り返さない。
    out.write(rest.replaceAll(' ', '\u00A0'));
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      // 修飾キーの後の「+」の後だけで折り返す（読み上げは元の文）。
      child: Text(
        _breakable(label),
        semanticsLabel: label,
        style: _style(context),
      ),
    );
  }
}
