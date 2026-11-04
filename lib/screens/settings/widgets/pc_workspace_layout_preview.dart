import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/canvas_dock_panel.dart';
import '../../../services/settings_service.dart';

/// A live, interactive representation of the desktop canvas docking layout.
///
/// The preview uses the same SettingsService lists, visibility preferences and
/// per-window dimensions as CanvasScreen. Nothing is stored separately.
/// Drag a window's grip to reorder or move it between columns; drag its right
/// or left edge and bottom edge to resize it. Pinch/zoom the whole workspace.
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
  final Map<CanvasDockPanel, double> _resizingWidth = {};
  final Map<CanvasDockPanel, double> _resizingHeight = {};
  Size? _lastViewportSize;
  double? _leftColumnWidthDrag;
  double? _rightColumnWidthDrag;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    final widthScale = viewport.width / workspaceWidth;
    final heightScale = viewport.height / workspaceHeight;
    final scale = (widthScale < heightScale ? widthScale : heightScale)
        .clamp(0.25, 1.0);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _toggleVisible(SettingsService settings, CanvasDockPanel panel) {
    final next = Set<CanvasDockPanel>.of(settings.defaultDockedPanels);
    if (!next.add(panel)) next.remove(panel);
    settings.setDefaultDockedPanels(next);
  }

  double _columnWidth(SettingsService settings, {required bool right}) {
    final order =
        right ? settings.rightDockOrder : settings.toolOptionDockOrder;
    double width = right
        ? (_rightColumnWidthDrag ?? settings.desktopPanelWidth)
        : (_leftColumnWidthDrag ?? settings.desktopToolPanelWidth);
    for (final panel in order) {
      if (!settings.defaultDockedPanels.contains(panel)) continue;
      final panelWidth = _resizingWidth[panel] ??
          settings.desktopDockWidth(panel, right: right);
      if (panelWidth > width) width = panelWidth;
    }
    return width;
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
                                  _toolbar(scheme),
                                  _column(settings, right: false),
                                  _columnResizeGrip(settings, right: false),
                                  Expanded(child: _canvasAndFrames(scheme)),
                                  _columnResizeGrip(settings, right: true),
                                  _column(settings, right: true),
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

  Widget _topBar(SettingsService settings, AppLocalizations l, ColorScheme scheme) {
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
          Text(l.pcWorkspaceLayoutScreenTitle,
              style: TextStyle(color: scheme.onSurface, fontSize: 14)),
          const Spacer(),
          PopupMenuButton<CanvasDockPanel>(
            key: const Key('pcWorkspacePreviewVisibilityMenu'),
            tooltip: l.workspaceDockPanelSection,
            icon: Icon(Icons.view_sidebar_outlined, color: scheme.onSurface),
            onSelected: (panel) => _toggleVisible(settings, panel),
            itemBuilder: (_) => [
              for (final panel in CanvasDockPanel.values)
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
    return Container(
      width: 52,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
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
    final order = right ? settings.rightDockOrder : settings.toolOptionDockOrder;
    final visible = order.where(settings.defaultDockedPanels.contains).toList();
    return SizedBox(
      width: _columnWidth(settings, right: right),
      child: DragTarget<CanvasDockPanel>(
        key: ValueKey(right ? 'pcPreviewRightColumn' : 'pcPreviewToolColumn'),
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) =>
            settings.moveDesktopDockPanel(details.data, toRight: right),
        builder: (context, candidates, _) => ColoredBox(
          color: candidates.isEmpty ? scheme.surface : scheme.primaryContainer,
          child: ListView(
            children: [
              for (final panel in visible)
                Align(
                  alignment:
                      right ? Alignment.centerRight : Alignment.centerLeft,
                  child: _window(settings, panel, right: right),
                ),
            ],
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
        key: ValueKey(right ? 'pcPreviewRightColumnResize' : 'pcPreviewToolColumnResize'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => setState(() {
          final delta = details.delta.dx * (right ? -1 : 1);
          if (right) {
            _rightColumnWidthDrag =
                ((_rightColumnWidthDrag ?? settings.desktopPanelWidth) + delta)
                    .clamp(200.0, 480.0);
          } else {
            _leftColumnWidthDrag =
                ((_leftColumnWidthDrag ?? settings.desktopToolPanelWidth) + delta)
                    .clamp(200.0, 480.0);
          }
        }),
        onHorizontalDragEnd: (_) {
          if (right) {
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
          width: 10,
          child: Center(
            child: Container(width: 3, color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _window(
    SettingsService settings,
    CanvasDockPanel panel, {
    required bool right,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final width = _resizingWidth[panel] ??
        settings.desktopDockWidth(panel, right: right);
    final height = _resizingHeight[panel] ?? settings.desktopDockHeight(panel);
    return SizedBox(
      width: width,
      child: DragTarget<CanvasDockPanel>(
        key: ValueKey('pcPreviewDrop-${panel.name}'),
        onWillAcceptWithDetails: (details) => details.data != panel,
        onAcceptWithDetails: (details) => settings.moveDesktopDockPanel(
          details.data,
          toRight: right,
          before: panel,
        ),
        builder: (context, candidates, _) => Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(
              color: candidates.isNotEmpty ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: Row(
                  children: [
                    LongPressDraggable<CanvasDockPanel>(
                      data: panel,
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
                        style: TextStyle(color: scheme.onSurface, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey('pcPreviewMenu-${panel.name}'),
                      icon: Icon(Icons.more_vert, size: 18, color: scheme.onSurface),
                      onSelected: (action) {
                        if (action == 'hide') {
                          _toggleVisible(settings, panel);
                        } else {
                          settings.moveDesktopDockPanel(
                            panel,
                            toRight: action == 'right',
                          );
                        }
                      },
                      itemBuilder: (context) {
                        final l = AppLocalizations.of(context)!;
                        return [
                          PopupMenuItem(
                            value: 'left',
                            child: Text(l.pcWorkspaceLayoutToolOrderSection),
                          ),
                          PopupMenuItem(
                            value: 'right',
                            child: Text(l.pcWorkspaceLayoutRightOrderSection),
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
                child: Stack(
                  children: [
                    Positioned.fill(
                      left: right ? 12 : 0,
                      right: right ? 0 : 12,
                      child: _windowContents(panel, scheme),
                    ),
                    Positioned(
                      left: right ? 0 : null,
                      right: right ? null : 0,
                      top: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          key: ValueKey('pcPreviewWidth-${panel.name}'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) => setState(() {
                            _resizingWidth[panel] = ((_resizingWidth[panel] ??
                                    settings.desktopDockWidth(panel, right: right)) +
                                details.delta.dx * (right ? -1 : 1))
                                .clamp(200.0, 480.0);
                          }),
                          onHorizontalDragEnd: (_) {
                            final newWidth = _resizingWidth[panel];
                            if (newWidth != null) {
                              settings.setDesktopDockWidth(panel, newWidth);
                              setState(() => _resizingWidth.remove(panel));
                            }
                          },
                          child: SizedBox(
                            width: 12,
                            child: Center(
                              child: Container(
                                  width: 3, color: scheme.outlineVariant),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  key: ValueKey('pcPreviewHeight-${panel.name}'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) => setState(() {
                    _resizingHeight[panel] =
                        ((_resizingHeight[panel] ?? settings.desktopDockHeight(panel)) +
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
                    height: 16,
                    child: Center(
                      child: Icon(Icons.drag_handle,
                          size: 20, color: scheme.outline),
                    ),
                  ),
                ),
              ),
            ],
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
                  Icon(Icons.layers_outlined,
                      size: 18, color: scheme.onSurface),
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
