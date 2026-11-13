import 'package:flutter/material.dart';

import '../config/accent_text_theme.dart';
import '../config/font_fallback.dart';
import '../l10n/app_localizations.dart';
import '../utils/color_contrast.dart';
import 'docked_panel_scope.dart';

/// PC/DeXモード専用の作業画面（キャンバス・タイムライン）の部品。
///
/// ボタンはスマホと同じもの（同じ機能を同じボタンで）を使い、スマホでは
/// キャンバスの上に浮かべていたパネルを、広い画面ではドックの窓に入れて
/// 画面を区切って並べる。上部バー・ステータスバーはテーマのメニューの色、
/// 窓はパネルの色で塗る。
@immutable
class PcWorkspaceColors {
  const PcWorkspaceColors._({
    required this.chrome,
    required this.onChrome,
    required this.mutedOnChrome,
    required this.pane,
    required this.paneHeader,
    required this.onPane,
    required this.mutedOnPane,
    required this.divider,
    required this.accentText,
    required this.accentFill,
  });

  factory PcWorkspaceColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // テーマの色は透明度まで選べるので、下の画面が透けないよう平たくする。
    final pane = opaqueOver(
      scheme.surface,
      scheme.brightness == Brightness.dark ? Colors.black : Colors.white,
    );
    final chrome = opaqueOver(
      theme.appBarTheme.backgroundColor ?? scheme.surfaceContainer,
      pane,
    );
    final onChrome = theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    return PcWorkspaceColors._(
      chrome: chrome,
      onChrome: onChrome,
      mutedOnChrome: onChrome.withValues(alpha: 0.72),
      pane: pane,
      paneHeader: opaqueOver(scheme.surfaceContainerHigh, pane),
      onPane: scheme.onSurface,
      mutedOnPane: scheme.onSurfaceVariant,
      divider: scheme.outlineVariant,
      accentText: AccentTextTheme.of(context),
      accentFill: scheme.primary,
    );
  }

  /// 上部バー・ステータスバーの面と文字。
  final Color chrome;
  final Color onChrome;
  final Color mutedOnChrome;

  /// ドックのペインの面・見出しの面と文字。
  final Color pane;
  final Color paneHeader;
  final Color onPane;
  final Color mutedOnPane;
  final Color divider;

  /// 背景の上の差し色の文字・アイコン（[AccentTextTheme]）と、差し色の塗り。
  final Color accentText;
  final Color accentFill;

  /// [base]の上で「選択中・オン」を表す淡い差し色の塗り。
  Color selectedOn(Color base) =>
      Color.alphaBlend(accentFill.withValues(alpha: 0.24), base);
}

/// 画面の上の上部バー。ボタンをアイコンで並べる。
/// 入りきらない幅では[leading]が横にスクロールし、[trailing]は右端に残る。
class PcCommandBar extends StatelessWidget {
  const PcCommandBar({
    super.key,
    required this.leading,
    this.trailing = const [],
  });

  final List<Widget> leading;
  final List<Widget> trailing;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    return Material(
      color: colors.chrome,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.divider),
            bottom: BorderSide(color: colors.divider),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: leading),
              ),
            ),
            ...trailing,
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// 上部バー・窓の見出しのアイコンボタン。[selected]は入切の
/// 「オン」を淡い差し色の塗りで表す。
class PcToolButton extends StatelessWidget {
  const PcToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.onPane = false,
    this.size = 30,
    this.iconSize = 18,
    this.trailingIcon,
  });

  final IconData icon;

  /// [icon]の右に小さく添えるアイコン（行き先の向きなど）。ボタンは横に広がる。
  final IconData? trailingIcon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  /// ペインの上に置く（文字色・塗りをペインに合わせる）。
  final bool onPane;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final fg = onPane ? colors.onPane : colors.onChrome;
    final base = onPane ? colors.pane : colors.chrome;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: IconButton(
        icon: trailingIcon == null
            ? Icon(icon, size: iconSize)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize),
                  const SizedBox(width: 2),
                  Icon(trailingIcon, size: iconSize * 0.75),
                ],
              ),
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: selected,
        style: IconButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: fg.withValues(alpha: 0.35),
          backgroundColor: selected ? colors.selectedOn(base) : null,
          minimumSize: Size(trailingIcon == null ? size : size * 1.6, size),
          fixedSize: Size(trailingIcon == null ? size : size * 1.6, size),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }
}

