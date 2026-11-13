import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/canvas_dock_panel.dart';
import '../../../services/settings_service.dart';
import '../../../utils/desktop_dock_column_fit.dart';

/// A live, interactive representation of the desktop canvas docking layout.
///
/// The preview uses the same SettingsService lists, visibility preferences and
/// per-window dimensions as CanvasScreen. Nothing is stored separately.
/// Drag a window's grip to move it between columns; drag the column boundary
/// to resize every window there, or a window's bottom grip for its own height.
/// Pinch/zoom the whole workspace.
class PcWorkspaceLayoutPreview extends StatefulWidget {
  final String Function(CanvasDockPanel) labelOf;

  const PcWorkspaceLayoutPreview({super.key, required this.labelOf});

  @override
  State<PcWorkspaceLayoutPreview> createState() =>
      _PcWorkspaceLayoutPreviewState();
}

class _PcWorkspaceLayoutPreviewState extends State<PcWorkspaceLayoutPreview> {
  static const double workspaceWidth = 1120;
  static const double workspaceHeight = 650;
  final TransformationController _transform = TransformationController();
  final Map<CanvasDockPanel, double> _resizingHeight = {};
  Size? _lastViewportSize;
  double? _leftColumnWidthDrag;
  double? _rightColumnWidthDrag;
  final Map<CanvasDockPanel, int> _dockLastUsed = {};
  int _dockUseSequence = 0;
  CanvasDockPanel? _activeDockPanel;

  void _rememberDockInteraction(CanvasDockPanel panel) {
    _dockLastUsed[panel] = ++_dockUseSequence;
    _activeDockPanel = panel;
  }

  void _expandDock(CanvasDockPanel panel, SettingsService settings) {
    _rememberDockInteraction(panel);
    if (settings.isDesktopDockCollapsed(panel)) {
      settings.setDesktopDockCollapsed(panel, false);
    } else {
      // Auto folding is transient and never overwrites user preferences.
      setState(() {});
    }
  }

  void _collapseDock(CanvasDockPanel panel, SettingsService settings) {
    if (_activeDockPanel == panel) _activeDockPanel = null;
    settings.setDesktopDockCollapsed(panel, true);
  }

  DesktopDockLayout _fitDock(
    SettingsService settings,
    List<CanvasDockPanel> visible,
    double availableHeight,
  ) => DesktopDockColumnFit.layout(
    availableHeight: availableHeight,
    visible: visible,
    isManuallyCollapsed: settings.isDesktopDockCollapsed,
    preferredHeight: (panel) =>
        _resizingHeight[panel] ?? settings.desktopDockHeight(panel),
    autoCollapseEnabled: settings.desktopDockAutoCollapseEnabled,
    lastUsed: _dockLastUsed,
    activePanel: _activeDockPanel,
  );
  // Empty columns reclaim their canvas space outside a panel drag.
  bool _dockDragActive = false;

