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
import '../../../widgets/responsive.dart';
import '../../../widgets/stepped_slider.dart';
import '../canvas_screen.dart';
import 'canvas_icon_button.dart';
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
  // 手動保存（セーブツリー）：「キャンバス → 保存 → キャンバスへ戻る」
  final VoidCallback onSaveTap;
  // 投げ縄塗り選択（ペンのサブツールではなく、バケツ長押しメニューから
  // 選べるようにするための導線。投げ縄で囲った範囲を塗りつぶす点で
  // バケツ塗りに近い性質を持つため）。
  final VoidCallback onLassoFillSelected;
  // スタンプ選択中かどうか（色アイコンに🚫重ね表示・タップで専用トースト）
  final bool isStampSelected;
  // trueの場合、画面下部の横並びバーではなく左側（左利きモードでは右側）に
  // 常設する縦並びのツールレールとして表示する。
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
    required this.onTextTap,
    required this.onShapeTap,
    required this.onQuickToolTap,
    required this.onQuickToolLongPress,
    required this.onSaveTap,
    required this.onLassoFillSelected,
    this.isStampSelected = false,
    this.vertical = false,
  });

  /// ツールバー編集でカスタマイズ可能な項目を、現在の並び順・
  /// 表示設定に従って構築する。
  Widget _buildToolItem(
    BuildContext context,
    AppLocalizations l10n,
    ToolbarItemId id,
  ) {
    return switch (id) {
      // ペンボタン：長押しでサブツールパネル表示（初回使用時の吹き出し説明）
      ToolbarItemId.pen => FirstUseTooltip(
        tooltipKey: 'pen_tool',
        message: l10n.toolbarPenFirstUseTip,
        child: GestureDetector(
          onLongPress: onPenLongPress,
          // 長押しに加えて上スワイプでもサブツールパネルを開けるように
          // する（早替えツールボタンと同じ操作方法に揃える）。
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) onPenLongPress();
          },
          child: _toolButton(
            context,
            Icons.brush,
            DrawingTool.pen,
            l10n.toolbarPenTooltip,
          ),
        ),
      ),
      // 消しゴム用のアイコン。Material Iconsには適切な消しゴムのグリフが
      // ないため、Font Awesome Free（font_awesome_flutter、CC BY 4.0。
      // クレジットは設定＞利用規約・ライセンス画面に表示）のeraserアイコンを使う。
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
      // バケツボタン：長押しまたは上スワイプでベタ塗り／トーン切り替え
      // メニュー表示（他の詳細設定ポップアップと操作方法を
      // 統一するため、長押しに加えて上スワイプにも対応させている）。
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
          ),
        ),
      ),
      ToolbarItemId.eyedropper => _toolButton(
        context,
        Icons.colorize,
        DrawingTool.eyedropper,
        l10n.toolbarItemEyedropper,
      ),
      // 指先ツール（歪み）：スマホ・PC両モードで使用可能。
      ToolbarItemId.finger => _toolButton(
        context,
        Icons.pan_tool_alt,
        DrawingTool.finger,
        l10n.toolbarItemFinger,
      ),
      // 手のひらツール（画面移動専用）：呼び出し側のfor文でcanShowPanTool()
      // により表示条件（強制スマホモードでは非表示、それ以外は横画面のみ）が
      // 既に判定済みのため、ここでは単に描画するだけでよい。
      ToolbarItemId.pan => _toolButton(
        context,
        Icons.back_hand,
        DrawingTool.pan,
        l10n.toolbarItemPan,
      ),
      ToolbarItemId.select => _selectToolButton(context, l10n),
      ToolbarItemId.transform => _toolButton(
        context,
        Icons.transform,
        DrawingTool.transform,
        l10n.toolbarItemTransform,
      ),
      // 初回タップ時の吹き出し説明
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
    // 描画領域を可能な限り広げるため、常設ボタン類は背景を持たせず、
    // どんな色のキャンバス内容の上でも視認できるよう縁取りのみを付ける
    // （CanvasIconButton参照）。アイコン・縁取りとも白黒に固定せず、
    // ユーザーが選んだテーマ・外観のアイコン色・メニュー背景色と連動する。
    final outlineColor = context.watch<ThemeService>().current.menuBgColor;
    final spacer = vertical
        ? const SizedBox(height: 4)
        : const SizedBox(width: 4);
    final items = [
      // ツールバー編集でカスタマイズ可能な項目を並び順・表示設定通りに表示。
      // 手のひらツールは強制スマホモードでは常に非表示、それ以外
      // （PCモード固定・自動判定）では横画面のときのみ表示する
      // （液タブ接続時のDeXモード等を考慮）。
      for (final id in settings.toolbarOrder)
        if (!settings.hiddenToolbarItems.contains(id) &&
            (id != ToolbarItemId.pan || canShowPanTool(context)))
          _buildToolItem(context, l10n, id),
      spacer,
      // 色インジケーター（スタンプ選択中は色情報を保持しているため
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
                child: const Icon(Icons.block, color: Colors.red, size: 20),
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
      // オニオンスキンはここから削除し、
      // キャンバス上部バーの「設定/編集」メニューへ集約した。
      // ツール早替えボタン（↺）
      // ツール早替えボタン：タップで登録順に切替、長押しまたは上スワイプで
      // 管理ポップアップ（登録・並び替え）を表示
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
          child: _borderedIconButton(
            context,
            Icons.loop,
            onPressed: onQuickToolTap,
            tooltip: l10n.toolbarQuickToolTooltip,
          ),
        ),
      ),
      // タイムラインへの切替ボタンはここから
      // 削除し、フレーム一覧右下のボタン（frame_strip_widget.dart）
      // へ統一した（同じ役割のボタンが2箇所にあり冗長だったため）。
      // 手動保存（セーブツリー）：「キャンバス → 保存 → キャンバスへ戻る」
      _borderedIconButton(
        context,
        Icons.save_outlined,
        onPressed: onSaveTap,
        tooltip: l10n.toolbarSaveTooltip,
      ),
    ];
    // verticalの場合は縦並びのツールレール、falseの場合は画面下部の
    // 横並びバーとして表示する。
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

  // ダブルタップで簡易説明・長押しでブラシ/トーン/色変更。長押しは各ツール個別のサブメニュー
  // （ペンのサブツールパネル・バケツのトーン切替等）に使うため、従来
  // 長押しで表示していた簡易説明はダブルタップへ移す。ここで
  // GestureDetectorを重ねてもペン/バケツ/選択ツールの既存の
  // onLongPress用GestureDetectorとは別のジェスチャー種別（ダブルタップ
  // vs 長押し）を検出するため、ジェスチャーアリーナで正しく共存する。
  Widget _toolButton(
    BuildContext context,
    IconData icon,
    DrawingTool tool,
    String tooltip, {
    VoidCallback? onTap,
  }) {
    final isSelected = currentTool == tool;
    return GestureDetector(
      onDoubleTap: () => _showBriefDescription(context, tooltip),
      child: _borderedIconButton(
        context,
        icon,
        onPressed: onTap ?? () => onToolSelected(tool),
        tooltip: tooltip,
        selected: isSelected,
      ),
    );
  }

  /// ダブルタップ時のツール簡易説明をスナックバーで一瞬表示する。
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

  /// 常設ボタン共通のスタイル：背景なし・アイコンだけが
  /// キャンバス上に浮かび、アイコンの形にぴったり沿う半透明の黒い縁取りを
  /// 持つ（実装はCanvasIconButtonへ集約。canvas_screen.dartの上部バーとも
  /// 共通のデザインにするため）。
  static Widget _borderedIconButton(
    BuildContext context,
    IconData icon, {
    required VoidCallback? onPressed,
    required String tooltip,
    bool selected = false,
  }) {
    return CanvasIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      selected: selected,
    );
  }

  Widget _selectToolButton(BuildContext context, AppLocalizations l10n) {
    final isSelected =
        currentTool == DrawingTool.selectRect ||
        currentTool == DrawingTool.selectLasso ||
        currentTool == DrawingTool.selectMagicWand;
    // 矩形選択（デフォルト）にはhighlight_alt（角に選択ハンドルが付いた
    // 矩形）を使う。以前のcrop_square（ただの四角い枠）よりも「範囲選択」
    // であることが一目で伝わるアイコン。
    final icon = switch (currentTool) {
      DrawingTool.selectLasso => Icons.gesture,
      DrawingTool.selectMagicWand => Icons.auto_awesome,
      _ => Icons.highlight_alt,
    };
    return GestureDetector(
      onLongPress: () => _showSelectMenu(context, l10n),
      onDoubleTap: () =>
          _showBriefDescription(context, l10n.toolbarSelectTooltip),
      // 長押しに加えて上スワイプでも選択メニューを開けるようにする
      // （他の詳細設定ポップアップと操作方法を統一するため）。
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          _showSelectMenu(context, l10n);
        }
      },
      child: _borderedIconButton(
        context,
        icon,
        onPressed: () => onToolSelected(DrawingTool.selectRect),
        tooltip: l10n.toolbarSelectTooltip,
        selected: isSelected,
      ),
    );
  }

  /// バケツツールのベタ塗り／トーン切り替えメニュー。
  /// 詳細設定（許容誤差・拡張px・線の下まで潜るか）も同じシートから
  /// 調整できる。ここでの変更はSettingsServiceを直接更新するため、
  /// 設定画面「バケツ塗り」で行った変更と常に連動する（単一の設定値を
  /// 共有しているだけで、同期処理は不要）。
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
                    // 投げ縄塗り：投げ縄で囲った範囲を塗りつぶす点でバケツ塗りに
                    // 近い性質を持つため、ペンではなくここから選べるようにする。
                    // 選択後は塗りつぶし方（ベタ塗り／トーン）を選ぶシートを続けて
                    // 開く。「囲って塗る」モード（閉じた線画の内側だけを塗る）は
                    // ツール選択後、上部バーのスイッチで切り替えられる。
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.toolbarBucketToneListLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
                                    : Colors.grey[600]!,
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
                                Text(
                                  tone.name,
                                  style: const TextStyle(
                                    fontSize: 7,
                                    fontFamily: 'Kuramubon',
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
                      // ExpansionTileの区切り線を消す（前後のDividerと二重に
                      // ならないようにするため）。
                      data: Theme.of(
                        ctx,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        dense: true,
                        leading: const Icon(Icons.tune, size: 18),
                        title: Text(
                          l10n.bucketSettingsTitle,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Kuramubon'),
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
