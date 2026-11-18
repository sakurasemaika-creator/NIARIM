import 'dart:math' as math;

import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/brush.dart';
import '../../../models/quick_tool_entry.dart';
import '../../../services/brush_service.dart';
import '../../../services/quick_tool_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/stepped_slider.dart';
import '../canvas_screen.dart' show DrawingTool;
import '../../../widgets/docked_panel_scope.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/reorder_index.dart';
import '../../../widgets/scrollable_sheet_body.dart';

/// 早替えツールの一覧に出す名前。
///
/// 保存した名前（[QuickToolEntry.label]）ではなく、ツールの種類から表示の
/// たびに今の言語で作る。保存した名前は足したときの言語の文（最初からある
/// ものは日本語の「消しゴム」「Gペン 細」）なので、そのまま出すと、言語を
/// 切り替えても足したときの言語のまま残った。
///
/// - 消しゴム・スポイト・バケツは、今の言語のツールの名前。
/// - ブラシのツールは、[brushes]の中のそのブラシの今の名前（利用者のデータ
///   なので訳さない。名前を変えれば新しい名前）と、決めた太さ。ブラシが
///   無くなっていれば保存した名前。
///
/// 保存の形（`label`）は、前の版・引き継ぎ（.niatra）が読めるよう今までどおり
/// 残す。
String quickToolDisplayLabel(
  AppLocalizations l10n,
  QuickToolEntry entry,
  Iterable<Brush> brushes,
) {
  switch (entry.toolKey) {
    case 'eraser':
      return l10n.quickToolEraser;
    case 'eyedropper':
      return l10n.quickToolEyedropper;
    case 'bucket':
      return l10n.quickToolBucket;
    case 'pen':
      final id = entry.brushId;
      final brush = brushes.where((b) => b.id == id).firstOrNull;
      if (brush == null) return entry.label;
      final size = entry.sizeOverride;
      return size == null ? brush.name : '${brush.name} ${size.round()}px';
  }
  return entry.label;
}

/// 早替えツール設定ポップアップ。
/// ↺ボタンの長押しで表示する。ドラッグで順番変更・削除・追加ができる。
class QuickToolPanel extends StatelessWidget {
  final VoidCallback onClose;
  // 「現在のブラシを追加」用（使用中のブラシ設定をそのまま登録可能）
  final DrawingTool currentTool;
  final String? currentBrushId;
  final String? currentBrushName;
  final double currentSize;

  const QuickToolPanel({
    super.key,
    required this.onClose,
    required this.currentTool,
    this.currentBrushId,
    this.currentBrushName,
    required this.currentSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<QuickToolService>();
    final entries = service.entries;
    // ブラシの名前を変えたら、一覧の名前も変わる。
    final brushes = context.watch<BrushService>().brushes;

    final height = _floatingHeight(context);
    // 浮かぶパネルが置ける場所より低くなるとき（横向きのスマホ）は、題を
    // 一覧と一緒にスクロールさせる（題を固定すると、大きな文字では題が
    // 3行になり、一覧が数pxに押しつぶされた）。
    final compact =
        !DockedPanelScope.of(context) &&
        height < _preferredFloatingHeight(context);
    // 題はパネルの幅で折り返す（`Text`＋`Spacer`の行に置いていた頃は
    // 折り返さず、西語「Ajustes de herramientas rápidas」が行から
    // はみ出した）。韓国語の語は、1行に入れば途中で折らない。
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        messageText(
          l10n.quickToolPanelTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
        ),
        const Divider(),
      ],
    );
    final empty = Text(
      l10n.quickToolEmpty,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );

