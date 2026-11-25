import '../../services/shared_asset_card_service.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/theme_preset_labels.dart';
import '../../services/export_share_service.dart';
import '../../services/theme_service.dart';
import '../../models/app_theme_preset.dart';
import '../../widgets/export_share_feedback.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/color_contrast.dart';
import '../../utils/duplicate_name.dart';
import '../../utils/reorder_index.dart';
import '../../utils/warning_color.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/menu_action_label.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../widgets/theme_rescue_button.dart';
import 'theme_preview_gallery_screen.dart';
import '../../config/accent_text_theme.dart';
import '../../config/signal_colors.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/sheet_list_segment.dart';
import '../../widgets/first_that_fits.dart';
import '../../widgets/typing_dialog_inset.dart';
import '../../utils/file_failure_reason.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = context.watch<ThemeService>();
    final presets = themeService.presets;
    final current = themeService.current;

    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.themeSettingsTitle),
        actions: [
          const HelpButton(topic: 'テーマ設定'),
          if (themeService.needsThemeRescue)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ThemeRescueButton(
                iconOnly:
                    MediaQuery.sizeOf(context).width < 520 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4,
              ),
            ),
        ],
      ),
      body: desktopCentered(
        context,
        ListView(
          children: [
            // 現在の配色をそのまま縮小表示する。描画の見本は全画面の
            // 画面ギャラリーと共通で、固定画像・固定配色ではない。
            // タップで全画面に移動する。カラーピッカーの変更結果は
            // ThemeServiceの再描画によって即座にこの見本にも反映される。
            // 見本は設定の面と同じ1枚の面（メニューの背景色・細い縁）に置く。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GroupedSheet(
                children: [
                  InkWell(
                    key: const Key('themePreviewOpen'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ThemePreviewGalleryScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const ThemePreviewThumbnail(
                            key: Key('themeInlinePreview'),
                            height: 184,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.themePreviewCardTitle,
                                  style: localizedHeadingStyle(
                                    context,
                                    const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.themePreviewCardSubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.themePreviewCardViewAll(
                                          themePreviewEntries.length,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AccentTextTheme.of(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.open_in_full,
                                      size: 17,
                                      color: AccentTextTheme.of(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // カラーカスタマイズ：すべてカラーピッカー（HSV/RGB/HEX）で
            // 自由に設定できる。変更は即座にアプリ全体（現在のプリセット）へ
            // 反映される。
            // 色の役目ごとの行は1枚の面にまとめ、細かい役目は同じ面の最後の
            // 行で開く（以前は色ごとに影のついたカードが並んでいた）。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: GroupedSheet(
                title: l10n.themeColorCustomizeSection,
                children: [
                  _ColorCustomizeTile(
                    label: l10n.themeColorAccent,
                    color: current.accentColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(
                        accentColor: c,
                        accentTextColor:
                            current.accentTextColor != null &&
                                _sameColor(
                                  current.effectiveAccentTextColor,
                                  current.accentColor,
                                )
                            ? c
                            : current.accentTextColor,
                        selectionColor:
                            _sameColor(
                              current.selectionColor,
                              current.accentColor,
                            )
                            ? c
                            : null,
                      ),
                      current.accentColor,
                      role: _ThemeColorRole.accent,
                      roleLabel: l10n.themeColorAccent,
                    ),
                  ),
                  _ColorCustomizeTile(
                    label: l10n.themeColorText,
                    color: current.textColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(
                        textColor: c,
                        menuTextColor:
                            _sameColor(current.menuTextColor, current.textColor)
                            ? c
                            : null,
                      ),
                      current.textColor,
                      role: _ThemeColorRole.text,
                      roleLabel: l10n.themeColorText,
                    ),
                  ),
                  _ColorCustomizeTile(
                    key: const Key('themeButtonTextColorTile'),
                    label: l10n.themeColorButtonText,
                    color: current.buttonTextColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(
                        buttonTextColor: c,
                        selectionTextColor:
                            _sameColor(
                              current.selectionTextColor,
                              current.buttonTextColor,
                            )
                            ? c
                            : null,
                      ),
                      current.buttonTextColor,
                      role: _ThemeColorRole.buttonText,
                      roleLabel: l10n.themeColorButtonText,
                    ),
                  ),
                  _ColorCustomizeTile(
                    label: l10n.themeColorPanelBg,
                    color: current.panelBgColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(panelBgColor: c),
                      current.panelBgColor,
                      role: _ThemeColorRole.panelBg,
                      roleLabel: l10n.themeColorPanelBg,
                    ),
                  ),
                  _ColorCustomizeTile(
                    label: l10n.themeColorMenuBg,
                    color: current.menuBgColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(menuBgColor: c),
                      current.menuBgColor,
                      role: _ThemeColorRole.menuBg,
                      roleLabel: l10n.themeColorMenuBg,
                    ),
                  ),
                  // 更新マーク色は注意色を兼ねる（更新の印と、気をつけてほしい
                  // 知らせ）。警告色は取り消せない操作と失敗の知らせだけ。
                  _ColorCustomizeTile(
                    key: const Key('themeUpdateMarkColorTile'),
                    label: l10n.themeColorUpdateMark,
                    description: l10n.themeColorUpdateMarkHint,
                    color: current.updateMarkColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(updateMarkColor: c),
                      current.updateMarkColor,
                      role: _ThemeColorRole.updateMark,
                      roleLabel: l10n.themeColorUpdateMark,
                    ),
                  ),
                  _ColorCustomizeTile(
                    key: const Key('themeWarningColorTile'),
                    label: l10n.themeColorWarning,
                    description: l10n.themeColorWarningHint,
                    color: current.warningColor,
                    onTap: () => _showColorPickerDialog(
                      context,
                      themeService,
                      (p, c) => p.copyWith(warningColor: c),
                      current.warningColor,
                      role: _ThemeColorRole.warning,
                      roleLabel: l10n.themeColorWarning,
                    ),
                  ),
                  ExpansionTile(
                    key: const PageStorageKey('themeAdvancedColors'),
                    // 面の中の行なので、開いたときの上下の線は引かない（行の間の線は
                    // 面が引く）。
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(l10n.themeAdvancedColors),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: messageText(
                          l10n.themeAdvancedColorsHint,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _ColorCustomizeTile(
                        key: const Key('themeAccentTextColorTile'),
                        label: l10n.themeColorAccentText,
                        color: current.effectiveAccentTextColor,
                        onTap: () => _showColorPickerDialog(
                          context,
                          themeService,
                          (p, c) => p.copyWith(accentTextColor: c),
                          current.effectiveAccentTextColor,
                          role: _ThemeColorRole.accentText,
                          roleLabel: l10n.themeColorAccentText,
                        ),
                      ),
                      _ColorCustomizeTile(
                        key: const Key('themeMenuTextColorTile'),
                        label: l10n.themeColorMenuText,
                        color: current.menuTextColor,
                        onTap: () => _showColorPickerDialog(
                          context,
                          themeService,
                          (p, c) => p.copyWith(menuTextColor: c),
                          current.menuTextColor,
                          role: _ThemeColorRole.menuText,
                          roleLabel: l10n.themeColorMenuText,
                        ),
                      ),
                      _ColorCustomizeTile(
                        label: l10n.themeColorSelection,
                        color: current.selectionColor,
                        onTap: () => _showColorPickerDialog(
                          context,
                          themeService,
                          (p, c) => p.copyWith(selectionColor: c),
                          current.selectionColor,
                          role: _ThemeColorRole.selection,
                          roleLabel: l10n.themeColorSelection,
                        ),
                      ),
                      _ColorCustomizeTile(
                        key: const Key('themeSelectionTextColorTile'),
                        label: l10n.themeColorSelectionText,
                        color: current.selectionTextColor,
                        onTap: () => _showColorPickerDialog(
                          context,
                          themeService,
                          (p, c) => p.copyWith(selectionTextColor: c),
                          current.selectionTextColor,
                          role: _ThemeColorRole.selectionText,
                          roleLabel: l10n.themeColorSelectionText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 今の色をテーマとして残す・ファイルから足すは、長い一覧の後ろでは
            // なく色の設定のすぐ下に面の行として置く（以前は28件のテーマの
            // さらに下の枠のボタンだった）。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GroupedSheet(
                children: [
                  SheetRow(
                    icon: Icons.add,
                    title: l10n.themeSaveAsNewButton,
                    onTap: () => _saveCurrentAsNew(context, themeService),
                  ),
                  SheetRow(
                    icon: Icons.file_upload_outlined,
                    title: l10n.themeImportButton,
                    onTap: () => _importTheme(context, themeService),
                  ),
                ],
              ),
            ),
            // テーマ一覧（ドラッグで並び替え可能）。行は並べると1枚の面に
            // 見える（SheetListSegment）。
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(32, 24, 32, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.themePresetSection,
                  style: localizedHeadingStyle(
                    context,
                    TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // ドラッグハンドルは行末の明示アイコンのみを使う。既定の
              // ドラッグハンドル（buildDefaultDragHandles）を有効にしたままだと
              // Flutterが自動でもう1つハンドルを追加してしまい、テーマ色の
              // スウォッチからはみ出た黒いハンドルが二重に見えるバグになっていた。
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => themeService.reorder(
                oldIndex,
                preRemovalIndex(oldIndex, newIndex),
              ),
              children: [
                // 他の画面（設定トップ・セーブツリー等）と統一した、影付き
                // カードとして浮かせるデザイン（作り込みの一環）。
                //
                // カードのタップは「そのテーマの配色を現在の色へ取り込む」
                // だけで、テーマ自体の編集対象にはしない（取り込んだあとに
                // カラーカスタマイズで色を変えても、見本にしたテーマは
                // 書き換わらない）。そのためタップしてもチェックマークは
                // 付かない。テーマ自体を編集したい場合は三点メニューの
                // 「編集」から編集対象にする（そのときだけチェックが付き、
                // 背景をprimaryContainerに敷いて区別する）。
                for (final entry in presets.asMap().entries)
                  _presetRow(
                    context,
                    index: entry.key,
                    preset: entry.value,
                    current: current,
                    themeService: themeService,
                  ),
              ],
            ),
            SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  // 保存時と同じ精度で比較する。ピッカーを開いた時点の色を比較し、
  // プレビュー中に一時的に同じ色を通過しても個別設定を保持する。
  static bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

  /// [a]と[b]の配色（名前・お気に入り等を除く全ての色）が同じか。
  /// 一覧のカードをタップすると配色だけが現在の色へ写る（idは写らない）
  /// ので、いま使っている配色のテーマは色で見分ける。
  static bool _samePalette(AppThemePreset a, AppThemePreset b) =>
      _sameColor(a.accentColor, b.accentColor) &&
      _sameColor(a.effectiveAccentTextColor, b.effectiveAccentTextColor) &&
      _sameColor(a.textColor, b.textColor) &&
      _sameColor(a.buttonTextColor, b.buttonTextColor) &&
      _sameColor(a.menuTextColor, b.menuTextColor) &&
      _sameColor(a.selectionTextColor, b.selectionTextColor) &&
      _sameColor(a.panelBgColor, b.panelBgColor) &&
      _sameColor(a.menuBgColor, b.menuBgColor) &&
      _sameColor(a.selectionColor, b.selectionColor) &&
      _sameColor(a.updateMarkColor, b.updateMarkColor) &&
      _sameColor(a.warningColor, b.warningColor);

  /// テーマ一覧の1行。カードのタップは配色の取り込みだけで、テーマ自体の
  /// 編集は三点メニューの「編集」から行う（そのときだけ鉛筆の印が付く）。
  ///
  /// いまアプリに使っている配色と同じテーマの行には「使用中」の印と縁を
  /// 付ける。取り込んだ直後でも、どのテーマの配色で動いているかが一覧で
  /// 分かる（以前はSnackBarが消えると、どの行にも印が無かった）。
  Widget _presetRow(
    BuildContext context, {
    required int index,
    required AppThemePreset preset,
    required AppThemePreset current,
    required ThemeService themeService,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final accentText = AccentTextTheme.of(context);
    final editing = current.id == preset.id;
    final inUse = editing || _samePalette(current, preset);
    final label = themePresetLabel(preset, locale);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    // 「使用中」は入る幅では印と文字、入らない幅（320pxの仏語など）では
    // 印だけ（文字は縮めない。名前は読み上げに残す）。
    Widget statusIcon() => Icon(
      editing ? Icons.edit_outlined : Icons.check_circle,
      key: editing ? const Key('themePresetEditingCheck') : null,
      size: 16,
      color: accentText,
    );
    final status = inUse
        ? FirstThatFits(
            key: const Key('themePresetInUse'),
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  statusIcon(),
                  const SizedBox(width: 4),
                  Text(
                    l10n.themePresetInUseLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: localizedHeadingStyle(
                      context,
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentText,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(label: l10n.themePresetInUseLabel, child: statusIcon()),
            ],
          )
        : null;

    final name = messageText(
      label,
      keepLineStarts: true,
      style: localizedHeadingStyle(
        context,
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
    final swatch = _PresetColorSwatch(preset: preset);
    final actions = <Widget>[
      IconButton(
        icon: Icon(
          preset.isFavorite ? Icons.star : Icons.star_outline,
          size: 20,
          color: preset.isFavorite
              ? ThemeService.activeColorScheme.tertiary
              : null,
        ),
        tooltip: l10n.commonFavoriteToggle,
        onPressed: () => themeService.toggleFavorite(preset.id),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (action) =>
            _handleAction(context, action, preset, themeService),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
          PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
          PopupMenuItem(
            value: 'duplicate',
            child: Text(l10n.themeDuplicateAction),
          ),
          PopupMenuItem(
            value: 'exportCard',
            child: Text(l10n.shareCardExportMenu),
          ),
          PopupMenuItem(
            value: 'export',
            // 書き出しと共有が終わるまで、同じテーマをもう一度は書き出さない。
            enabled: !ExportShareService.isRunning(_exportKey(preset)),
            child: Text(l10n.themeExportMenuItem),
          ),
          if (ThemeService.isBuiltInPreset(preset.id))
            PopupMenuItem(
              value: 'reset',
              child: Text(l10n.themeResetConfirmAction),
            )
          else
            PopupMenuItem(
              value: 'delete',
              child: MenuActionLabel(
                icon: Icons.delete_outline,
                label: l10n.commonDelete,
                destructive: true,
              ),
            ),
        ],
      ),
      // つかめる所をアイコンの周りまで広げる（18pxの印だけだと指で
      // つかみ損ねて、カードのタップ＝配色の取り込みになった）。
      ReorderableDragStartListener(
        index: index,
        child: const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6, 12, 8, 12),
          child: Icon(Icons.drag_handle, size: 22),
        ),
      ),
    ];

    // 使っているテーマは行の色や枠では示さず、「使用中」の印と読み上げの
    // 選択の状態で示す（差し色の塗りは状態の印だけに使う）。
    return Padding(
      key: ValueKey(preset.id),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        selected: inUse,
        child: SheetListSegment(
          first: index == 0,
          last: index == themeService.presets.length - 1,
          child: InkWell(
            onTap: () {
              // 1回押すだけで今の配色（自分で作った配色を含む）が置き換わる
              // ので、知らせから押す前の配色へ戻せるようにする。
              final previous = themeService.current;
              themeService.adoptPresetColors(preset.id);
              final changed = !_samePalette(previous, themeService.current);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.themeAdoptColorsSnackbar(label)),
                  persist: false,
                  action: changed
                      ? SnackBarAction(
                          label: l10n.homeUndoAction,
                          onPressed: () =>
                              themeService.restoreCurrent(previous),
                        )
                      : null,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 370 * textScale) {
                    // 狭い画面：名前を1行目に、見本・印・操作を2行目に。
                    // 2行目の見本と操作の間の空きへ「使用中」を置くので、
                    // 印を出しても行の高さは変わらない。
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: 4,
                            end: 8,
                          ),
                          child: name,
                        ),
                        Row(
                          children: [
                            swatch,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: status,
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      swatch,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            name,
                            if (status != null) ...[
                              const SizedBox(height: 4),
                              status,
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// カラーピッカーダイアログを表示する（カラーカスタマイズ）。
  /// ドラッグ中は `ThemeService.previewCurrent()` でアプリ全体へ即時反映し、
  /// 閉じた時点でユーザーが選んだ色をそのまま保存する。
  ///
  /// 読みにくさを理由にユーザーの色選択を拒否しない。操作不能になる
  /// ほど色が近いテーマからの復旧は、起動画面右上のテーマ非依存の
  /// リセットボタンで行う（判定は `color_contrast.dart`）。
  Future<void> _showColorPickerDialog(
    BuildContext context,
    ThemeService service,
    AppThemePreset Function(AppThemePreset preset, Color color) update,
    Color initialColor, {
    required _ThemeColorRole role,
    required String roleLabel,
  }) async {
    var changed = false;
    // 警告色が決め方どおり（利用者が選んでいない）なら、ほかの色を変えると
    // きは変えた後の色で決め直す（背景を変えても警告色が読めるまま。開いた
    // 時点の色で決める）。
    final warningFollows =
        role != _ThemeColorRole.warning && warningFollowsRule(service.current);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: typingDialogInsetPadding(
          ctx,
          usual: const EdgeInsets.all(16),
        ),
        // ピッカーが画面のほとんどを覆うので、選んでいる色がアプリの
        // どこに効くかを見出しの見本で示す（見本はThemeServiceの現在の色を
        // 直接読むので、ドラッグ中もそのまま変わる）。
        child: ColorPickerPanel(
          currentColor: initialColor,
          header: _ThemeColorRoleSample(role: role, label: roleLabel),
          onColorChanged: (color) {
            changed = true;
            final next = update(service.current, color);
            service.previewCurrent(
              warningFollows
                  ? next.copyWith(warningColor: defaultWarningColorFor(next))
                  : next,
            );
          },
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
    if (changed) service.commitCurrent();
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    AppThemePreset preset,
    ThemeService service,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final name = themePresetLabel(preset, locale);
    switch (action) {
      // このテーマ自体を編集対象にする（一覧でチェックが付き、以後の
      // カラーカスタマイズの変更はこのテーマへ上書き保存される）。
      // カードのタップは配色の取り込みだけなので、編集はここからのみ。
      case 'edit':
        service.applyPreset(preset.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.themeEditPresetSnackbar(name))),
        );
      case 'rename':
        await _showRenameDialog(context, preset, service);
      case 'duplicate':
        // ブラシ・作品の複製・引き継ぎで足す複製と同じ形の名前（同じ名前が
        // あれば番号を付ける）。
        final copy = preset.copyWith(
          id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
          name: numberedCopyName(l10n, name, {
            for (final p in service.presets) themePresetLabel(p, locale),
          }),
        );
        service.savePreset(copy);
      case 'delete':
        // お気に入り登録中は削除できない。
        if (preset.isFavorite) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
          );
        } else if (await confirmDelete(context, itemName: name)) {
          service.deletePreset(preset.id);
        }
      case 'reset':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: messageText(l10n.themeResetConfirmTitle),
            content: messageText(name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              // 編集した色は戻せないので、取り消せない操作の塗り（警告色）。
              FilledButton(
                style: warningFilledButtonStyle(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.themeResetConfirmAction),
              ),
            ],
          ),
        );
        if (confirmed == true) service.resetPresetColors(preset.id);
      case 'export':
        _exportTheme(context, preset);
      case 'exportCard':
        SharedAssetCardService.exportSettings(
          context,
          kind: 'theme',
          name: name,
          settings: preset.toJson(),
        );
    }
  }

  static String _exportKey(AppThemePreset preset) => 'theme:${preset.id}';

  /// .niathemeへ書き出してから共有する。書き出しの失敗と、共有できない端末・
  /// 共有の失敗は別のことなので、別の文で知らせる。
  Future<void> _exportTheme(BuildContext context, AppThemePreset preset) =>
      ExportShareService.runExclusive(_exportKey(preset), () async {
        final File file;
        try {
          final dir = await getTemporaryDirectory();
          final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          file = File('${dir.path}/$safeName.niatheme');
          await file.writeAsString(jsonEncode(preset.toJson()));
        } catch (e) {
          if (!context.mounted) return;
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.themeExportFailedSnackbar(fileFailureReason(l10n, e)),
              ),
            ),
          );
          return;
        }
        if (!context.mounted) return;
        await shareExportedFileWithNotice(context, file);
      });

  Future<void> _importTheme(BuildContext context, ThemeService service) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['niatheme', 'png'],
      );
      final path = result?.files.firstOrNull?.path;
      if (!context.mounted || path == null) return;

      final content = await SharedAssetCardService.readSettingsFile(
        path,
        kind: 'theme',
      );
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic> ||
          (!json.containsKey('accentColor') &&
              !(json['id'] is String && json['name'] is String))) {
        throw const FormatException('Not a theme');
      }
      final AppThemePreset preset;
      try {
        preset = AppThemePreset.fromJson(
          json,
        ).copyWith(id: 'theme_${DateTime.now().millisecondsSinceEpoch}');
      } on TypeError catch (error, stack) {
        AppErrorReporter.record(error, stack);
        if (context.mounted) {
          _showImportMessage(context, l10n.themeImportMissingColors);
        }
        return;
      }
      if (!context.mounted) return;
      service.savePreset(preset);
      if (isThemeAtLockoutRisk(preset)) {
        _showImportMessage(context, l10n.themeImportLowContrast);
      } else {
        service.applyPreset(preset.id);
        _showImportMessage(context, l10n.themeImportSuccessSnackbar);
      }
    } on FormatException catch (error, stack) {
      AppErrorReporter.record(FormatException(error.message), stack);
      _showImportMessage(context, l10n.themeImportInvalidFile);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      _showImportMessage(context, l10n.themeImportReadFailed);
    }
  }

  void _showImportMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: messageText(message)));
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    AppThemePreset preset,
    ThemeService service,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final name = themePresetLabel(preset, Localizations.localeOf(context));
    return showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.commonRename,
        confirmLabel: l10n.commonSave,
        cancelLabel: l10n.commonCancel,
        initialName: name,
        onSubmit: (newName) async {
          if (newName != name) {
            service.renamePreset(preset.id, newName);
          }
        },
      ),
    );
  }

  void _saveCurrentAsNew(BuildContext context, ThemeService service) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.themePresetNameDialogTitle,
        confirmLabel: l10n.commonSave,
        cancelLabel: l10n.commonCancel,
        initialName: l10n.themeDefaultPresetName,
        onSubmit: (name) async {
          service.savePreset(
            service.current.copyWith(
              id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              isFavorite: false,
            ),
          );
        },
      ),
    );
  }
}