  void _setDockDragging(bool active) {
    if (!mounted || _dockDragActive == active) return;
    setState(() => _dockDragActive = active);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    final widthScale = viewport.width / workspaceWidth;
    final heightScale = viewport.height / workspaceHeight;
    final scale = (widthScale < heightScale ? widthScale : heightScale).clamp(
      0.25,
      1.0,
    );
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _toggleVisible(SettingsService settings, CanvasDockPanel panel) {
    final next = Set<CanvasDockPanel>.of(settings.defaultDockedPanels);
    if (!next.add(panel)) next.remove(panel);
    settings.setDefaultDockedPanels(next);
  }

  // SettingsService mirrors only pristine defaults; all order getters and
  // drop targets are otherwise the user's saved physical left/right sides.
  bool _storedRightForPhysicalSide(SettingsService settings, bool right) =>
      right;

  List<CanvasDockPanel> _physicalDockOrder(
    SettingsService settings, {
    required bool right,
  }) => _storedRightForPhysicalSide(settings, right)
      ? settings.rightDockOrder
      : settings.toolOptionDockOrder;

  double _preferredWidth(SettingsService settings, {required bool right}) {
    final storedRight = _storedRightForPhysicalSide(settings, right);
    final order = _physicalDockOrder(settings, right: right);
    final visible = order.where(settings.defaultDockedPanels.contains).toList();
    if (visible.isEmpty) return _dockDragActive ? 52 : 0;
    final fitted = _fitDock(settings, visible, workspaceHeight - 44 - 58);
    if (visible.every(
      (p) => fitted.isCollapsed(p, settings.isDesktopDockCollapsed(p)),
    )) {
      return 52;
    }
    return storedRight
        ? (_rightColumnWidthDrag ?? settings.desktopPanelWidth)
        : (_leftColumnWidthDrag ?? settings.desktopToolPanelWidth);
  }

  double _columnWidth(SettingsService settings, {required bool right}) {
    final left = _preferredWidth(settings, right: false);
    final rightWidth = _preferredWidth(settings, right: true);
    final sizes = DesktopDockColumnFit.columnWidths(
      availableWidth: workspaceWidth,
      leftDesired: left,
      rightDesired: rightWidth,
      leftVisible: left > 0,
      rightVisible: rightWidth > 0,
    );
    return right ? sizes.right : sizes.left;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewportSize != viewport &&
            viewport.width > 0 &&
            viewport.height > 0) {
          _lastViewportSize = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit(viewport);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  key: const Key('pcWorkspaceInteractivePreview'),
                  transformationController: _transform,
                  constrained: false,
                  minScale: 0.25,
                  maxScale: 2,
                  boundaryMargin: const EdgeInsets.all(260),
                  child: SizedBox(
                    width: workspaceWidth,
                    height: workspaceHeight,
                    child: Material(
                      color: scheme.surfaceContainerLowest,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            _topBar(settings, l, scheme),
                            Expanded(
                              child: Row(
                                children: [
                                  if (!settings.isLeftHanded) _toolbar(scheme),
                                  _column(settings, right: false),
                                  if (_columnWidth(settings, right: false) > 52)
                                    _columnResizeGrip(settings, right: false),
                                  Expanded(child: _canvasAndFrames(scheme)),
                                  if (_columnWidth(settings, right: true) > 52)
                                    _columnResizeGrip(settings, right: true),
                                  _column(settings, right: true),
                                  if (settings.isLeftHanded) _toolbar(scheme),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IconButton.filledTonal(
                key: const Key('pcWorkspaceFitPreview'),
                tooltip: l.pcWorkspaceLayoutScreenTitle,
                onPressed: () => _fit(viewport),
                icon: const Icon(Icons.fit_screen),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topBar(
    SettingsService settings,
    AppLocalizations l,
    ColorScheme scheme,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.undo, size: 20, color: scheme.onSurface),
          const SizedBox(width: 12),
          Icon(Icons.redo, size: 20, color: scheme.onSurface),
          const SizedBox(width: 26),
          Text(
            l.pcWorkspaceLayoutScreenTitle,
            style: TextStyle(color: scheme.onSurface, fontSize: 14),
          ),
          const Spacer(),
          PopupMenuButton<CanvasDockPanel>(
            key: const Key('pcWorkspacePreviewVisibilityMenu'),
            tooltip: l.workspaceDockPanelSection,
            icon: Icon(Icons.view_sidebar_outlined, color: scheme.onSurface),
            onSelected: (panel) => _toggleVisible(settings, panel),
            itemBuilder: (_) => [
              for (final panel in CanvasDockPanel.values.where(
                (p) => !isLegacyMaterialDock(p),
              ))
                CheckedPopupMenuItem<CanvasDockPanel>(
                  value: panel,
                  checked: settings.defaultDockedPanels.contains(panel),
                  child: Text(widget.labelOf(panel)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Icon(Icons.settings, size: 22, color: scheme.onSurface),
          const SizedBox(width: 14),
          Icon(Icons.home_outlined, size: 22, color: scheme.onSurface),
          const SizedBox(width: 14),
          Icon(Icons.movie_filter_outlined, size: 22, color: scheme.onSurface),
          Icon(Icons.arrow_forward, size: 16, color: scheme.onSurface),
        ],
      ),
    );
  }

  Widget _toolbar(ColorScheme scheme) {
    final leftHanded = context.watch<SettingsService>().isLeftHanded;
    return Container(
      key: const ValueKey('pcPreviewToolbar'),
      width: 52,
      decoration: BoxDecoration(
        border: Border(
          left: leftHanded
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
          right: leftHanded
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          for (final icon in [
            Icons.brush_outlined,
            Icons.auto_fix_normal,
            Icons.format_color_fill,
            Icons.colorize_outlined,
            Icons.pan_tool_outlined,
            Icons.crop_free,
            Icons.text_fields,
            Icons.category_outlined,
            Icons.palette_outlined,
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Icon(icon, size: 22, color: scheme.onSurface),
            ),
        ],
      ),
    );
  }

  Widget _column(SettingsService settings, {required bool right}) {
    final scheme = Theme.of(context).colorScheme;
    final storedRight = _storedRightForPhysicalSide(settings, right);
    final order = _physicalDockOrder(settings, right: right);
    final visible = order.where(settings.defaultDockedPanels.contains).toList();
    return Padding(
      // The frame timeline is 58px tall: docks never enter its bottom strip.
      padding: const EdgeInsets.only(bottom: 58),
      child: SizedBox(
        width: _columnWidth(settings, right: right),
        child: DragTarget<CanvasDockPanel>(
          key: ValueKey(right ? 'pcPreviewRightColumn' : 'pcPreviewToolColumn'),
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              settings.moveDesktopDockPanel(details.data, toRight: storedRight),
          builder: (context, candidates, _) => ColoredBox(
            color: candidates.isEmpty
                ? scheme.surface
                : scheme.primaryContainer,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fitted = _fitDock(
                  settings,
                  visible,
                  constraints.maxHeight,
                );
                final heights = fitted.bodyHeights;
                return ListView(
                  key: ValueKey(
                    right
                        ? 'pcPreviewRightDockScroll'
                        : 'pcPreviewLeftDockScroll',
                  ),
                  children: [
                    if (visible.isEmpty && _dockDragActive)
                      SizedBox(
                        height: 80,
                        child: Center(
                          child: Icon(
                            Icons.add,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: DesktopDockColumnFit.gap),
                      Align(
                        alignment: right
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _window(
                          settings,
                          visible[i],
                          right: right,
                          fittedBodyHeight: heights[visible[i]],
                          automaticallyCollapsed: fitted.automaticallyCollapsed
                              .contains(visible[i]),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _columnResizeGrip(SettingsService settings, {required bool right}) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        key: ValueKey(
          right ? 'pcPreviewRightColumnResize' : 'pcPreviewToolColumnResize',
        ),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => setState(() {
          final delta = details.delta.dx * (right ? -1 : 1);
          final storedRight = _storedRightForPhysicalSide(settings, right);
          if (storedRight) {
            _rightColumnWidthDrag =
                ((_rightColumnWidthDrag ?? settings.desktopPanelWidth) + delta)
                    .clamp(200.0, 480.0);
          } else {
            _leftColumnWidthDrag =
                ((_leftColumnWidthDrag ?? settings.desktopToolPanelWidth) +
                        delta)
                    .clamp(200.0, 480.0);
          }
        }),
        onHorizontalDragEnd: (_) {
          final storedRight = _storedRightForPhysicalSide(settings, right);
          if (storedRight) {
            final width = _rightColumnWidthDrag;
            if (width != null) settings.setDesktopPanelWidth(width);
            setState(() => _rightColumnWidthDrag = null);
          } else {
            final width = _leftColumnWidthDrag;
            if (width != null) settings.setDesktopToolPanelWidth(width);
            setState(() => _leftColumnWidthDrag = null);
          }
        },
        child: SizedBox(
          width: 18,
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _window(
    SettingsService settings,
    CanvasDockPanel panel, {
    required bool right,
    double? fittedBodyHeight,
    bool automaticallyCollapsed = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final height =
        fittedBodyHeight ??
        _resizingHeight[panel] ??
        settings.desktopDockHeight(panel);
    final collapsed =
        settings.isDesktopDockCollapsed(panel) || automaticallyCollapsed;
    final foldsLeft = !right;
    return Listener(
      onPointerDown: (_) => _rememberDockInteraction(panel),
      child: SizedBox(
        // Only the whole column has an independent width.
        width: collapsed ? 52 : double.infinity,
        child: DragTarget<CanvasDockPanel>(
          key: ValueKey('pcPreviewDrop-${panel.name}'),
          onWillAcceptWithDetails: (details) => details.data != panel,
          onAcceptWithDetails: (details) => settings.moveDesktopDockPanel(
            details.data,
            toRight: _storedRightForPhysicalSide(settings, right),
            before: panel,
          ),
          builder: (context, candidates, _) => Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(
                color: candidates.isNotEmpty
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
            child: collapsed
                ? SizedBox(
                    height: 48,
                    child: Draggable<CanvasDockPanel>(
                      key: ValueKey('pcPreviewCollapsedDrag-${panel.name}'),
                      data: panel,
                      onDragStarted: () => _setDockDragging(true),
                      onDragEnd: (_) => _setDockDragging(false),
                      feedback: Material(
                        color: scheme.surfaceContainerHighest,
                        elevation: 4,
                        child: SizedBox(
                          width: 52,
                          height: 48,
                          child: Icon(switch (panel) {
                            CanvasDockPanel.brush => Icons.brush_outlined,
                            CanvasDockPanel.colorPicker =>
                              Icons.palette_outlined,
                            CanvasDockPanel.layer => Icons.layers_outlined,
                            CanvasDockPanel.canvasPreview => Icons.map_outlined,
                            _ => Icons.tune_outlined,
                          }, size: 24),
                        ),
                      ),
                      childWhenDragging: const SizedBox(width: 52, height: 48),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: IconButton(
                          key: ValueKey('pcPreviewExpand-${panel.name}'),
                          tooltip:
                              '${widget.labelOf(panel)} · ${AppLocalizations.of(context)!.filterPanelExpand}',
                          icon: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                switch (panel) {
                                  CanvasDockPanel.brush => Icons.brush_outlined,
                                  CanvasDockPanel.colorPicker =>
                                    Icons.palette_outlined,
                                  CanvasDockPanel.layer =>
                                    Icons.layers_outlined,
                                  CanvasDockPanel.canvasPreview =>
                                    Icons.map_outlined,
                                  _ => Icons.tune_outlined,
                                },
                                size: 18,
                                color: scheme.onSurface,
                              ),
                              Icon(
                                foldsLeft
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                                size: 13,
                                color: scheme.onSurface,
                              ),
                            ],
                          ),
                          onPressed: () => _expandDock(panel, settings),
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 34,
                        child: Row(
                          children: [
                            Draggable<CanvasDockPanel>(
                              data: panel,
                              onDragStarted: () => _setDockDragging(true),
                              onDragEnd: (_) => _setDockDragging(false),
                              feedback: Material(
                                color: scheme.surfaceContainerHighest,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(widget.labelOf(panel)),
                                ),
                              ),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: SizedBox(
                                  key: ValueKey('pcPreviewDrag-${panel.name}'),
                                  width: 36,
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 20,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.labelOf(panel),
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              key: ValueKey('pcPreviewCollapse-${panel.name}'),
                              tooltip: AppLocalizations.of(
                                context,
                              )!.filterPanelCollapse,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => _collapseDock(panel, settings),
                              icon: Icon(
                                foldsLeft
                                    ? Icons.chevron_left
                                    : Icons.chevron_right,
                                size: 22,
                                color: scheme.onSurface,
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: ValueKey('pcPreviewMenu-${panel.name}'),
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: scheme.onSurface,
                              ),
                              onSelected: (action) {
                                if (action == 'hide') {
                                  _toggleVisible(settings, panel);
                                } else {
                                  settings.moveDesktopDockPanel(
                                    panel,
                                    toRight: _storedRightForPhysicalSide(
                                      settings,
                                      action == 'right',
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) {
                                final l = AppLocalizations.of(context)!;
                                return [
                                  PopupMenuItem(
                                    value: 'left',
                                    child: Text(
                                      l.pcWorkspaceLayoutToolOrderSection,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'right',
                                    child: Text(
                                      l.pcWorkspaceLayoutRightOrderSection,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'hide',
                                    child: Text(l.commonClose),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: height,
                        child: _windowContents(panel, scheme),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          key: ValueKey('pcPreviewHeight-${panel.name}'),
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) => setState(() {
                            _resizingHeight[panel] =
                                ((_resizingHeight[panel] ??
                                            settings.desktopDockHeight(panel)) +
                                        details.delta.dy)
                                    .clamp(140.0, 700.0);
                          }),
                          onVerticalDragEnd: (_) {
                            final newHeight = _resizingHeight[panel];
                            if (newHeight != null) {
                              settings.setDesktopDockHeight(panel, newHeight);
                              setState(() => _resizingHeight.remove(panel));
                            }
                          },
                          child: SizedBox(
                            height: 22,
                            child: Center(
                              child: Icon(
                                Icons.drag_handle,
                                size: 24,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _windowContents(CanvasDockPanel panel, ColorScheme scheme) {
    if (panel == CanvasDockPanel.canvasPreview) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: scheme.primaryContainer),
          ),
        ),
      );
    }
    if (panel == CanvasDockPanel.layer) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 8,
                      color: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Center(
      child: Icon(
        panel == CanvasDockPanel.colorPicker
            ? Icons.palette_outlined
            : panel == CanvasDockPanel.brush
            ? Icons.brush_outlined
            : Icons.tune_outlined,
        size: 48,
        color: scheme.primary,
      ),
    );
  }

  Widget _canvasAndFrames(ColorScheme scheme) {
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: scheme.surfaceContainerLow,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 58,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 8),
                for (var i = 0; i < 6; i++)
                  Container(
                    width: 48,
                    height: 42,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      border: Border.all(
                        color: i == 0 ? scheme.primary : scheme.outlineVariant,
                        width: i == 0 ? 2 : 1,
                      ),
                    ),
                  ),
                Icon(Icons.add, color: scheme.onSurface),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
