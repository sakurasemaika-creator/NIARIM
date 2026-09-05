import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/toolbar_item.dart';
import '../../../services/settings_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/tone_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../../../widgets/help_button.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/stepped_slider.dart';
import '../canvas_screen.dart';
import 'canvas_icon_button.dart';
import '../../../config/font_fallback.dart';
import 'pen_sub_tool_panel.dart' show LassoFillToneSheet;

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
  final VoidCallback onSaveTap;
  final VoidCallback onLassoFillSelected;
  final VoidCallback onFingerLongPress;
  final VoidCallback onRulerTap;
  final bool isStampSelected;
  final bool vertical;

  const ToolbarWidget({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.onToolSelected,
    required this.onColorTap,
    required this.onBrushTap,
    required this.onLayerTap,
    required this.onPenLongPress,
    required this.onFingerLongPress,
    required this.onTextTap,
    required this.onShapeTap,
    required this.onQuickToolTap,
    required this.onQuickToolLongPress,
    required this.onSaveTap,
    required this.onLassoFillSelected,
    required this.onRulerTap,
    this.isStampSelected = false,
    this.vertical = false,
  });

  Widget _buildToolItem(
    BuildContext context,
    AppLocalizations l10n,
    ToolbarItemId id,
  ) {
    return switch (id) {
      ToolbarItemId.pen => FirstUseTooltip(
        tooltipKey: 'pen_tool',
        message: l10n.toolbarPenFirstUseTip,
        child: GestureDetector(
          onLongPress: onPenLongPress,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) onPenLongPress();
          },
          child: _toolButton(
            context,
            Icons.brush,
            DrawingTool.pen,
            l10n.toolbarPenTooltip,
            longPressTooltip: false,
          ),
        ),
      ),
      ToolbarItemId.eraser => GestureDetector(
        onDoubleTap: () =>
            _showBriefDescription(context, l10n.toolbarItemEraser),
        child: CanvasIconButton(
          iconBuilder: (color) =>
              FaIcon(FontAwesomeIcons.eraser, size: 18, color: color),
          onPressed: () => onToolSelected(DrawingTool.eraser),
          tooltip: l10n.toolbarItemEraser,
          selected: currentTool == DrawingTool.eraser,
        ),
      ),
      ToolbarItemId.bucket => FirstUseTooltip(
        tooltipKey: 'bucket_tool',
        message: l10n.toolbarBucketFirstUseTip,
        child: GestureDetector(
          onLongPress: () => _showBucketToneMenu(context),
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) {
              _showBucketToneMenu(context);
            }
          },
          child: _toolButton(
            context,
            Icons.format_color_fill,
            DrawingTool.bucket,
            l10n.toolbarBucketTooltip,
            longPressTooltip: false,
          ),
        ),
      ),
      ToolbarItemId.eyedropper => _toolButton(
        context,
        Icons.colorize,
        DrawingTool.eyedropper,
        l10n.toolbarItemEyedropper,
      ),
      ToolbarItemId.finger => GestureDetector(
        onLongPress: onFingerLongPress,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -200) onFingerLongPress();
        },
        child: _toolButton(
          context,
          Icons.pan_tool_alt,
          DrawingTool.finger,
          l10n.toolbarItemFinger,
          longPressTooltip: false,
          isSelected:
              currentTool == DrawingTool.finger ||
              currentTool == DrawingTool.blur ||
              currentTool == DrawingTool.mosaic,
        ),
      ),
      ToolbarItemId.pan => _toolButton(
        context,
        Icons.back_hand,
        DrawingTool.pan,
        l10n.toolbarItemPan,
      ),
      ToolbarItemId.select => _selectToolButton(context, l10n),
      ToolbarItemId.text => FirstUseTooltip(
        tooltipKey: 'text_tool',
        message: l10n.toolbarTextFirstUseTip,
        child: _toolButton(
          context,
          Icons.text_fields,
          DrawingTool.text,
          l10n.toolbarItemText,
          onTap: onTextTap,
        ),
      ),
      ToolbarItemId.shape => _toolButton(
        context,
        Icons.category,
        DrawingTool.shape,
        l10n.toolbarShapeTooltip,
        onTap: onShapeTap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final outlineColor = context.watch<ThemeService>().current.menuBgColor;
    final spacer = vertical
        ? const SizedBox(height: 4)
        : const SizedBox(width: 4);
    final items = [
      for (final id in settings.toolbarOrder)
        if (!settings.hiddenToolbarItems.contains(id) &&
            (id != ToolbarItemId.pan || canShowPanTool(context)))
          _buildToolItem(context, l10n, id),
      spacer,
      GestureDetector(
        // 色見本はアイコンではなく色付きのContainerなので、テストから
        // find.byIconで特定できない。カラーピッカーを開く監査
        // （`test/dialog_screenshot_audit_test.dart`）が到達できるよう
        // キーを付けてある。
        key: const ValueKey('canvasColorSwatch'),
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
                border: Border.all(color: outlineColor, width: 2),
              ),
            ),
            if (isStampSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: outlineColor, width: 2),
                ),
                child: Icon(
                  Icons.block,
                  color: ThemeService.activeColorScheme.error,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
      _borderedIconButton(
        context,
        Icons.tune,
        onPressed: onBrushTap,
        tooltip: l10n.toolbarBrushSettingsTooltip,
      ),
      _borderedIconButton(
        context,
        Icons.layers,
        onPressed: onLayerTap,
        tooltip: l10n.toolbarLayerTooltip,
      ),
      FirstUseTooltip(
        tooltipKey: 'quick_tool',
        message: l10n.toolbarQuickToolFirstUseTip,
        child: GestureDetector(
          onLongPress: onQuickToolLongPress,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) {
              onQuickToolLongPress();
            }
          },
          child: _borderedIconButton(
            context,
            Icons.loop,
            onPressed: onQuickToolTap,
            tooltip: l10n.toolbarQuickToolTooltip,
            longPressTooltip: false,
          ),
        ),
      ),
      _borderedIconButton(
        context,
        Icons.save_outlined,
        onPressed: onSaveTap,
        tooltip: l10n.toolbarSaveTooltip,
      ),
      FirstUseTooltip(
        tooltipKey: 'ruler_tool',
        message: l10n.canvasRulerFirstUseTip,
        child: _borderedIconButton(
          context,
          Icons.straighten,
          onPressed: onRulerTap,
          tooltip: l10n.canvasRulerTooltip,
          selected: currentTool == DrawingTool.ruler,
        ),
      ),
      const HelpButton(),
    ];

    return Container(
      height: vertical ? null : 40,
      width: vertical ? 40 : null,
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 0 : 4,
        vertical: vertical ? 4 : 0,
      ),
      color: Colors.transparent,
      child: SingleChildScrollView(
        scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
        child: vertical ? Column(children: items) : Row(children: items),
      ),
    );
  }

  Widget _toolButton(
    BuildContext context,
    IconData icon,
    DrawingTool tool,
    String tooltip, {
    VoidCallback? onTap,
    bool? isSelected,
    // 外側で独自の長押しメニューを持つボタンはfalseにする
    // （Tooltipの長押しに取られて外側のonLongPressが発火しなくなるため）。
    bool longPressTooltip = true,
  }) {
    final selected = isSelected ?? (currentTool == tool);
    return GestureDetector(
      onDoubleTap: () => _showBriefDescription(context, tooltip),
      child: _borderedIconButton(
        context,
        icon,
        onPressed: onTap ?? () => onToolSelected(tool),
        tooltip: tooltip,
        selected: selected,
        longPressTooltip: longPressTooltip,
      ),
    );
  }

  static void _showBriefDescription(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 220,
      ),
    );
  }

  static Widget _borderedIconButton(
    BuildContext context,
    IconData icon, {
    required VoidCallback? onPressed,
    required String tooltip,
    bool selected = false,
    bool longPressTooltip = true,
  }) {
    return CanvasIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      selected: selected,
      longPressTooltip: longPressTooltip,
    );
  }

  Widget _selectToolButton(BuildContext context, AppLocalizations l10n) {
    final isSelected =
        currentTool == DrawingTool.selectRect ||
        currentTool == DrawingTool.selectLasso ||
        currentTool == DrawingTool.selectMagicWand;
    final icon = switch (currentTool) {
      DrawingTool.selectLasso => Icons.gesture,
      DrawingTool.selectMagicWand => Icons.auto_awesome,
      _ => Icons.highlight_alt,
    };
    return GestureDetector(
      onLongPress: () => _showSelectMenu(context, l10n),
      onDoubleTap: () =>
          _showBriefDescription(context, l10n.toolbarSelectTooltip),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          _showSelectMenu(context, l10n);
        }
      },
      child: _borderedIconButton(
        context,
        icon,
        onPressed: () => onToolSelected(DrawingTool.selectLasso),
        tooltip: l10n.toolbarSelectTooltip,
        selected: isSelected,
        longPressTooltip: false,
      ),
    );
  }

  void _showBucketToneMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer2<ToneService, SettingsService>(
        builder: (ctx, toneService, settings, _) {
          final tones = toneService.tones;
          final useTone = toneService.bucketUseTone;
          final lastBucketTone = toneService.lastBucketTone;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.format_color_fill, size: 18),
                      title: Text(
                        l10n.toolbarBucketFlatFill,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: !useTone,
                      onTap: () {
                        toneService.setBucketUseTone(false);
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.gesture, size: 18),
                      title: Text(
                        l10n.penSubToolTabLassoFill,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        onLassoFillSelected();
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (sheetCtx) => SizedBox(
                            height: MediaQuery.sizeOf(sheetCtx).height * 0.6,
                            child: LassoFillToneSheet(
                              onClose: () => Navigator.pop(sheetCtx),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.toolbarBucketToneListLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              ThemeService.activeColorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            childAspectRatio: 1,
                          ),
                      itemCount: tones.length,
                      itemBuilder: (context, index) {
                        final tone = tones[index];
                        final isSelected =
                            useTone && lastBucketTone?.id == tone.id;
                        return GestureDetector(
                          onTap: () {
                            toneService.setBucketUseTone(true);
                            toneService.setLastBucketTone(tone);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : ThemeService
                                          .activeColorScheme
                                          .onSurfaceVariant,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              color: ThemeService
                                  .activeColorScheme
                                  .onSurfaceVariant,
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
                    const Divider(height: 1),
                    Theme(
                      data: Theme.of(
                        ctx,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        dense: true,
                        leading: const Icon(Icons.tune, size: 18),
                        title: Text(
                          l10n.bucketSettingsTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        children: [
                          _bucketDetailSlider(
                            ctx: ctx,
                            label: l10n.bucketSettingsToleranceSection,
                            value: settings.bucketTolerance,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => settings.setBucketTolerance(v),
                          ),
                          _bucketDetailSlider(
                            ctx: ctx,
                            label: l10n.bucketSettingsExpandSection,
                            value: settings.bucketExpandPx.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (v) =>
                                settings.setBucketExpandPx(v.round()),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              l10n.bucketSettingsUnderLineTitle,
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: settings.bucketFillUnderLine,
                            onChanged: (v) =>
                                settings.setBucketFillUnderLine(v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bucketDetailSlider({
    required BuildContext ctx,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SteppedSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 28,
          child: EditableSliderValue(
            text: value.round().toString(),
            value: value,
            min: min,
            max: max,
            title: label,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }

  void _showSelectMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.toolbarSelectRect),
              onTap: () {
                onToolSelected(DrawingTool.selectRect);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.gesture),
              title: Text(l10n.toolbarSelectLasso),
              onTap: () {
                onToolSelected(DrawingTool.selectLasso);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l10n.toolbarSelectMagicWand),
              onTap: () {
                onToolSelected(DrawingTool.selectMagicWand);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