/// 上部バーに置くメニューのボタン（`PopupMenuButton.style`）を
/// [PcToolButton]と同じ大きさ・色にする。
ButtonStyle pcBarButtonStyle(BuildContext context) {
  final colors = PcWorkspaceColors.of(context);
  return IconButton.styleFrom(
    foregroundColor: colors.onChrome,
    disabledForegroundColor: colors.onChrome.withValues(alpha: 0.35),
    minimumSize: const Size(30, 30),
    fixedSize: const Size(30, 30),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  );
}

/// 上部バーの区切り。
class PcCommandDivider extends StatelessWidget {
  const PcCommandDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: PcWorkspaceColors.of(context).divider,
  );
}

/// 画面最下段のステータスバー。[items]は左から、[trailing]は右端に並べ、
/// 幅が足りなければ左の項目から省略する。
class PcStatusBar extends StatelessWidget {
  const PcStatusBar({super.key, required this.items, this.trailing = const []});

  final List<Widget> items;
  final List<Widget> trailing;

  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    Widget separator() => Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: colors.divider,
    );
    return Material(
      color: colors.chrome,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRect(
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) separator(),
                      Flexible(child: items[i]),
                    ],
                  ],
                ),
              ),
            ),
            for (var i = 0; i < trailing.length; i++) ...[
              separator(),
              trailing[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// ステータスバーの1項目（アイコン＋文字）。
class PcStatusItem extends StatelessWidget {
  const PcStatusItem({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontSize: 11.5, color: colors.onChrome);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: colors.mutedOnChrome),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// ドックのペインの1つのタブ。[onClose]があれば見出しに×を出す。
class PcPaneTab {
  const PcPaneTab({
    required this.id,
    required this.title,
    required this.child,
    this.icon,
    this.onClose,
  });

  final String id;
  final String title;
  final IconData? icon;
  final Widget child;
  final VoidCallback? onClose;
}

/// ドックの列の1つのペイン。[fill]のペインは列の残りの高さを分け合い、
/// それ以外は[preferredHeight]の高さで始まる（どちらも境目のつまみで変えられる）。
class PcPane {
  const PcPane({
    required this.id,
    required this.tabs,
    this.fill = false,
    this.preferredHeight = 200,
    this.minLayoutHeight = 240,
    this.focusTab,
    this.focusSerial = 0,
    this.movable = false,
    this.collapsed,
    this.onCollapsedChanged,
  });

  final String id;
  final List<PcPaneTab> tabs;
  final bool fill;
  final double preferredHeight;

  /// 見出しをつかんで、同じ列の別の位置や反対側の列へ動かせる
  /// （[PcDockColumn.onPaneDropped]）。
  final bool movable;

  /// 中身を並べる最低の高さ。ペインがこれより低いときは、中身をこの高さで
  /// 並べてペインの中でスクロールする（パネルの見出し・ボタンの段が潰れて
  /// はみ出さないように）。自分で大きさを合わせる・スクロールする中身は0。
  final double minLayoutHeight;

  /// [focusSerial]が変わったとき、このタブを前に出し、ペインを広げる。
  final String? focusTab;
  final int focusSerial;

  /// たたんでいるか（外で覚えておく場合。nullなら列が自分で覚える）。
  /// 外で覚えるときは、たたむ・広げるの操作を[onCollapsedChanged]で受ける。
  final bool? collapsed;
  final ValueChanged<bool>? onCollapsedChanged;
}

/// ドックの列。ペインを縦に並べ、境目のつまみで高さを分け直せる。
/// ペインは見出しの矢印でたためる（見出しにダブルクリックを付けると、
/// タブのクリックがダブルクリックの判定を待って遅れる）。タブは開いた順に
/// 前に出る。動かせるペインは見出しをつかんで、別のペインの上へ落とすと
/// その前（ペインの下半分なら後ろ）へ入る。列をまたいでも落とせる。
class PcDockColumn extends StatefulWidget {
  const PcDockColumn({
    super.key,
    required this.panes,
    this.onActiveTabChanged,
    this.onPaneResized,
    this.onPaneDropped,
  });

  final List<PcPane> panes;

  /// ペインの前に出ているタブが変わったとき（ペインのid, タブのid）。
  final void Function(String paneId, String tabId)? onActiveTabChanged;

  /// 境目のつまみを離したとき、高さを変えたペインのidと中身の高さ。
  /// 保存した高さを[PcPane.preferredHeight]で渡し直すと、その値で並べる。
  final void Function(String paneId, double height)? onPaneResized;

  /// 動かせるペインがこの列へ落とされたとき（落とされたペインのid、その
  /// 前に入るペインのid。nullなら列の最後）。
  final void Function(String paneId, String? beforePaneId)? onPaneDropped;

  static const double headerHeight = 28;

  /// 列の窓がすべてたたまれたときの列の幅（窓ごとに広げるボタンだけを
  /// 縦に並べた細い帯）。
  static const double foldedWidth = 52;
  static const double splitterHeight = 5;
  static const double minContentHeight = 120;

  @override
  State<PcDockColumn> createState() => _PcDockColumnState();
}

class _PcDockColumnState extends State<PcDockColumn> {
  final Map<String, String> _active = {};
  final Set<String> _collapsed = {};
  final Map<String, double> _heights = {};
  final Map<String, double> _weights = {};
  // 直前のレイアウトでの中身の高さ（つまみのドラッグの基準）。
  final Map<String, double> _laidOut = {};
  final Map<String, GlobalKey> _paneKeys = {};
  // いま動かしているつまみで高さが変わるペイン。
  String? _resizing;

  @override
  void initState() {
    super.initState();
    for (final pane in widget.panes) {
      _syncActive(pane, null);
    }
  }

  @override
  void didUpdateWidget(PcDockColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = {for (final p in oldWidget.panes) p.id: p};
    for (final pane in widget.panes) {
      _syncActive(pane, old[pane.id]);
      // 外で決め直した高さ（保存した値・設定の画面）を優先する。
      final before = old[pane.id];
      if (before != null && before.preferredHeight != pane.preferredHeight) {
        _heights.remove(pane.id);
      }
    }
  }

  void _syncActive(PcPane pane, PcPane? old) {
    if (pane.tabs.isEmpty) return;
    final ids = [for (final t in pane.tabs) t.id];
    String? next = _active[pane.id];
    // 新しく開いたタブを前に出す。
    final oldIds = {for (final t in old?.tabs ?? const <PcPaneTab>[]) t.id};
    if (old != null) {
      for (final id in ids) {
        if (!oldIds.contains(id)) next = id;
      }
    }
    if (pane.focusTab != null &&
        ids.contains(pane.focusTab) &&
        (old == null || old.focusSerial != pane.focusSerial)) {
      next = pane.focusTab;
      if (old != null && _isCollapsed(pane)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setCollapsed(pane, false);
        });
      }
    }
    if (next == null || !ids.contains(next)) next = ids.first;
    if (_active[pane.id] != next) {
      _active[pane.id] = next;
      final notify = widget.onActiveTabChanged;
      if (notify != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) notify(pane.id, next!);
        });
      }
    }
  }

  bool _isCollapsed(PcPane pane) =>
      pane.collapsed ?? _collapsed.contains(pane.id);

  void _setCollapsed(PcPane pane, bool collapsed) {
    final notify = pane.onCollapsedChanged;
    if (pane.collapsed != null && notify != null) {
      if (pane.collapsed != collapsed) notify(collapsed);
      return;
    }
    setState(() {
      if (collapsed) {
        _collapsed.add(pane.id);
      } else {
        _collapsed.remove(pane.id);
      }
    });
  }

  void _select(PcPane pane, String tabId) {
    if (_active[pane.id] == tabId && !_isCollapsed(pane)) return;
    setState(() => _active[pane.id] = tabId);
    _setCollapsed(pane, false);
    widget.onActiveTabChanged?.call(pane.id, tabId);
  }

  void _toggleCollapsed(PcPane pane) =>
      _setCollapsed(pane, !_isCollapsed(pane));

  void _drag(List<PcPane> panes, Set<String> fills, int i, double dy) {
    final upper = panes[i];
    final lower = panes[i + 1];
    final upperOpen = !_isCollapsed(upper);
    final lowerOpen = !_isCollapsed(lower);
    const minH = PcDockColumn.minContentHeight;
    setState(() {
      if (upperOpen && !fills.contains(upper.id)) {
        _resizing = upper.id;
        _heights[upper.id] =
            ((_heights[upper.id] ?? upper.preferredHeight) + dy).clamp(
              minH,
              4000.0,
            );
      } else if (lowerOpen && !fills.contains(lower.id)) {
        _resizing = lower.id;
        _heights[lower.id] =
            ((_heights[lower.id] ?? lower.preferredHeight) - dy).clamp(
              minH,
              4000.0,
            );
      } else if (upperOpen && lowerOpen) {
        _resizing = null;
        // 2つとも残りを分け合うペイン：今の高さを重みにして、境目を動かす。
        for (final id in fills) {
          _weights[id] = _laidOut[id] ?? 1;
        }
        final a = _laidOut[upper.id] ?? minH;
        final b = _laidOut[lower.id] ?? minH;
        final total = a + b;
        if (total <= minH * 2) return;
        final na = (a + dy).clamp(minH, total - minH);
        _weights[upper.id] = na;
        _weights[lower.id] = total - na;
      }
    });
  }

  void _dragEnd() {
    final id = _resizing;
    _resizing = null;
    final height = id == null ? null : _heights[id];
    if (id != null && height != null) widget.onPaneResized?.call(id, height);
  }

  /// [pane]の上へ落とされたとき：ペインの上半分ならその前、下半分なら
  /// その後ろ（次のペインの前）へ入れる。
  void _drop(List<PcPane> panes, PcPane pane, String dragged, Offset global) {
    final box =
        _paneKeys[pane.id]?.currentContext?.findRenderObject() as RenderBox?;
    var lower = false;
    if (box != null && box.hasSize) {
      lower = box.globalToLocal(global).dy > box.size.height / 2;
    }
    String? before = pane.id;
    if (lower) {
      final i = panes.indexOf(pane);
      before = i + 1 < panes.length ? panes[i + 1].id : null;
    }
    if (before == dragged) return;
    widget.onPaneDropped?.call(dragged, before);
  }

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final panes = [
      for (final p in widget.panes)
        if (p.tabs.isNotEmpty) p,
    ];
    if (panes.isEmpty) return const SizedBox.shrink();
    return ColoredBox(
      color: colors.pane,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // すべてたたんだ列は細い帯：窓ごとに広げるボタンだけを並べる。
          if (panes.every(_isCollapsed) &&
              constraints.maxWidth <= PcDockColumn.foldedWidth + 0.5) {
            return _folded(panes, colors);
          }
          const header = PcDockColumn.headerHeight;
          const splitter = PcDockColumn.splitterHeight;
          const minH = PcDockColumn.minContentHeight;
          final open = [
            for (final p in panes)
              if (!_isCollapsed(p)) p,
          ];
          final fills = {
            for (final p in open)
              if (p.fill) p.id,
          };
          // 残りを受けるペインが無ければ、一番下の開いたペインが受ける。
          if (fills.isEmpty && open.isNotEmpty) fills.add(open.last.id);
          final available =
              constraints.maxHeight -
              header * panes.length -
              splitter * (panes.length - 1);
          final fixed = {
            for (final p in open)
              if (!fills.contains(p.id))
                p.id: _heights[p.id] ?? p.preferredHeight,
          };
          final fixedSum = fixed.values.fold(0.0, (a, b) => a + b);
          final fillMin = minH * fills.length;
          var scale = 1.0;
          if (fixedSum > 0 && fixedSum > available - fillMin) {
            scale = ((available - fillMin) / fixedSum).clamp(0.0, 1.0);
          }
          var fillSpace = available - fixedSum * scale;
          if (fillSpace < 0) fillSpace = 0;
          final weightSum = fills.fold(0.0, (a, id) => a + (_weights[id] ?? 1));
          final content = <String, double>{
            for (final p in open)
              p.id: fills.contains(p.id)
                  ? (weightSum > 0
                        ? fillSpace * (_weights[p.id] ?? 1) / weightSum
                        : 0)
                  : fixed[p.id]! * scale,
          };
          _laidOut
            ..clear()
            ..addAll(content);

          final children = <Widget>[];
          for (var i = 0; i < panes.length; i++) {
            final pane = panes[i];
            if (i > 0) {
              children.add(
                _PcSplitter(
                  // 上の窓の下端のつまみ。
                  key: ValueKey('pcPaneResize.${panes[i - 1].id}'),
                  axis: Axis.vertical,
                  onDrag: (d) => _drag(panes, fills, i - 1, d),
                  onDragEnd: _dragEnd,
                ),
              );
            }
            final collapsed = _isCollapsed(pane);
            Widget view = SizedBox(
              key: _paneKeys.putIfAbsent(pane.id, GlobalKey.new),
              height: header + (collapsed ? 0 : content[pane.id] ?? 0),
              child: _PcDockPaneView(
                pane: pane,
                activeId: _active[pane.id] ?? pane.tabs.first.id,
                collapsed: collapsed,
                onSelect: (id) => _select(pane, id),
                onToggleCollapsed: () => _toggleCollapsed(pane),
              ),
            );
            if (widget.onPaneDropped != null) {
              final inner = view;
              view = DragTarget<_PcPaneDrag>(
                onWillAcceptWithDetails: (d) => d.data.id != pane.id,
                onAcceptWithDetails: (d) =>
                    _drop(panes, pane, d.data.id, d.offset),
                builder: (context, candidates, _) => candidates.isEmpty
                    ? inner
                    : DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colors.accentFill,
                            width: 2,
                          ),
                        ),
                        child: inner,
                      ),
              );
            }
            children.add(view);
          }
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          );
        },
      ),
    );
  }

  Widget _folded(List<PcPane> panes, PcWorkspaceColors colors) {
    return SingleChildScrollView(
      key: const ValueKey('pcDockFolded'),
      child: Column(
        children: [
          for (final pane in panes)
            Builder(
              builder: (context) {
                final tab = pane.tabs.firstWhere(
                  (t) => t.id == _active[pane.id],
                  orElse: () => pane.tabs.first,
                );
                return SizedBox(
                  height: 48,
                  child: Center(
                    child: IconButton(
                      key: ValueKey('pcPaneExpand.${pane.id}'),
                      tooltip: tab.title,
                      icon: Icon(tab.icon, color: colors.onPane),
                      onPressed: () => _setCollapsed(pane, false),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PcDockPaneView extends StatelessWidget {
  const _PcDockPaneView({
    required this.pane,
    required this.activeId,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapsed,
  });

  final PcPane pane;
  final String activeId;
  final bool collapsed;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final activeIndex = pane.tabs
        .indexWhere((t) => t.id == activeId)
        .clamp(0, pane.tabs.length - 1);
    final active = pane.tabs[activeIndex];
    final titleStyle = TextStyle(
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
      fontSize: 12,
      color: colors.onPane,
    );
    final tabs = [
      for (final tab in pane.tabs)
        _PcTabLabel(
          key: ValueKey('pcPaneTab.${tab.id}'),
          tab: tab,
          active: tab.id == active.id,
          style: titleStyle,
          onTap: () => onSelect(tab.id),
        ),
    ];
    return Material(
      color: colors.pane,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: ValueKey('pcPaneHeader.${pane.id}'),
            height: PcDockColumn.headerHeight,
            decoration: BoxDecoration(
              color: colors.paneHeader,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: pane.movable
                      ? _draggableHeader(context, tabs, active, titleStyle)
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: tabs),
                        ),
                ),
                PcToolButton(
                  key: ValueKey('pcPaneCollapse.${pane.id}'),
                  icon: collapsed ? Icons.expand_more : Icons.expand_less,
                  tooltip: collapsed
                      ? l10n.filterPanelExpand
                      : l10n.filterPanelCollapse,
                  onPressed: onToggleCollapsed,
                  onPane: true,
                  size: 24,
                  iconSize: 16,
                ),
                if (active.onClose != null)
                  PcToolButton(
                    key: ValueKey('pcPaneClose.${active.id}'),
                    icon: Icons.close,
                    tooltip: l10n.commonClose,
                    onPressed: active.onClose,
                    onPane: true,
                    size: 24,
                    iconSize: 15,
                  ),
                const SizedBox(width: 2),
              ],
            ),
          ),
          if (!collapsed)
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final short = constraints.maxHeight < pane.minLayoutHeight;
                    // 低さに関係なく同じ形の木にして、パネルの状態を保つ。
                    return SingleChildScrollView(
                      physics: short
                          ? null
                          : const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: short
                            ? pane.minLayoutHeight
                            : constraints.maxHeight,
                        child: DockedPanelScope(
                          child: IndexedStack(
                            index: activeIndex,
                            sizing: StackFit.expand,
                            children: [
                              for (final tab in pane.tabs)
                                KeyedSubtree(
                                  key: ValueKey(tab.id),
                                  child: tab.child,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 動かせるペインの見出し。つかんで別のペインの上へ落とす。
  Widget _draggableHeader(
    BuildContext context,
    List<Widget> tabs,
    PcPaneTab active,
    TextStyle titleStyle,
  ) {
    final colors = PcWorkspaceColors.of(context);
    // 見出しの空いた所もつかめるよう、行の外側まで当たりにする。
    final row = ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Row(mainAxisSize: MainAxisSize.min, children: tabs),
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<_PcPaneDrag>(
        key: ValueKey('pcPaneDrag.${pane.id}'),
        data: _PcPaneDrag(pane.id),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: colors.paneHeader,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.accentFill),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active.icon != null) ...[
                  Icon(active.icon, size: 14, color: colors.onPane),
                  const SizedBox(width: 5),
                ],
                Text(active.title, style: titleStyle),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: row),
        child: row,
      ),
    );
  }
}

/// ドックのペインを動かすときに運ぶもの。
@immutable
class _PcPaneDrag {
  const _PcPaneDrag(this.id);
  final String id;
}

class _PcTabLabel extends StatelessWidget {
  const _PcTabLabel({
    super.key,
    required this.tab,
    required this.active,
    required this.style,
    required this.onTap,
  });

  final PcPaneTab tab;
  final bool active;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final fg = active ? colors.onPane : colors.mutedOnPane;
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: PcDockColumn.headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? colors.pane : null,
            border: Border(
              bottom: BorderSide(
                color: active ? colors.accentFill : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.icon != null) ...[
                Icon(tab.icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(tab.title, style: style.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ペインの境目・ドックの境目のつまみ。[axis]がverticalなら上下に、
/// horizontalなら左右に動かす。
class _PcSplitter extends StatelessWidget {
  const _PcSplitter({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDragEnd,
  });

  final Axis axis;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = PcWorkspaceColors.of(context);
    final vertical = axis == Axis.vertical;
    return MouseRegion(
      cursor: vertical
          ? SystemMouseCursors.resizeRow
          : SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: vertical ? (d) => onDrag(d.delta.dy) : null,
        onVerticalDragEnd: vertical ? (_) => onDragEnd?.call() : null,
        onHorizontalDragUpdate: vertical ? null : (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: vertical ? null : (_) => onDragEnd?.call(),
        child: SizedBox(
          height: vertical ? PcDockColumn.splitterHeight : null,
          width: vertical ? null : PcDockSplitter.width,
          child: Center(
            child: Container(
              height: vertical ? 1 : null,
              width: vertical ? null : 1,
              color: colors.divider,
            ),
          ),
        ),
      ),
    );
  }
}

/// ドックとキャンバスの境目のつまみ（左右にドラッグしてドックの幅を変える）。
class PcDockSplitter extends StatelessWidget {
  const PcDockSplitter({super.key, required this.onDrag, this.onDragEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  static const double width = 6;

  @override
  Widget build(BuildContext context) =>
      _PcSplitter(axis: Axis.horizontal, onDrag: onDrag, onDragEnd: onDragEnd);
}

/// 上下の区画の境目のつまみ（上下にドラッグして上の区画の高さを変える）。
class PcRowSplitter extends StatelessWidget {
  const PcRowSplitter({super.key, required this.onDrag, this.onDragEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) =>
      _PcSplitter(axis: Axis.vertical, onDrag: onDrag, onDragEnd: onDragEnd);
}

/// PC/DeXモードのツールパレットの中であることを伝える。キャンバスの上に
/// 浮かぶボタン（`CanvasIconButton`）は、この中では選択中のツールを
/// 淡い差し色の下地で示す。
class PcPaletteScope extends InheritedWidget {
  const PcPaletteScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PcPaletteScope>() != null;

  @override
  bool updateShouldNotify(PcPaletteScope oldWidget) => false;
}