/// カラーカスタマイズ項目1件：色見本＋ラベル＋タップでカラー
/// ピッカーを開く。
class _ColorCustomizeTile extends StatelessWidget {
  final String label;

  /// 項目名の下に出す、その色を使う所の短い説明（警告色・更新マーク色）。
  final String? description;
  final Color color;
  final VoidCallback onTap;

  const _ColorCustomizeTile({
    super.key,
    required this.label,
    this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 面（GroupedSheet）の中の1行。行の大きさ・余白は面の行（SheetRow）と
    // 同じで、先頭は色の見本（色そのものが中身なので、狭い幅・大きな文字
    // でも隠さない）。
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    messageText(
                      label,
                      keepLineStarts: true,
                      style: localizedHeadingStyle(
                        context,
                        const TextStyle(fontSize: 15, height: 1.3),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      messageText(
                        description!,
                        keepLineStarts: true,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetColorSwatch extends StatelessWidget {
  final AppThemePreset preset;
  const _PresetColorSwatch({required this.preset});

  @override
  Widget build(BuildContext context) {
    // Compact swatch samples all four actual foreground roles; colors come
    // solely from the preset. It is not a substitute for the full preview.
    return Container(
      width: 72,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    color: preset.panelBgColor,
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: preset.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    color: preset.accentColor,
                    child: Icon(
                      Icons.check,
                      color: preset.buttonTextColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    color: preset.menuBgColor,
                    child: Icon(
                      Icons.menu,
                      color: preset.menuTextColor,
                      size: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    color: preset.selectionColor,
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: preset.selectionTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

/// カラーカスタマイズで選んでいる色の役目。
enum _ThemeColorRole {
  accent,
  text,
  buttonText,
  panelBg,
  menuBg,
  updateMark,
  warning,
  accentText,
  menuText,
  selection,
  selectionText,
}

/// カラーピッカーの上に出す、選んでいる色がアプリのどこに効くかの見本。
///
/// 色はテーマ（ダイアログを開いた時点で写した`Theme`）ではなく
/// [ThemeService]の現在の色から直接読む。ピッカーのドラッグ中の
/// `previewCurrent`がそのまま見本へ届く。選んでいる役目の部分を
/// 輪で囲み、名前（項目名）を上に出す。
class _ThemeColorRoleSample extends StatelessWidget {
  const _ThemeColorRoleSample({required this.role, required this.label});

  final _ThemeColorRole role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.watch<ThemeService>().current;
    final scheme = Theme.of(context).colorScheme;

    Widget ring({
      required bool on,
      required Color color,
      required double radius,
      required Widget child,
    }) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + 3),
          border: Border.all(
            color: on ? color : color.withValues(alpha: 0),
            width: 2,
          ),
        ),
        child: child,
      );
    }

    TextStyle heading(double size, Color color) => localizedHeadingStyle(
      context,
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      ),
    );

    final onPanel = c.textColor;
    final sample = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: c.panelBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: role == _ThemeColorRole.panelBg
              ? onPanel
              : scheme.outlineVariant,
          width: role == _ThemeColorRole.panelBg ? 2 : 1,
        ),
      ),
      // 大きな文字・長い語でも見本の行をはみ出させない（見本は飾りで、
      // 読ませる文は上の項目名）。
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ring(
                on: role == _ThemeColorRole.text,
                color: onPanel,
                radius: 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: c.textColor,
                        height: 1.1,
                      ),
                    ),
                    PositionedDirectional(
                      top: -3,
                      end: -9,
                      child: ring(
                        on: role == _ThemeColorRole.updateMark,
                        color: onPanel,
                        radius: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.updateMarkColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ring(
                on: role == _ThemeColorRole.accentText,
                color: onPanel,
                radius: 4,
                child: Text(
                  l10n.commonEdit,
                  maxLines: 1,
                  style: heading(13, c.effectiveAccentTextColor),
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ring(
                on:
                    role == _ThemeColorRole.accent ||
                    role == _ThemeColorRole.buttonText,
                color: onPanel,
                radius: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.accentColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.commonSave,
                    maxLines: 1,
                    style: heading(12, c.buttonTextColor),
                  ),
                ),
              ),
            ),
          ),
          // 警告色：メニューの削除の項目・失敗の知らせの印（取り消せない操作）。
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ring(
                on: role == _ThemeColorRole.warning,
                color: onPanel,
                radius: 8,
                child: Icon(
                  Icons.delete_forever_outlined,
                  key: const Key('themeColorRoleSampleWarning'),
                  size: 24,
                  color: c.warningColor,
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ring(
                on:
                    role == _ThemeColorRole.selection ||
                    role == _ThemeColorRole.selectionText,
                color: onPanel,
                radius: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.selectionColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: c.selectionTextColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final menuRole =
        role == _ThemeColorRole.menuBg || role == _ThemeColorRole.menuText;
    // ピッカーの面（メニューの背景色）の上に、見出しと画面の見本を並べる。
    // メニューの色を選んでいるときは見出しの行（ピッカーの面そのもの）を囲む。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ring(
          on: menuRole,
          color: c.menuTextColor,
          radius: 6,
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _roleColor(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.menuTextColor, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  key: const Key('themeColorRoleSampleTitle'),
                  style: heading(14, c.menuTextColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(child: sample),
      ],
    );
  }

  Color _roleColor(AppThemePreset c) => switch (role) {
    _ThemeColorRole.accent => c.accentColor,
    _ThemeColorRole.text => c.textColor,
    _ThemeColorRole.buttonText => c.buttonTextColor,
    _ThemeColorRole.panelBg => c.panelBgColor,
    _ThemeColorRole.menuBg => c.menuBgColor,
    _ThemeColorRole.updateMark => c.updateMarkColor,
    _ThemeColorRole.warning => c.warningColor,
    _ThemeColorRole.accentText => c.effectiveAccentTextColor,
    _ThemeColorRole.menuText => c.menuTextColor,
    _ThemeColorRole.selection => c.selectionColor,
    _ThemeColorRole.selectionText => c.selectionTextColor,
  };
}
