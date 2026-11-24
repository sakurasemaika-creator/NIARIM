import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/home_widget_refresh.dart';
import '../../services/shortcut_widget_renderer.dart';
import '../../services/home_widget_service.dart';
import '../../services/project_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';
import 'widget_artwork_picker_screen.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/typing_dialog_inset.dart';
import '../../widgets/grouped_sheet.dart';

/// 背景色の選び方（テーマに合わせる／色を指定する）の2択。
enum _ColorMode { theme, custom }

/// ホーム画面ウィジェットの設定画面。
///
/// 置けるウィジェットは3種類（起動画面／作品をつくる／作品広場）。この画面は
/// **ウィジェット1種類につき1節**という構成にしてある。
///
/// - 起動画面ウィジェットは「どのフレームを表示するか」だけを選ぶ
///   （タップで`WidgetArtworkPickerScreen`→`WidgetArtworkFramePickerScreen`
///   の2画面フローへ進む。背景色の指定はここには無い＝常にテーマに追従）。
/// - 作品をつくる／作品広場ウィジェットは、配色を「テーマに合わせる」
///   「色を選ぶ」の2択のラジオボタンで選ぶ。「色を選ぶ」を選ぶと、
///   **背景色と文字・アイコンの色の2つ**を個別に指定できる行が出る
///   （背景だけ変えられると、濃い背景に濃い文字といった読めない
///   組み合わせになりうるため）。
///
/// 色は種類ごとに独立して持つ。3種を並べて置いたとき色を変えて
/// 見分けたい、という使い方ができるようにするため。
///
/// ウィジェットの追加そのものはホーム画面の長押しから行う（アプリからは
/// 追加できない）ため、その旨を画面上に書いてある。
class WidgetSettingsScreen extends StatelessWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = context.watch<HomeWidgetService>();

    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(l10n.widgetSettingsTitle)),
      body: desktopCentered(
        context,
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // 画面の説明は1つにする（動画を出せない旨は、起動画面ウィジェットの
            // 面の下の「フレーム1枚を表示します」と重なっていた）。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _note(context, l10n.widgetSettingsDescription),
            ),
            const SizedBox(height: 24),

            // ウィジェット1種類につき1つの欄（題は欄の上の見出し、説明は
            // 欄の中の先頭）。ほかの設定の画面と同じ見出し・欄にそろえた。
            GroupedSheet(
              title: l10n.widgetSectionArtwork,
              footer: l10n.widgetSectionArtworkDesc,
              children: [_artworkSummaryTile(context, widgets)],
            ),
            const SizedBox(height: 24),

            _colorCard(
              context,
              widgets,
              HomeWidgetKind.create,
              l10n.widgetSectionCreate,
              l10n.widgetSectionCreateDesc,
            ),
            const SizedBox(height: 24),

            _colorCard(
              context,
              widgets,
              HomeWidgetKind.plaza,
              l10n.widgetSectionPlaza,
              l10n.widgetSectionPlazaDesc,
            ),
          ],
        ),
      ),
    );
  }

  /// 起動画面ウィジェットの「作品を選ぶ」行。
  ///
  /// 未選択なら[l10n.widgetArtworkPickButton]（「作品を選ぶ」）をタイトルに
  /// 出す。選択済みなら選んだフレームのプレビュー・作品名・フレーム番号を
  /// 出す。どちらもタップで作品→フレームの選択フローへ進む。
  Widget _artworkSummaryTile(BuildContext context, HomeWidgetService widgets) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final projectId = widgets.projectId;
    final artwork = projectId == null
        ? null
        : homeWidgetArtworkState(context.watch<ProjectService>(), projectId);

    // 欄の中の行（欄の中にさらに欄を重ねない）。上の小見出し「表示する
    // 作品」は行の上の文として出す。
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: projectId == null || artwork?.name == null
            // まだ選んでいないときは、選ぶ前の絵の枠（補助の文字色の印と
            // 細い枠）を出す。差し色の下地には載せない。
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ArtworkFrameThumbnail(
                  projectId: projectId,
                  sceneId: widgets.sceneId,
                  frameIndex: widgets.frameIndex,
                ),
              ),
      ),
      title: Text(artwork?.name ?? l10n.widgetArtworkPickButton),
      subtitle: artwork?.inTrash == true
          ? Text(l10n.widgetArtworkInTrash)
          : Text(
              artwork?.name == null
                  ? l10n.widgetArtworkSection
                  : l10n.widgetArtworkFrameNumberLabel(
                      (widgets.frameIndex ?? 0) + 1,
                    ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/widget/artwork'),
    );
  }

  /// 1種類ぶんの配色設定（テーマに合わせる／色を選ぶのラジオボタンと、
  /// 「色を選ぶ」のときだけ出る背景色・文字色の2行）。
  Widget _colorCard(
    BuildContext context,
    HomeWidgetService widgets,
    HomeWidgetKind kind,
    String title,
    String description,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isCustom = !widgets.followsTheme(kind);
    final mode = isCustom ? _ColorMode.custom : _ColorMode.theme;

    final radios = RadioGroup<_ColorMode>(
      groupValue: mode,
      onChanged: (value) async {
        if (value == _ColorMode.theme) {
          await widgets.setBackgroundColor(kind, null);
          if (context.mounted) await _push(context);
        } else if (context.mounted) {
          // 「色を選ぶ」は選ぶたび（既に選んでいる状態からの再タップも
          // 含め）背景色の選択ダイアログを開く。まだ指定していなければ
          // 現在のテーマカラーを初期値にする。ダイアログをそのまま
          // 閉じた場合は何も変更されず、選択はテーマ追従のまま
          // （＝ラジオも戻る）。
          _pickColor(context, widgets, kind, foreground: false);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<_ColorMode>(
            value: _ColorMode.theme,
            title: Text(l10n.widgetColorFollowTheme),
          ),
          RadioListTile<_ColorMode>(
            value: _ColorMode.custom,
            title: Text(l10n.widgetColorCustom),
          ),
        ],
      ),
    );
    final preview = _ShortcutWidgetPreview(kind: kind, widgets: widgets);
    return GroupedSheet(
      title: title,
      footer: description,
      children: [
        // 選択肢の横に、ホーム画面に置いたときの見た目をその場で出す
        // （色を選んでも、ホーム画面へ戻るまで結果が分からなかった）。
        // 並べると選択肢の名前が狭くなる幅・文字の大きさでは見本を下へ。
        LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (box.maxWidth - _previewSize - 16 >= 200 * scale) {
              return Row(
                children: [
                  Expanded(child: radios),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: preview,
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                radios,
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Center(child: preview),
                ),
              ],
            );
          },
        ),
        // 色を選んでいるときだけ、背景色と文字・アイコンの色を個別に
        // 出す。文字色まで選べないと、濃い背景に濃い文字といった読めない
        // 組み合わせになりうるため。
        if (isCustom) ...[
          _swatchTile(
            context,
            label: l10n.widgetColorBase,
            color: Color(
              widgets.backgroundColorOf(kind) ?? _themeColor(context),
            ),
            onTap: () => _pickColor(context, widgets, kind, foreground: false),
          ),
          _swatchTile(
            context,
            label: l10n.widgetColorForeground,
            color: Color(
              widgets.foregroundColorOf(kind) ?? _themeForegroundColor(context),
            ),
            onTap: () => _pickColor(context, widgets, kind, foreground: true),
          ),
        ],
      ],
    );
  }

  /// 色見本つきの1行（タップで色選択ダイアログを開く）。
  Widget _swatchTile(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// 画面の説明（欄の外、13px・薄い文字色）。
  Widget _note(BuildContext context, String text) => messageText(
    text,
    style: TextStyle(
      fontSize: 13,
      height: 1.45,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  static int _themeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.toARGB32();

  /// テーマ追従時のアイコン・文字色。起動画面の導線ボタンと
  /// 同じ「ボタン内の文字・アイコン色」を使用する。
  static int _themeForegroundColor(BuildContext context) =>
      context.read<ThemeService>().current.buttonTextColor.toARGB32();

  /// 設定変更のたびにウィジェットへ反映する。
  static Future<void> _push(BuildContext context) async {
    await refreshHomeWidgets(
      widgets: context.read<HomeWidgetService>(),
      projects: context.read<ProjectService>(),
      theme: context.read<ThemeService>(),
      l10n: AppLocalizations.of(context)!,
    );
  }

  /// 色選択ダイアログ。[foreground]がtrueなら文字・アイコンの色、
  /// falseなら背景色を選ぶ。
  void _pickColor(
    BuildContext context,
    HomeWidgetService widgets,
    HomeWidgetKind kind, {
    required bool foreground,
  }) {
    final current = foreground
        ? (widgets.foregroundColorOf(kind) ?? _themeForegroundColor(context))
        : (widgets.backgroundColorOf(kind) ?? _themeColor(context));
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: typingDialogInsetPadding(
          ctx,
          usual: const EdgeInsets.all(16),
        ),
        child: ColorPickerPanel(
          currentColor: Color(current),
          onColorChanged: (c) => foreground
              ? widgets.setForegroundColor(kind, c.toARGB32())
              : widgets.setBackgroundColor(kind, c.toARGB32()),
          onClose: () async {
            Navigator.pop(ctx);
            if (context.mounted) await _push(context);
          },
        ),
      ),
    );
  }
}

