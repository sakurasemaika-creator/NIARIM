import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'tip_diagram.dart';
import 'tip_diagram_data.dart';
import 'tip_capture_data.dart';
import 'tip_screen_capture.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import '../../utils/name_collation.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/responsive.dart';
import '../../widgets/keep_together_text.dart';

/// ヘルプ（機能の説明）とは別に、「こうすると便利」という活用方法を
/// 紹介するTipsページ。ホーム画面のハンバーガーメニューから開く。
/// 一覧はタイトルだけのコンパクトな行にし、タップするとポップアップ
/// （_TipDetailDialog）でキャプチャと説明を横スライドで
/// 読める構成にしている。説明の分量に応じてページ数は可変（固定2ページ
/// に限らない）で、下部にページ位置インジケーター、右上に閉じるボタンを
/// 常設する。ヘルプ画面と同様、タイトル・説明・カテゴリ名から検索できる。
class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

/// 進捗ダイアログ（ProgressDialog、書き出し・複数フレーム加工時に表示）が
/// 10秒おきにランダム表示するTips用に、全カテゴリのTipsをタイトル・説明の
/// ペアへ平坦化して返す。Tips画面本体（[_TipsScreenState._buildCategories]）
/// と同じ一覧を参照するため、内容を追加・変更してもここでの二重管理は不要。
List<(String title, String description)> allTipEntries(AppLocalizations l10n) {
  return _buildTipCategories(
    l10n,
  ).expand((c) => c.tips).map((t) => (t.title, t.description)).toList();
}