    return PanelSurface(
      width: 260,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelCenterCloseBar(onClose: onClose),
            if (!compact) heading,
            Expanded(
              child: entries.isEmpty
                  ? compact
                        ? ListView(children: [heading, empty])
                        : Center(child: empty)
                  // 行の幅（一覧の幅）で、名前を番号と操作の間に置くか、番号と
                  // 操作の行の下に置くかを決める（[_QuickToolRows]）。
                  : LayoutBuilder(
                      builder: (context, box) {
                        final rows = _QuickToolRows(
                          context,
                          rowWidth: box.maxWidth,
                          count: entries.length,
                        );
                        return ReorderableListView.builder(
                          // ドラッグハンドルを明示アイコンとして置く（既定の
                          // ままだと行の長押しでしか並べ替えを開始できず、
                          // 可視の目印が無いままだった）。
                          buildDefaultDragHandles: false,
                          header: compact ? heading : null,
                          itemCount: entries.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              service.reorder(
                                oldIndex,
                                preRemovalIndex(oldIndex, newIndex),
                              ),
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            return rows.build(
                              key: ValueKey(e.id),
                              index: index,
                              label: quickToolDisplayLabel(l10n, e, brushes),
                              unavailable:
                                  e.brushId != null &&
                                      !brushes.any(
                                        (brush) => brush.id == e.brushId,
                                      )
                                  ? l10n.quickToolBrushUnavailable
                                  : null,
                              deleteTooltip: l10n.commonDelete,
                              onDelete: () => service.removeEntry(e.id),
                            );
                          },
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.commonAdd),
              onPressed: () => _showAddDialog(context, service),
            ),
          ],
        ),
      ),
    );
  }

  /// スマホの浮かぶパネルの高さ。文字の大きさに合わせて高くし（文字2倍では
  /// 題が3行になり、名前を番号と操作の下に回した行も高くなるので、360pxの
  /// ままでは一覧に1行しか見えなかった）、画面の上の帯（56px）と上下の空き
  /// （16px）を残した高さまでにする。360pxは置ける場所があるときの下限で、
  /// 横向きのスマホ（高さ360〜400px）のように場所が足りなければ、置ける
  /// 高さまで低くする（一覧はその中でスクロールする。以前は360pxより低く
  /// しなかったので、パネルの上の端が画面の外へ切れた）。
  static double _floatingHeight(BuildContext context) {
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        56 -
        16 * 2;
    return math.min(
      _preferredFloatingHeight(context),
      math.max(0.0, available),
    );
  }

  /// 場所が足りるときの浮かぶパネルの高さ（360pxを文字の大きさに合わせて
  /// 高くしたもの）。
  static double _preferredFloatingHeight(BuildContext context) {
    const base = 360.0;
    return math.max(base, MediaQuery.textScalerOf(context).scale(base));
  }

  void _showAddDialog(BuildContext context, QuickToolService service) {
    final brushService = context.read<BrushService>();
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 「現在のブラシを追加」：使用中のブラシ設定をそのまま登録
            if (currentTool == DrawingTool.pen && currentBrushId != null)
              ListTile(
                leading: Icon(
                  Icons.bolt,
                  color: ThemeService.activeColorScheme.tertiary,
                ),
                title: Text(l10n.quickToolAddCurrentBrush),
                subtitle: Text('$currentBrushName ${currentSize.round()}px'),
                onTap: () {
                  service.addEntry(
                    QuickToolEntry(
                      id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
                      label: '$currentBrushName ${currentSize.round()}px',
                      toolKey: 'pen',
                      brushId: currentBrushId,
                      sizeOverride: currentSize,
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
            if (currentTool == DrawingTool.pen && currentBrushId != null)
              const Divider(height: 1),
            for (final brush in brushService.brushes)
              ListTile(
                leading: const Icon(Icons.brush),
                title: Text(brush.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSizeDialog(
                    context,
                    service,
                    brush.id,
                    brush.name,
                    brush.size,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.quickToolEraser),
              onTap: () {
                _addSimple(service, 'eraser', l10n.quickToolEraser);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: Text(l10n.quickToolEyedropper),
              onTap: () {
                _addSimple(service, 'eyedropper', l10n.quickToolEyedropper);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: Text(l10n.quickToolBucket),
              onTap: () {
                _addSimple(service, 'bucket', l10n.quickToolBucket);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSimple(QuickToolService service, String toolKey, String label) {
    service.addEntry(
      QuickToolEntry(
        id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        toolKey: toolKey,
      ),
    );
  }

  void _showSizeDialog(
    BuildContext context,
    QuickToolService service,
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
          // 値は上の行の右端へ出し、スライダーは［－］［＋］の間で
          // ダイアログの横幅いっぱいに広げる。ダイアログ自体も既定
          // （左右40px空け、内容が狭ければ幅280）より広く取る。
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(l10n.quickToolSizeDialogTitle(brushName)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 14),
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
                  label: '${size.round()}px',
                  onChanged: (v) => setS(() => size = v),
                ),
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
                service.addEntry(
                  QuickToolEntry(
                    id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
                    label: '$brushName ${size.round()}px',
                    toolKey: 'pen',
                    brushId: brushId,
                    sizeOverride: size,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }
}

/// 早替えツールの一覧の行の並べ方（行の幅[rowWidth]・行の数[count]ごと）。
///
/// 名前が先頭の番号と右の操作（削除・並べ替えのつまみ）の間の欄に1行で入る
/// 行は1行に並べ、入らない行は番号と操作の行の下に名前を置いて、行の幅
/// いっぱいを名前に使う（名前を縮めない・省略記号で切らない）。以前は
/// ListTileの既定の余白で並べていて、パネルの幅260pxでは名前の欄が74pxしか
/// なく、今の言語で出すようになった名前（英語「Eyedropper」83px・西語
/// 「Cuentagotas」92px）が語の途中で折れた。
///
/// 欄に入るかは、語の幅ではなく名前を1行に並べた幅で決める。ブラシの名前
/// （「Gペン 3px」）は字の間で折れるので、語の幅で決めると狭い欄で
/// 「Gペ / ン / 3p / x」と折れた（くらむぼんの文を1pxの幅で並べ直す測り方
/// 〔`widestUnbreakableWidth`〕は「3px」を「3」「px」に分けて数えた）。
class _QuickToolRows {
  _QuickToolRows(this.context, {required this.rowWidth, required int count})
    : _badgeWidth = _measure(
        context,
        // 番号の欄は、いちばん大きい番号の桁数ぶん（どの行の名前も同じ所から
        // 始まる）。
        '$count'.replaceAll(RegExp(r'\d'), '0'),
        _badgeStyle(context),
      );

  final BuildContext context;
  final double rowWidth;
  final double _badgeWidth;

  /// 行の左右の余白（右は、つまみの押せる所が端まで届くよう狭く）。
  static const _padding = EdgeInsetsDirectional.only(start: 12, end: 4);

  /// 番号と名前、名前と操作の間。
  static const double _gap = 12;

  /// 削除のボタン（押せる大きさの最小、48）と、並べ替えのつまみ（指で
  /// つかめる幅32・高さ48）。
  static const double _deleteSize = kMinInteractiveDimension;
  static const Size _handleSize = Size(32, kMinInteractiveDimension);

  static const _nameStyle = TextStyle(
    fontSize: 13,
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  /// 番号の書式（ListTileの先頭の既定〔labelSmall・onSurfaceVariant〕に
  /// 大きさを足したもの。名前の上の行に置いても同じに描く）。
  static TextStyle _badgeStyle(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        ListTileTheme.of(context).leadingAndTrailingTextStyle ??
        theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle();
    return base.copyWith(fontSize: 12);
  }

  /// [text]を[style]で1行に描いたときの幅。
  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// 番号と操作の間に置いたときの名前の欄の幅。
  double get _nameWidthBeside =>
      rowWidth -
      _padding.horizontal -
      _badgeWidth -
      _gap * 2 -
      _deleteSize -
      _handleSize.width;

  /// 名前[name]（文は[label]）を1行に並べた幅（行の題の書式で）。
  double _lineWidthOf(Widget name, String label) {
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
      maxLines: 1,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  /// [index]番目の行（名前は[label]）。
  Widget build({
    required Key key,
    required int index,
    required String label,
    String? unavailable,
    required String deleteTooltip,
    required VoidCallback onDelete,
  }) {
    // 韓国語の語・数と単位は、1行に入れば途中で折らない。
    final name = messageText(label, style: _nameStyle);
    final beside =
        unavailable == null && _lineWidthOf(name, label) <= _nameWidthBeside;
    final badge = SizedBox(
      width: _badgeWidth,
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: _badgeStyle(context),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _deleteSize,
          child: IconButton(
            icon: Icon(
              Icons.delete,
              size: 16,
              color: ThemeService.activeColorScheme.error,
            ),
            tooltip: deleteTooltip,
            onPressed: onDelete,
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: SizedBox.fromSize(
            size: _handleSize,
            // 名前の下に回した行でも、1行の行（ListTileの末尾のアイコンの
            // 色）と同じ色で描く。
            child: Icon(
              Icons.drag_handle,
              size: 18,
              color:
                  ListTileTheme.of(context).iconColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    return ListTile(
      key: key,
      dense: true,
      contentPadding: _padding,
      horizontalTitleGap: _gap,
      minLeadingWidth: 0,
      minVerticalPadding: beside ? null : 4,
      leading: beside ? badge : null,
      title: beside
          ? name
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [badge, const Spacer(), controls]),
                name,
                if (unavailable != null)
                  messageText(
                    unavailable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
      trailing: beside ? controls : null,
    );
  }
}
