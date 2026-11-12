import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/brush_service.dart';
import '../../../services/tone_service.dart';
import '../../../services/theme_service.dart';
import '../../../config/font_fallback.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../canvas_screen.dart';
import 'brush_panel.dart';
import 'tone_panel.dart';
import 'stamp_panel.dart';

/// The ONLY entry point for pen subtools and their catalogue management.
/// Each tab hosts the actual full-featured management panel, not a duplicate
/// quick list. Favourites, search, folder management, create/import/export,
/// rename/edit/duplicate/delete, and drag handles remain fully operational.
class PenSubToolPanel extends StatefulWidget {
  final DrawingTool currentTool;
  final PenSubTool currentSubTool;
  final ValueChanged<PenSubTool> onSubToolSelected;
  final VoidCallback onClose;
  final Future<int?> Function()? onEyedropOutlineColor;

  /// Old caller compatibility; selection and editing no longer open a
  /// different management panel. All actions live inside these three tabs.
  final void Function(PenSubTool subTool)? onManage;

  const PenSubToolPanel({
    super.key,
    required this.currentTool,
    required this.currentSubTool,
    required this.onSubToolSelected,
    required this.onClose,
    this.onEyedropOutlineColor,
    this.onManage,
  });

  @override
  State<PenSubToolPanel> createState() => _PenSubToolPanelState();
}

class _PenSubToolPanelState extends State<PenSubToolPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int _index(PenSubTool tool) => switch (tool) {
    PenSubTool.brush => 0,
    PenSubTool.tone => 1,
    PenSubTool.stamp => 2,
    PenSubTool.lassoFill => 0,
  };

  PenSubTool _subTool(int index) => switch (index) {
    1 => PenSubTool.tone,
    2 => PenSubTool.stamp,
    _ => PenSubTool.brush,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: _index(widget.currentSubTool),
    )..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant PenSubToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSubTool != widget.currentSubTool) {
      final index = _index(widget.currentSubTool);
      if (_tabs.index != index) _tabs.animateTo(index);
    }
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    widget.onSubToolSelected(_subTool(_tabs.index));
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final availableHeight = MediaQuery.sizeOf(context).height;
    // Full catalogue panels need more vertical room than the former quick
    // list. Parent dock viewports retain their own scrolling/collapse rules.
    final panelHeight = math.min(540.0, math.max(290.0, availableHeight - 70));
    return PanelSurface(
      width: 280,
      height: panelHeight,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  labelStyle: const TextStyle(fontSize: 11),
                  tabs: [
                    Tab(text: l10n.penSubToolTabBrush),
                    FirstUseTooltip(
                      tooltipKey: 'pen_subtool_tone',
                      message: l10n.penSubToolToneTooltipMessage,
                      child: Tab(text: l10n.penSubToolTabTone),
                    ),
                    FirstUseTooltip(
                      tooltipKey: 'pen_subtool_stamp',
                      message: l10n.penSubToolStampTooltipMessage,
                      child: Tab(text: l10n.penSubToolTabStamp),
                    ),
                  ],
                ),
              ),
              if (!DockedPanelScope.of(context))
                IconButton(
                  tooltip: l10n.commonClose,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => BrushPanel(
                    embedded: true,
                    embeddedHeight: constraints.maxHeight,
                    dockedMode: true,
                    onEyedropOutlineColor: widget.onEyedropOutlineColor,
                    onClose: widget.onClose,
                    onPresetSelected: () => widget.onSubToolSelected(
                      PenSubTool.brush,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => TonePanel(
                    embedded: true,
                    embeddedHeight: constraints.maxHeight,
                    onClose: widget.onClose,
                    onPresetSelected: () => widget.onSubToolSelected(
                      PenSubTool.tone,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => StampPanel(
                    embedded: true,
                    embeddedHeight: constraints.maxHeight,
                    onClose: widget.onClose,
                    onPresetSelected: () => widget.onSubToolSelected(
                      PenSubTool.stamp,
                    ),
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

/// 投げ縄塗りの塗りつぶし方選択（ベタ塗り／トーン一覧）。バケツ長押し
/// メニューから「投げ縄塗り」を選んだ直後に表示するボトムシートとして使う。
class LassoFillToneSheet extends StatelessWidget {
  final VoidCallback onClose;
  const LassoFillToneSheet({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final toneService = context.watch<ToneService>();
    final tones = toneService.tones;
    final lastLassoTone = toneService.lastLassoTone;
    final useTone = toneService.lassoUseTone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ベタ塗りボタン（一番上）
        ListTile(
          dense: true,
          leading: const Icon(Icons.format_color_fill, size: 18),
          title: Text(
            l10n.toolbarBucketFlatFill,
            style: const TextStyle(fontSize: 13),
          ),
          selected: !useTone,
          onTap: () {
            toneService.setLassoUseTone(false);
            onClose();
          },
        ),
        const Divider(height: 1),
        // トーン一覧
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            l10n.toolbarBucketToneListLabel,
            style: TextStyle(
              fontSize: 11,
              color: ThemeService.activeColorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: tones.length,
            itemBuilder: (context, index) {
              final tone = tones[index];
              final isSelected = useTone && lastLassoTone?.id == tone.id;
              return GestureDetector(
                onTap: () {
                  toneService.setLassoUseTone(true);
                  toneService.setLastLassoTone(tone);
                  toneService.selectTone(tone.id);
                  onClose();
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : ThemeService.activeColorScheme.onSurfaceVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: ThemeService.activeColorScheme.onSurfaceVariant,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_on, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        tone.name,
                        style: const TextStyle(
                          fontSize: 7,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum PenSubTool { brush, tone, stamp, lassoFill }