class _TipsScreenState extends State<TipsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _resultsScroll = ScrollController(keepScrollOffset: false);
  String _searchQuery = '';

  @override
  void dispose() {
    _resultsScroll.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String value) {
    if (_resultsScroll.hasClients && _resultsScroll.offset != 0) {
      _resultsScroll.jumpTo(0);
    }
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearch('');
    _searchFocus.requestFocus();
  }

  List<_TipCategory> _buildCategories(AppLocalizations l10n) =>
      _buildTipCategories(l10n);

  // The text is written with ’ and no-break spaces (French), the keyboard
  // types ' and plain spaces: compare both in the same form.
  bool _matches(_Tip tip, String category) {
    if (_searchQuery.isEmpty) return true;
    final query = foldName(_searchQuery);
    return nameMatches(tip.title, query) ||
        nameMatches(tip.description, query) ||
        nameMatches(category, query);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final categories = _buildCategories(l10n)
        .map(
          (c) => _TipCategory(
            title: c.title,
            icon: c.icon,
            tips: c.tips.where((t) => _matches(t, c.title)).toList(),
          ),
        )
        .where((c) => c.tips.isNotEmpty)
        .toList();
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: FitOrHideTitle(l10n.tipsScreenTitle)),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                // 画面の色で塗る欄なので、打った字・ヒント・アイコンは本文の
                // 文字色（テーマの入力欄はメニューの色で塗りメニューの文字色）。
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: l10n.tipsSearchHint,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  // 入らないヒントは行を増やして全部出す（1行の欄のままだと、
                  // 仏語・文字2倍で「Rechercher une a…」と切れた）。
                  hintMaxLines: 4,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.projectListClearSearch,
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        ),
                  prefixIconColor: scheme.onSurfaceVariant,
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                onChanged: _updateSearch,
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.helpNoResults,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _resultsScroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 19,
                                    color: AccentTextTheme.of(context),
                                  ),
                                  const SizedBox(width: 8),
                                  // 1行に入らない名前（仏語・西語・大きな文字）は
                                  // 折り返す（幅を決めずに並べていたので、行が
                                  // 画面の外へはみ出していた）。韓国語の語は、
                                  // 1行に入れば途中で折らない。
                                  Flexible(
                                    child: messageText(
                                      category.title,
                                      style: localizedHeadingStyle(
                                        context,
                                        TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AccentTextTheme.of(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final tip in category.tips)
                                _TipListTile(tip: tip),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<_TipCategory> _buildTipCategories(AppLocalizations l10n) => [
  _TipCategory(
    title: l10n.tipsCategoryVideo,
    icon: Icons.movie_creation_outlined,
    tips: [
      _Tip(
        TipTopic.clipDuplicate,
        l10n.tipsClipDuplicateTitle,
        l10n.tipsClipDuplicateDesc,
      ),
      _Tip(
        TipTopic.textCaption,
        l10n.tipsTextCaptionTitle,
        l10n.tipsTextCaptionDesc,
      ),
      _Tip(
        TipTopic.audioRepeat,
        l10n.tipsAudioRepeatTitle,
        l10n.tipsAudioRepeatDesc,
      ),
      _Tip(
        TipTopic.verticalRuby,
        l10n.tipsVerticalRubyTitle,
        l10n.tipsVerticalRubyDesc,
      ),
      _Tip(
        TipTopic.endCardWatermark,
        l10n.tipsEndCardWatermarkTitle,
        l10n.tipsEndCardWatermarkDesc,
      ),
      _Tip(
        TipTopic.verticalPixelFont,
        l10n.tipsVerticalPixelFontTitle,
        l10n.tipsVerticalPixelFontDesc,
      ),
      _Tip(
        TipTopic.stampBlendMode,
        l10n.tipsStampBlendModeTitle,
        l10n.tipsStampBlendModeDesc,
      ),
      _Tip(
        TipTopic.videoTrimReuse,
        l10n.tipsVideoTrimReuseTitle,
        l10n.tipsVideoTrimReuseDesc,
      ),
      _Tip(
        TipTopic.timelineMarker,
        l10n.tipsTimelineMarkerTitle,
        l10n.tipsTimelineMarkerDesc,
      ),
      _Tip(
        TipTopic.communityYoutube,
        l10n.tipsCommunityYoutubeTitle,
        l10n.tipsCommunityYoutubeDesc,
      ),
    ],
  ),
  _TipCategory(
    title: l10n.tipsCategoryEfficiency,
    icon: Icons.speed_outlined,
    tips: [
      _Tip(
        TipTopic.autofillPreset,
        l10n.tipsAutofillPresetTitle,
        l10n.tipsAutofillPresetDesc,
      ),
      _Tip(
        TipTopic.officialAutomationPresets,
        l10n.tipsOfficialAutomationPresetsTitle,
        l10n.tipsOfficialAutomationPresetsDesc,
      ),
      _Tip(
        TipTopic.autofillBaseCoat,
        l10n.tipsAutofillBaseCoatTitle,
        l10n.tipsAutofillBaseCoatDesc,
      ),
      _Tip(
        TipTopic.autofillManualPartColor,
        l10n.tipsAutofillManualPartColorTitle,
        l10n.tipsAutofillManualPartColorDesc,
      ),
      _Tip(
        TipTopic.brushFavorite,
        l10n.tipsBrushFavoriteTitle,
        l10n.tipsBrushFavoriteDesc,
      ),
      _Tip(
        TipTopic.brushTrySaveTree,
        l10n.tipsBrushTrySaveTreeTitle,
        l10n.tipsBrushTrySaveTreeDesc,
      ),
      _Tip(
        TipTopic.eyedropperGesture,
        l10n.tipsEyedropperGestureTitle,
        l10n.tipsEyedropperGestureDesc,
      ),
      _Tip(
        TipTopic.magicWandLasso,
        l10n.tipsMagicWandLassoTitle,
        l10n.tipsMagicWandLassoDesc,
      ),
      _Tip(
        TipTopic.commonLayerFolder,
        l10n.tipsCommonLayerFolderTitle,
        l10n.tipsCommonLayerFolderDesc,
      ),
      _Tip(
        TipTopic.quickToolPenSub,
        l10n.tipsQuickToolPenSubTitle,
        l10n.tipsQuickToolPenSubDesc,
      ),
      _Tip(
        TipTopic.quickToolVariant,
        l10n.tipsQuickToolVariantTitle,
        l10n.tipsQuickToolVariantDesc,
      ),
      _Tip(
        TipTopic.autofillToneReuse,
        l10n.tipsAutofillToneReuseTitle,
        l10n.tipsAutofillToneReuseDesc,
      ),
      _Tip(
        TipTopic.autofillMisfill,
        l10n.tipsAutofillMisfillTitle,
        l10n.tipsAutofillMisfillDesc,
      ),
      _Tip(
        TipTopic.homeWidget,
        l10n.tipsHomeWidgetTitle,
        l10n.tipsHomeWidgetDesc,
      ),
      _Tip(
        TipTopic.autofillTransparentFix,
        l10n.tipsAutofillTransparentFixTitle,
        l10n.tipsAutofillTransparentFixDesc,
      ),
      _Tip(
        TipTopic.saveSlotAutoSave,
        l10n.tipsSaveSlotAutoSaveTitle,
        l10n.tipsSaveSlotAutoSaveDesc,
      ),
      _Tip(
        TipTopic.quickToolSwipe,
        l10n.tipsQuickToolSwipeTitle,
        l10n.tipsQuickToolSwipeDesc,
      ),
      _Tip(
        TipTopic.toolbarCustomize,
        l10n.tipsToolbarCustomizeTitle,
        l10n.tipsToolbarCustomizeDesc,
      ),
      _Tip(
        TipTopic.pcDexLayout,
        l10n.tipsPcDexLayoutTitle,
        l10n.tipsPcDexLayoutDesc,
      ),
      _Tip(
        TipTopic.commonLayerLipSync,
        l10n.tipsCommonLayerLipSyncTitle,
        l10n.tipsCommonLayerLipSyncDesc,
      ),
      _Tip(
        TipTopic.commonLayerKeyframe,
        l10n.tipsCommonLayerKeyframeTitle,
        l10n.tipsCommonLayerKeyframeDesc,
      ),
    ],
  ),
  _TipCategory(
    title: l10n.tipsCategoryDrawing,
    icon: Icons.brush_outlined,
    tips: [
      _Tip(
        TipTopic.transparentColor,
        l10n.tipsTransparentColorTitle,
        l10n.tipsTransparentColorDesc,
      ),
      _Tip(
        TipTopic.pressureCurve,
        l10n.tipsPressureCurveTitle,
        l10n.tipsPressureCurveDesc,
      ),
      _Tip(
        TipTopic.rulerOnion,
        l10n.tipsRulerOnionTitle,
        l10n.tipsRulerOnionDesc,
      ),
      _Tip(
        TipTopic.fourPanelBrush,
        l10n.tipsFourPanelBrushTitle,
        l10n.tipsFourPanelBrushDesc,
      ),
      _Tip(
        TipTopic.gradientTrace,
        l10n.tipsGradientTraceTitle,
        l10n.tipsGradientTraceDesc,
      ),
      _Tip(
        TipTopic.gradientOutlineHair,
        l10n.tipsGradientOutlineHairTitle,
        l10n.tipsGradientOutlineHairDesc,
      ),
      _Tip(TipTopic.brushFold, l10n.tipsBrushFoldTitle, l10n.tipsBrushFoldDesc),
      _Tip(
        TipTopic.strokeDecayFade,
        l10n.tipsStrokeDecayFadeTitle,
        l10n.tipsStrokeDecayFadeDesc,
      ),
      _Tip(
        TipTopic.colorMixingFade,
        l10n.tipsColorMixingFadeTitle,
        l10n.tipsColorMixingFadeDesc,
      ),
      _Tip(
        TipTopic.radialVignette,
        l10n.tipsRadialVignetteTitle,
        l10n.tipsRadialVignetteDesc,
      ),
      _Tip(
        TipTopic.clippingGradient,
        l10n.tipsClippingGradientTitle,
        l10n.tipsClippingGradientDesc,
      ),
      _Tip(
        TipTopic.drawingAreaCamera,
        l10n.tipsDrawingAreaCameraTitle,
        l10n.tipsDrawingAreaCameraDesc,
      ),
      _Tip(
        TipTopic.autofillBlendMode,
        l10n.tipsAutofillBlendModeTitle,
        l10n.tipsAutofillBlendModeDesc,
      ),
      _Tip(
        TipTopic.roughLayerRescue,
        l10n.tipsRoughLayerRescueTitle,
        l10n.tipsRoughLayerRescueDesc,
      ),
      _Tip(
        TipTopic.lineArtExtraction,
        l10n.tipsLineArtExtractionTitle,
        l10n.tipsLineArtExtractionDesc,
      ),
      _Tip(
        TipTopic.lineColorUsage,
        l10n.tipsLineColorUsageTitle,
        l10n.tipsLineColorUsageDesc,
      ),
      _Tip(
        TipTopic.blushAutofill,
        l10n.tipsBlushAutofillTitle,
        l10n.tipsBlushAutofillDesc,
      ),
      _Tip(
        TipTopic.stockingDenier,
        l10n.tipsStockingDenierTitle,
        l10n.tipsStockingDenierDesc,
      ),
    ],
  ),
  _TipCategory(
    title: l10n.tipsCategoryEffects,
    icon: Icons.auto_awesome_outlined,
    tips: [
      _Tip(TipTopic.rainNoise, l10n.tipsRainNoiseTitle, l10n.tipsRainNoiseDesc),
      _Tip(
        TipTopic.texturePrismVhs,
        l10n.tipsTexturePrismVhsTitle,
        l10n.tipsTexturePrismVhsDesc,
      ),
      _Tip(
        TipTopic.partKeyframeGroup,
        l10n.tipsPartKeyframeGroupTitle,
        l10n.tipsPartKeyframeGroupDesc,
      ),
      _Tip(
        TipTopic.outlineAnimeStyle,
        l10n.tipsOutlineAnimeStyleTitle,
        l10n.tipsOutlineAnimeStyleDesc,
      ),
      _Tip(
        TipTopic.levelsToneCurve,
        l10n.tipsLevelsToneCurveTitle,
        l10n.tipsLevelsToneCurveDesc,
      ),
      _Tip(
        TipTopic.toneCurveSepia,
        l10n.tipsToneCurveSepiaTitle,
        l10n.tipsToneCurveSepiaDesc,
      ),
      _Tip(
        TipTopic.cameraLensBlur,
        l10n.tipsCameraLensBlurTitle,
        l10n.tipsCameraLensBlurDesc,
      ),
      _Tip(
        TipTopic.webmCommonLayer,
        l10n.tipsWebmCommonLayerTitle,
        l10n.tipsWebmCommonLayerDesc,
      ),
      _Tip(
        TipTopic.leftHandedWorkspace,
        l10n.tipsLeftHandedWorkspaceTitle,
        l10n.tipsLeftHandedWorkspaceDesc,
      ),
      _Tip(
        TipTopic.blendModeUsage,
        l10n.tipsBlendModeUsageTitle,
        l10n.tipsBlendModeUsageDesc,
      ),
      _Tip(
        TipTopic.fisheyeChromatic,
        l10n.tipsFisheyeChromaticTitle,
        l10n.tipsFisheyeChromaticDesc,
      ),
      _Tip(
        TipTopic.lensDistortion,
        l10n.tipsLensDistortionTitle,
        l10n.tipsLensDistortionDesc,
      ),
      _Tip(
        TipTopic.sphereShading,
        l10n.tipsSphereShadingTitle,
        l10n.tipsSphereShadingDesc,
      ),
      _Tip(
        TipTopic.backgroundBlend,
        l10n.tipsBackgroundBlendTitle,
        l10n.tipsBackgroundBlendDesc,
      ),
    ],
  ),
  _TipCategory(
    title: l10n.tipsCategoryExport,
    icon: Icons.ios_share_outlined,
    tips: [
      _Tip(
        TipTopic.exportFormat,
        l10n.tipsExportFormatTitle,
        l10n.tipsExportFormatDesc,
      ),
      _Tip(
        TipTopic.gestureShortcut,
        l10n.tipsGestureShortcutTitle,
        l10n.tipsGestureShortcutDesc,
      ),
      _Tip(
        TipTopic.lowSpecSettings,
        l10n.tipsLowSpecSettingsTitle,
        l10n.tipsLowSpecSettingsDesc,
      ),
      _Tip(
        TipTopic.seriesPresetFolder,
        l10n.tipsSeriesPresetFolderTitle,
        l10n.tipsSeriesPresetFolderDesc,
      ),
      _Tip(
        TipTopic.mosaicChromatic,
        l10n.tipsMosaicChromaticTitle,
        l10n.tipsMosaicChromaticDesc,
      ),
      _Tip(
        TipTopic.pixelToneRetro,
        l10n.tipsPixelToneRetroTitle,
        l10n.tipsPixelToneRetroDesc,
      ),
      _Tip(
        TipTopic.blurVignetteBg,
        l10n.tipsBlurVignetteBgTitle,
        l10n.tipsBlurVignetteBgDesc,
      ),
      _Tip(
        TipTopic.sepiaVignette,
        l10n.tipsSepiaVignetteTitle,
        l10n.tipsSepiaVignetteDesc,
      ),
      _Tip(
        TipTopic.transferDevice,
        l10n.tipsTransferDeviceTitle,
        l10n.tipsTransferDeviceDesc,
      ),
      _Tip(
        TipTopic.transferCustomization,
        l10n.tipsTransferCustomizationTitle,
        l10n.tipsTransferCustomizationDesc,
      ),
    ],
  ),
];

/// 一覧に並ぶ1件のTipsの行。図解のミニアイコンとタイトルだけを表示する
/// コンパクトな行で、タップすると詳細ポップアップ（_TipDetailDialog）を開く。
class _TipListTile extends StatelessWidget {
  final _Tip tip;
  const _TipListTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showBadge = MediaQuery.textScalerOf(context).scale(14) < 21;
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.15,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog(
            context: context,
            builder: (_) => _TipDetailDialog(tip: tip),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                if (showBadge) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(
                        colors: [
                          scheme.tertiary.withValues(alpha: 0.25),
                          scheme.tertiary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: scheme.tertiary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  // 韓国語の語は、1行に入れば途中で折らない（「부 / 위별로」と
                  // 折れた）。長音符・小さいかな・閉じ括弧で行を始めない
                  // （「パ / ーツ」と長音符で始まる行に折れた）。
                  child: messageText(
                    tip.title,
                    keepLineStarts: true,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tips詳細のポップアップ。各ページに図解と本文を表示する。
/// 説明文を読みやすい分量ごとに分割し、1ページに収まる分量ならページ数は
/// 1のまま（＝スワイプ不要）、収まらない場合は必要なだけページ数を
/// 増やして横スライドで読み進める（ページ数の上限は設けない）。右上の
/// 閉じるボタンと、下部のページ位置インジケーター（何ページ中何ページ目か）
/// を表示する。
class _TipDetailDialog extends StatefulWidget {
  final _Tip tip;
  const _TipDetailDialog({required this.tip});

  @override
  State<_TipDetailDialog> createState() => _TipDetailDialogState();
}

class _TipDetailDialogState extends State<_TipDetailDialog> {
  final _pageController = PageController();
  int _page = 0;
  final _captureIndexByPage = <int, int>{};
  late final List<String> _textPages = _splitIntoPages(
    widget.tip.description,
    illustrateByParagraph: widget.tip.topic.illustrateByParagraph,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 説明文を読みやすい分量へ分割する。単純に上限文字数で区切ると、
  /// 最後のページだけ文章が短く「スカスカ」になりがちなため、まず必要な
  /// ページ数を概算し、そのページ数へ均等に近い分量で配分し直す（＝
  /// どのページも中身の詰まった1ページとして成立するようにする）。改行
  /// （段落）の区切りを優先して尊重し、1段落だけで目標分量を超える場合は
  /// そのまま1ページにする。
  static List<String> _splitIntoPages(
    String text, {
    required bool illustrateByParagraph,
  }) {
    const maxCharsPerPage = 220;
    final paragraphs = text
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return [text];
    if (illustrateByParagraph) return paragraphs;
    final totalLength =
        paragraphs.fold<int>(0, (sum, p) => sum + p.length) +
        (paragraphs.length - 1);
    final pageCount = (totalLength / maxCharsPerPage).ceil().clamp(
      1,
      paragraphs.length,
    );
    if (pageCount <= 1) return [paragraphs.join('\n')];
    final targetPerPage = totalLength / pageCount;
    final pages = <String>[];
    var current = '';
    for (final p in paragraphs) {
      final candidate = current.isEmpty ? p : '$current\n$p';
      final remainingPages = pageCount - pages.length;
      if (candidate.length > targetPerPage &&
          current.isNotEmpty &&
          remainingPages > 1) {
        pages.add(current);
        current = p;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) pages.add(current);
    return pages.isEmpty ? [text] : pages;
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _textPages.length || !_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _step(int direction, AppLocalizations l10n) {
    final count = _captures(_page, l10n).length;
    final capture = (_captureIndexByPage[_page] ?? 0) + direction;
    if (capture >= 0 && capture < count) {
      setState(() => _captureIndexByPage[_page] = capture);
      return;
    }
    final nextPage = _page + direction;
    if (nextPage < 0 || nextPage >= _textPages.length) return;
    final nextCount = _captures(nextPage, l10n).length;
    setState(() {
      _captureIndexByPage[nextPage] = direction < 0 && nextCount > 0
          ? nextCount - 1
          : 0;
    });
    _goToPage(nextPage);
  }

  List<TipScreenCapture> _captures(int page, AppLocalizations l10n) =>
      tipCaptures(
        widget.tip.topic,
        widget.tip.topic.illustrateByParagraph ? page : 0,
        l10n,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPages = _textPages.length;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 24).clamp(0.0, 600.0);
    final dialogHeight = (screenSize.height - 64).clamp(0.0, 680.0);
    final words = MaterialLocalizations.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);
    // Illustrated steps and text start at the same positions for every tip.
    final longTitle = screenSize.width < 360 || scaler.scale(15) > 18;
    final titleHeight = scaler.scale(15) * (longTitle ? 4.2 : 2.8);

    Widget buildPage(int index) {
      return SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: titleHeight),
              child: Semantics(
                header: true,
                child: messageText(
                  widget.tip.title,
                  keepLineStarts: true,
                  keepLastPhrase: true,
                  style: localizedHeadingStyle(
                    context,
                    TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AccentTextTheme.of(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TipDiagram(
              key: ValueKey((widget.tip.topic, index)),
              steps: widget.tip.topic.steps(l10n, index),
              height: dialogHeight * .60,
              isComparison: widget.tip.topic.isComparison,
              captures: _captures(index, l10n),
              captureIndex: _captureIndexByPage[index] ?? 0,
              onCaptureChanged: (capture) {
                setState(() => _captureIndexByPage[index] = capture);
              },
            ),
            const SizedBox(height: 12),
            Text(
              _textPages[index],
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _step(-1, l10n),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _step(1, l10n),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          constraints: BoxConstraints(maxHeight: dialogHeight),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Stack(
              children: [
                if (totalPages == 1)
                  buildPage(0)
                else
                  Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: totalPages,
                          onPageChanged: (p) => setState(() => _page = p),
                          itemBuilder: (_, index) => buildPage(index),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: words.previousPageTooltip,
                            onPressed: _page == 0
                                ? null
                                : () => _goToPage(_page - 1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          if (totalPages <= 6)
                            for (var i = 0; i < totalPages; i++)
                              Semantics(
                                selected: i == _page,
                                child: IconButton(
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 48,
                                  ),
                                  padding: EdgeInsets.zero,
                                  tooltip: words.pageRowsInfoTitle(
                                    i + 1,
                                    i + 1,
                                    totalPages,
                                    false,
                                  ),
                                  icon: Icon(
                                    i == _page
                                        ? Icons.circle
                                        : Icons.circle_outlined,
                                    size: 9,
                                    color: i == _page
                                        ? scheme.primary
                                        : scheme.outline,
                                  ),
                                  onPressed: () => _goToPage(i),
                                ),
                              )
                          else
                            Text(
                              '${_page + 1} / $totalPages',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          IconButton(
                            key: const ValueKey('tipNextTextPage'),
                            tooltip: words.nextPageTooltip,
                            onPressed: _page == totalPages - 1
                                ? null
                                : () => _goToPage(_page + 1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                // 右上の閉じるボタン
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCategory {
  final String title;
  final IconData icon;
  final List<_Tip> tips;
  const _TipCategory({
    required this.title,
    required this.icon,
    required this.tips,
  });
}

class _Tip {
  final TipTopic topic;
  final String title;
  final String description;
  const _Tip(this.topic, this.title, this.description);
}
