import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/brush_service.dart';
import '../../../services/tone_service.dart';
import '../../../services/stamp_service.dart';
import '../../../models/stamp.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../canvas_screen.dart';
import '../../../config/font_fallback.dart';

/// ペンツール長押し・上スワイプで表示されるサブツールタブUI
/// ブラシ / トーン / スタンプ
/// （投げ縄塗りは、投げ縄で囲った範囲を塗る点でバケツ塗りに近い性質を
/// 持つため、ペンのサブツールからバケツ長押しメニューへ移した）。
class PenSubToolPanel extends StatefulWidget {
  final DrawingTool currentTool;
  final PenSubTool currentSubTool;
  final ValueChanged<PenSubTool> onSubToolSelected;
  final VoidCallback onClose;
  // ブラシ/トーン/スタンプの全機能管理パネル（フォルダ・自作・検索・
  // 読み込み書き出し）を開く。現在表示中のタブに応じて呼び出し側で
  // 対象を判断する。
  final void Function(PenSubTool subTool)? onManage;

  const PenSubToolPanel({
    super.key,
    required this.currentTool,
    required this.currentSubTool,
    required this.onSubToolSelected,
    required this.onClose,
    this.onManage,
  });

  @override
  State<PenSubToolPanel> createState() => _PenSubToolPanelState();
}

