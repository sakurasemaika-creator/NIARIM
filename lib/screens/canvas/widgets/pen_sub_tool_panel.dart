import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/brush_service.dart';
import '../../../services/tone_service.dart';
import '../../../services/stamp_service.dart';
import '../../../models/stamp.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../canvas_screen.dart';

/// ペンツール長押し・上スワイプで表示されるサブツールタブUI
/// ブラシ / トーン / スタンプ / 投げ縄塗り
class PenSubToolPanel extends StatefulWidget {
  final DrawingTool currentTool;
  final PenSubTool currentSubTool;
  final ValueChanged<PenSubTool> onSubToolSelected;
  final VoidCallback onClose;

  const PenSubToolPanel({
    super.key,
    required this.currentTool,
    required this.currentSubTool,
    required this.onSubToolSelected,
    required this.onClose,
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
      PenSubTool.lassoFill => 3,
    };
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    // TabControllerのindex変化をonSubToolSelectedに通知
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final subTool = switch (_tabController.index) {
      0 => PenSubTool.brush,
      1 => PenSubTool.tone,
      2 => PenSubTool.stamp,
      3 => PenSubTool.lassoFill,
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
    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        height: 480,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontSize: 11),
              // 各サブツールタブの初回使用時に吹き出し説明を表示する（仕様書02・11）
              tabs: [
                const Tab(text: 'ブラシ'),
                FirstUseTooltip(
                  tooltipKey: 'pen_subtool_tone',
                  message: 'トーンを選ぶと、バケツやペンでアミトーン柄を塗れます。',
                  child: const Tab(text: 'トーン'),
                ),
                FirstUseTooltip(
                  tooltipKey: 'pen_subtool_stamp',
                  message: '決まった形のスタンプを配置できます。長押しで回転・密度などを設定できます。',
                  child: const Tab(text: 'スタンプ'),
                ),
                FirstUseTooltip(
                  tooltipKey: 'pen_subtool_lasso',
                  message: '投げ縄で囲んだ範囲を一括で塗りつぶせます。',
                  child: const Tab(text: '投げ縄塗り'),
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
                  _LassoFillTab(onClose: widget.onClose),
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
          leading: Icon(Icons.brush, size: 16,
              color: isSelected ? Theme.of(context).colorScheme.primary : null),
          title: Text(brush.name, style: const TextStyle(fontSize: 12)),
          subtitle: Text('${brush.size.round()}px · ${brush.opacity}%',
              style: const TextStyle(fontSize: 10)),
          trailing: GestureDetector(
            onTap: () => brushService.toggleFavoriteBrush(brush.id),
            child: Icon(
              brush.isFavorite ? Icons.star : Icons.star_outline,
              size: 14,
              color: brush.isFavorite ? Colors.amber : Colors.grey,
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
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[800],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_on, size: 20),
                const SizedBox(height: 2),
                Text(tone.name, style: const TextStyle(fontSize: 8),
                    textAlign: TextAlign.center, maxLines: 2),
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
        return GestureDetector(
          onTap: () {
            stampService.selectStamp(stamp.id);
            onClose();
          },
          // 長押しでスタンプ設定（回転・密度・散布、仕様書17）を編集
          onLongPress: () => _showStampSettingsDialog(context, stampService, stamp),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[800],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 20),
                const SizedBox(height: 2),
                Text(stamp.name, style: const TextStyle(fontSize: 8),
                    textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        );
      },
    );
  }

  /// スタンプ設定ダイアログ（仕様書17：回転ON/OFF・密度・散布）
  void _showStampSettingsDialog(BuildContext context, StampService service, Stamp stamp) {
    bool rotation = stamp.rotation;
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
                title: const Text('回転'),
                subtitle: const Text('ストローク方向に合わせてランダムに回転', style: TextStyle(fontSize: 11)),
                value: rotation,
                onChanged: (v) => setS(() => rotation = v),
              ),
              Row(
                children: [
                  const Text('密度', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: density, min: 0.1, max: 1.0,
                      label: '${(density * 100).round()}%',
                      onChanged: (v) => setS(() => density = v),
                    ),
                  ),
                  Text('${(density * 100).round()}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  const Text('散布', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: scatter, min: 0, max: 1.0,
                      label: '${(scatter * 100).round()}%',
                      onChanged: (v) => setS(() => scatter = v),
                    ),
                  ),
                  Text('${(scatter * 100).round()}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                service.updateStamp(stamp.copyWith(
                    rotation: rotation, density: density, scatter: scatter));
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 投げ縄塗りタブ
/// ベタ塗り（一番上のボタン）＋トーン一覧
class _LassoFillTab extends StatelessWidget {
  final VoidCallback onClose;
  const _LassoFillTab({required this.onClose});

  @override
  Widget build(BuildContext context) {
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
          title: const Text('ベタ塗り', style: TextStyle(fontSize: 13)),
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
          child: Text('トーン一覧', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
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
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[800],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_on, size: 16),
                      const SizedBox(height: 2),
                      Text(tone.name, style: const TextStyle(fontSize: 7),
                          textAlign: TextAlign.center, maxLines: 2),
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
