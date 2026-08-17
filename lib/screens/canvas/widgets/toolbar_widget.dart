import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/toolbar_item.dart';
import '../../../services/settings_service.dart';
import '../../../services/tone_service.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../canvas_screen.dart';

class ToolbarWidget extends StatelessWidget {
  final DrawingTool currentTool;
  final Color currentColor;
  final ValueChanged<DrawingTool> onToolSelected;
  final VoidCallback onColorTap;
  final VoidCallback onBrushTap;
  final VoidCallback onLayerTap;
  final VoidCallback onPenLongPress;
  final VoidCallback onTextTap;
  final VoidCallback onShapeTap;
  final VoidCallback onQuickToolTap;
  final VoidCallback onQuickToolLongPress;
  // 手動保存（セーブツリー）：仕様書10「キャンバス → 保存 → キャンバスへ戻る」
  final VoidCallback onSaveTap;
  // スタンプ選択中かどうか（仕様書17：色アイコンに🚫重ね表示・タップで専用トースト）
  final bool isStampSelected;

  const ToolbarWidget({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.onToolSelected,
    required this.onColorTap,
    required this.onBrushTap,
    required this.onLayerTap,
    required this.onPenLongPress,
    required this.onTextTap,
    required this.onShapeTap,
    required this.onQuickToolTap,
    required this.onQuickToolLongPress,
    required this.onSaveTap,
    this.isStampSelected = false,
  });