class _PenSubToolPanelState extends State<PenSubToolPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = switch (widget.currentSubTool) {
      PenSubTool.brush => 0,
      PenSubTool.tone => 1,
      PenSubTool.stamp => 2,
      // 投げ縄塗り選択中にペンサブツールパネルが開かれることはない
      // （投げ縄塗りはバケツ長押しメニューから選ぶため）が、念のため
      // ブラシタブへフォールバックする。
      PenSubTool.lassoFill => 0,
    };
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    // TabControllerのindex変化をonSubToolSelectedに通知
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final subTool = switch (_tabController.index) {
      0 => PenSubTool.brush,
      1 => PenSubTool.tone,
      2 => PenSubTool.stamp,
      _ => PenSubTool.brush,
    };
    widget.onSubToolSelected(subTool);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        height: 480,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: const TextStyle(fontSize: 11),
                    // 各サブツールタブの初回使用時に吹き出し説明を表示する
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
                // フォルダ管理・自作・検索・読み込み書き出し等のフル機能パネルを開く。
                if (widget.onManage != null)
                  IconButton(
                    icon: const Icon(Icons.tune, size: 16),
                    tooltip: l10n.penSubToolManageTooltip,
                    onPressed: () {
                      final subTool = switch (_tabController.index) {
                        0 => PenSubTool.brush,
                        1 => PenSubTool.tone,
                        2 => PenSubTool.stamp,
                        _ => PenSubTool.brush,
                      };
                      widget.onManage!(subTool);
                    },
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BrushTab(onClose: widget.onClose),
                  _ToneTab(onClose: widget.onClose),
                  _StampTab(onClose: widget.onClose),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ブラシタブ
class _BrushTab extends StatelessWidget {
  final VoidCallback onClose;
  const _BrushTab({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brushService = context.watch<BrushService>();
    final brushes = brushService.brushes;
    final current = brushService.currentBrush;

    return ListView.builder(
      itemCount: brushes.length,
      itemBuilder: (context, index) {
        final brush = brushes[index];
        final isSelected = current?.id == brush.id;
        return ListTile(
          dense: true,
          selected: isSelected,
          leading: Icon(
            Icons.brush,
            size: 16,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(
            brush.name,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          subtitle: Text(
            l10n.penSubToolBrushSizeOpacity(brush.size.round(), brush.opacity),
            style: const TextStyle(fontSize: 10),
          ),
          trailing: GestureDetector(
            onTap: () => brushService.toggleFavoriteBrush(brush.id),
            child: Icon(
              brush.isFavorite ? Icons.star : Icons.star_outline,
              size: 14,
              color: brush.isFavorite ? ThemeService.activeColorScheme.tertiary : ThemeService.activeColorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () {
            brushService.selectBrush(brush.id);
            onClose();
          },
        );
      },
    );
  }
}

/// トーンタブ
class _ToneTab extends StatelessWidget {
  final VoidCallback onClose;
  const _ToneTab({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final toneService = context.watch<ToneService>();
    final tones = toneService.tones;
    final current = toneService.currentTone;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: tones.length,
      itemBuilder: (context, index) {
        final tone = tones[index];
        final isSelected = current?.id == tone.id;
        return GestureDetector(
          onTap: () {
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
                const Icon(Icons.grid_on, size: 20),
                const SizedBox(height: 2),
                Text(
                  tone.name,
                  style: const TextStyle(
                    fontSize: 8,
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
    );
  }
}

/// スタンプタブ
class _StampTab extends StatelessWidget {
  final VoidCallback onClose;
  const _StampTab({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final stampService = context.watch<StampService>();
    final stamps = stampService.stamps;
    final current = stampService.currentStamp;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: stamps.length,
      itemBuilder: (context, index) {
        final stamp = stamps[index];
        final isSelected = current?.id == stamp.id;
        final builtIn = stampService.isBuiltIn(stamp.id);
        return GestureDetector(
          onTap: () {
            stampService.selectStamp(stamp.id);
            onClose();
          },
          // 組み込みスタンプはStampService側で編集不可なので、
          // 保存できたように見える偽の編集経路を出さない。複製後は編集可能。
          onLongPress: builtIn
              ? null
              : () => _showStampSettingsDialog(context, stampService, stamp),
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
                const Icon(Icons.star, size: 20),
                const SizedBox(height: 2),
                Text(
                  stamp.name,
                  style: const TextStyle(
                    fontSize: 8,
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
    );
  }

  /// スタンプ設定ダイアログ（回転ON/OFF・密度・散布）
  void _showStampSettingsDialog(
    BuildContext context,
    StampService service,
    Stamp stamp,
  ) {
    final l10n = AppLocalizations.of(context)!;
    bool rotation = stamp.rotation;
    int opacity = stamp.opacity;
    double density = stamp.density;
    double scatter = stamp.scatter;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(stamp.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                dense: true,
                title: Text(l10n.stampRotationLabel),
                subtitle: Text(
                  l10n.penSubToolStampRotationSubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                value: rotation,
                onChanged: (v) => setS(() => rotation = v),
              ),
              Row(
                children: [
                  Text(
                    l10n.brushSettingsOpacityLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: SteppedSlider(
                      value: opacity.toDouble(),
                      min: 1,
                      max: 100,
                      step: 1,
                      label: '$opacity%',
                      onChanged: (v) => setS(() => opacity = v.round()),
                    ),
                  ),
                  EditableSliderValue(
                    text: '$opacity%',
                    style: const TextStyle(fontSize: 12),
                    value: opacity.toDouble(),
                    min: 1,
                    max: 100,
                    isInt: true,
                    onChanged: (v) => setS(() => opacity = v.round()),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    l10n.stampDensityLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: SteppedSlider(
                      value: density.clamp(0.1, 5.0),
                      min: 0.1,
                      max: 5.0,
                      step: 0.1,
                      label: density.toStringAsFixed(1),
                      onChanged: (v) => setS(() => density = v),
                    ),
                  ),
                  EditableSliderValue(
                    text: density.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12),
                    value: density,
                    min: 0.1,
                    max: 5.0,
                    onChanged: (v) => setS(() => density = v.toDouble()),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    l10n.stampScatterLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: SteppedSlider(
                      value: scatter,
                      min: 0,
                      max: 1.0,
                      step: 0.01,
                      label: '${(scatter * 100).round()}%',
                      onChanged: (v) => setS(() => scatter = v),
                    ),
                  ),
                  EditableSliderValue(
                    text: '${(scatter * 100).round()}%',
                    style: const TextStyle(fontSize: 12),
                    value: (scatter * 100).round(),
                    min: 0,
                    max: 100,
                    onChanged: (v) => setS(() => scatter = v / 100.0),
                  ),
                ],
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
                service.updateStamp(
                  stamp.copyWith(
                    rotation: rotation,
                    opacity: opacity,
                    density: density,
                    scatter: scatter,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            l10n.toolbarBucketToneListLabel,
            style: TextStyle(fontSize: 11, color: ThemeService.activeColorScheme.onSurfaceVariant),
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