/// 見本の大きさ（ホーム画面のウィジェットを縮めて出す）。
const double _previewSize = 96;

/// 「作品をつくる」「作品広場」ウィジェットの見本。ホーム画面へ焼く画像
/// （`renderShortcutWidgetImage`の正方形）と同じ寸法・色・文言で組み、
/// [_previewSize]へ縮めて出す。
class _ShortcutWidgetPreview extends StatelessWidget {
  const _ShortcutWidgetPreview({required this.kind, required this.widgets});

  final HomeWidgetKind kind;
  final HomeWidgetService widgets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>();
    final colors = shortcutWidgetColors(widgets, kind);
    final foreground = shortcutWidgetForeground(widgets, theme, kind);
    final locale = Localizations.localeOf(context);
    // ホーム画面へ焼く画像と同じく、入らない文言はアイコン・文字を小さくして
    // 収める（省略記号で切らない・語の途中で折らない）。
    final fit = ShortcutWidgetFit.of(
      label: shortcutWidgetLabel(l10n, kind),
      subLabel: shortcutWidgetSubLabel(l10n, kind),
      locale: locale,
    );
    const size = ShortcutWidgetDesign.tileSize;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _previewSize,
        child: FittedBox(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                ShortcutWidgetDesign.cornerRadius,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.first, colors.last],
              ),
            ),
            child: SizedBox.square(
              dimension: size,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShortcutWidgetDesign.horizontalPadding,
                ),
                child: MediaQuery.withNoTextScaling(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        shortcutWidgetIcon(kind),
                        size: fit.iconSize,
                        color: foreground,
                      ),
                      const SizedBox(height: ShortcutWidgetDesign.gapAfterIcon),
                      Text(
                        fit.label,
                        textAlign: TextAlign.center,
                        style: shortcutWidgetTextStyle(
                          locale: locale,
                          color: foreground,
                          size: fit.labelSize,
                          bold: true,
                        ),
                      ),
                      if (fit.subLabel != null)
                        Text(
                          fit.subLabel!,
                          textAlign: TextAlign.center,
                          style: shortcutWidgetTextStyle(
                            locale: locale,
                            color: foreground,
                            size: fit.subLabelSize,
                            bold: false,
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
    );
  }
}