  /// ツールバー編集（仕様書08）でカスタマイズ可能な項目を、現在の並び順・
  /// 表示設定に従って構築する。
  Widget _buildToolItem(BuildContext context, AppLocalizations l10n, ToolbarItemId id) {
    return switch (id) {
      // ペンボタン：長押しでサブツールパネル表示（仕様書02・17：初回使用時の吹き出し説明）
      ToolbarItemId.pen => FirstUseTooltip(
          tooltipKey: 'pen_tool',
          message: l10n.toolbarPenFirstUseTip,
          child: GestureDetector(
            onLongPress: onPenLongPress,
            child: _toolButton(context, Icons.brush, DrawingTool.pen, l10n.toolbarPenTooltip),
          ),
        ),
      // 消しゴム用のアイコン（ユーザー指示により新規変更：以前使っていた
      // crop_square（四角形の枠）は選択ツール側へ移し、消しゴムには
      // 見た目でそれと分かる専用アイコンを割り当てる）。
      ToolbarItemId.eraser => _toolButton(context, Icons.backspace_outlined, DrawingTool.eraser, l10n.toolbarItemEraser),
      // バケツボタン：長押しでベタ塗り／トーン切り替えメニュー表示（仕様書04・17）
      ToolbarItemId.bucket => FirstUseTooltip(
          tooltipKey: 'bucket_tool',
          message: l10n.toolbarBucketFirstUseTip,
          child: GestureDetector(
            onLongPress: () => _showBucketToneMenu(context),
            child: _toolButton(context, Icons.format_color_fill, DrawingTool.bucket, l10n.toolbarBucketTooltip),
          ),
        ),
      ToolbarItemId.eyedropper => _toolButton(context, Icons.colorize, DrawingTool.eyedropper, l10n.toolbarItemEyedropper),
      ToolbarItemId.finger => _toolButton(context, Icons.back_hand, DrawingTool.finger, l10n.toolbarItemFinger),
      ToolbarItemId.select => _selectToolButton(context, l10n),
      ToolbarItemId.transform => _toolButton(context, Icons.transform, DrawingTool.transform, l10n.toolbarItemTransform),
      // 初回タップ時の吹き出し説明（仕様書15）
      ToolbarItemId.text => FirstUseTooltip(
          tooltipKey: 'text_tool',
          message: l10n.toolbarTextFirstUseTip,
          child: _toolButton(context, Icons.text_fields, DrawingTool.text, l10n.toolbarItemText, onTap: onTextTap),
        ),
      ToolbarItemId.shape =>
        _toolButton(context, Icons.category, DrawingTool.shape, l10n.toolbarShapeTooltip, onTap: onShapeTap),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ツールバー編集（仕様書08）でカスタマイズ可能な項目を並び順・表示設定通りに表示
            for (final id in settings.toolbarOrder)
              if (!settings.hiddenToolbarItems.contains(id)) _buildToolItem(context, l10n, id),
            const SizedBox(width: 4),
            // 色インジケーター（仕様書17：スタンプ選択中は色情報を保持しているため
            // 色変更不可を🚫重ね表示で示し、タップで専用トーストを表示する）
            GestureDetector(
              onTap: isStampSelected
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.toolbarStampColorLockedSnackbar)),
                      )
                  : onColorTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  if (isStampSelected)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.block, color: Colors.red, size: 20),
                    ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.tune, size: 20), onPressed: onBrushTap, tooltip: l10n.toolbarBrushSettingsTooltip),
            IconButton(icon: const Icon(Icons.layers, size: 20), onPressed: onLayerTap, tooltip: l10n.toolbarLayerTooltip),
            // オニオンスキンは仕様書08・タスク#95によりここから削除し、
            // キャンバス上部バーの「設定/編集」メニューへ集約した。
            // ツール早替えボタン（↺）
            // ツール早替えボタン：タップで登録順に切替、長押しまたは上スワイプで
            // 管理ポップアップ（登録・並び替え）を表示（仕様書02・08）
            FirstUseTooltip(
              tooltipKey: 'quick_tool',
              message: l10n.toolbarQuickToolFirstUseTip,
              child: GestureDetector(
                onLongPress: onQuickToolLongPress,
                onVerticalDragEnd: (details) {
                  // 上方向への素早いスワイプで長押しと同じ編集ポップアップを開く
                  // （primaryVelocityは下向き正・上向き負）。
                  if ((details.primaryVelocity ?? 0) < -200) {
                    onQuickToolLongPress();
                  }
                },
                child: IconButton(
                  icon: const Icon(Icons.loop, size: 20),
                  onPressed: onQuickToolTap,
                  tooltip: l10n.toolbarQuickToolTooltip,
                ),
              ),
            ),
            // タイムラインへの切替ボタンは仕様書08・タスク#95によりここから
            // 削除し、フレーム一覧右下のボタン（frame_strip_widget.dart）
            // へ統一した（同じ役割のボタンが2箇所にあり冗長だったため）。
            // 手動保存（セーブツリー）：仕様書10「キャンバス → 保存 → キャンバスへ戻る」
            IconButton(icon: const Icon(Icons.save_outlined, size: 20), onPressed: onSaveTap, tooltip: l10n.toolbarSaveTooltip),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(BuildContext context, IconData icon, DrawingTool tool, String tooltip,
      {VoidCallback? onTap}) {
    final isSelected = currentTool == tool;
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onTap ?? () => onToolSelected(tool),
      tooltip: tooltip,
      color: isSelected ? primary : null,
      style: isSelected ? IconButton.styleFrom(backgroundColor: primary.withValues(alpha: 0.15)) : null,
    );
  }

  Widget _selectToolButton(BuildContext context, AppLocalizations l10n) {
    final isSelected = currentTool == DrawingTool.selectRect ||
        currentTool == DrawingTool.selectLasso ||
        currentTool == DrawingTool.selectMagicWand;
    // 矩形選択（デフォルト）には、以前消しゴムに使っていたcrop_square
    // （四角形の枠）を移す（ユーザー指示：矩形選択の見た目に合っている
    // ため。消しゴムには専用のink_eraserアイコンを新たに割り当てた）。
    final icon = switch (currentTool) {
      DrawingTool.selectLasso => Icons.gesture,
      DrawingTool.selectMagicWand => Icons.auto_awesome,
      _ => Icons.crop_square,
    };
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPress: () => _showSelectMenu(context, l10n),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: () => onToolSelected(DrawingTool.selectRect),
        tooltip: l10n.toolbarSelectTooltip,
        color: isSelected ? primary : null,
        style: isSelected ? IconButton.styleFrom(backgroundColor: primary.withValues(alpha: 0.15)) : null,
      ),
    );
  }

  /// バケツツールのベタ塗り／トーン切り替えメニュー（仕様書04・17）。
  void _showBucketToneMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer<ToneService>(
        builder: (ctx, toneService, _) {
          final tones = toneService.tones;
          final useTone = toneService.bucketUseTone;
          final lastBucketTone = toneService.lastBucketTone;
          return SafeArea(
            child: SizedBox(
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.format_color_fill, size: 18),
                    title: Text(l10n.toolbarBucketFlatFill, style: const TextStyle(fontSize: 13)),
                    selected: !useTone,
                    onTap: () {
                      toneService.setBucketUseTone(false);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(l10n.toolbarBucketToneListLabel, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
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
                        final isSelected = useTone && lastBucketTone?.id == tone.id;
                        return GestureDetector(
                          onTap: () {
                            toneService.setBucketUseTone(true);
                            toneService.setLastBucketTone(tone);
                            Navigator.pop(ctx);
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSelectMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.auto_fix_high), title: Text(l10n.toolbarSelectRect), onTap: () { onToolSelected(DrawingTool.selectRect); Navigator.pop(ctx); }),
            ListTile(leading: const Icon(Icons.gesture), title: Text(l10n.toolbarSelectLasso), onTap: () { onToolSelected(DrawingTool.selectLasso); Navigator.pop(ctx); }),
            ListTile(leading: const Icon(Icons.auto_awesome), title: Text(l10n.toolbarSelectMagicWand), onTap: () { onToolSelected(DrawingTool.selectMagicWand); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }
}
