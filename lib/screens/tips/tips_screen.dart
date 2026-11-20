import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'tip_captures.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import '../../utils/name_collation.dart';
import '../../widgets/fit_or_hide_title.dart';
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

class _TipsScreenState extends State<TipsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
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
                  prefixIconColor: scheme.onSurfaceVariant,
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        l10n.helpNoResults,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                    size: 18,
                                    color: AccentTextTheme.of(context),
                                  ),
                                  const SizedBox(width: 6),
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
                                          fontSize: 14,
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
        'clipDuplicate',
        l10n.tipsClipDuplicateTitle,
        l10n.tipsClipDuplicateDesc,
      ),
      _Tip('textCaption', l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
      _Tip('audioRepeat', l10n.tipsAudioRepeatTitle, l10n.tipsAudioRepeatDesc),
      _Tip(
        'verticalRuby',
        l10n.tipsVerticalRubyTitle,
        l10n.tipsVerticalRubyDesc,
      ),
      _Tip(
        'endCardWatermark',
        l10n.tipsEndCardWatermarkTitle,
        l10n.tipsEndCardWatermarkDesc,
      ),
      _Tip(
        'verticalPixelFont',
        l10n.tipsVerticalPixelFontTitle,
        l10n.tipsVerticalPixelFontDesc,
      ),
      _Tip(
        'stampBlendMode',
        l10n.tipsStampBlendModeTitle,
        l10n.tipsStampBlendModeDesc,
      ),
      _Tip(
        'videoTrimReuse',
        l10n.tipsVideoTrimReuseTitle,
        l10n.tipsVideoTrimReuseDesc,
      ),
      _Tip(
        'timelineMarker',
        l10n.tipsTimelineMarkerTitle,
        l10n.tipsTimelineMarkerDesc,
      ),
      _Tip(
        'communityYoutube',
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
        'autofillPreset',
        l10n.tipsAutofillPresetTitle,
        l10n.tipsAutofillPresetDesc,
      ),
      _Tip(
        'officialAutomationPresets',
        l10n.tipsOfficialAutomationPresetsTitle,
        l10n.tipsOfficialAutomationPresetsDesc,
      ),
      _Tip(
        'autofillBaseCoat',
        l10n.tipsAutofillBaseCoatTitle,
        l10n.tipsAutofillBaseCoatDesc,
      ),
      _Tip(
        'autofillManualPartColor',
        l10n.tipsAutofillManualPartColorTitle,
        l10n.tipsAutofillManualPartColorDesc,
      ),
      _Tip(
        'brushFavorite',
        l10n.tipsBrushFavoriteTitle,
        l10n.tipsBrushFavoriteDesc,
      ),
      _Tip(
        'brushTrySaveTree',
        l10n.tipsBrushTrySaveTreeTitle,
        l10n.tipsBrushTrySaveTreeDesc,
      ),
      _Tip(
        'eyedropperGesture',
        l10n.tipsEyedropperGestureTitle,
        l10n.tipsEyedropperGestureDesc,
      ),
      _Tip(
        'magicWandLasso',
        l10n.tipsMagicWandLassoTitle,
        l10n.tipsMagicWandLassoDesc,
      ),
      _Tip(
        'commonLayerFolder',
        l10n.tipsCommonLayerFolderTitle,
        l10n.tipsCommonLayerFolderDesc,
      ),
      _Tip(
        'quickToolPenSub',
        l10n.tipsQuickToolPenSubTitle,
        l10n.tipsQuickToolPenSubDesc,
      ),
      _Tip(
        'quickToolVariant',
        l10n.tipsQuickToolVariantTitle,
        l10n.tipsQuickToolVariantDesc,
      ),
      _Tip(
        'autofillToneReuse',
        l10n.tipsAutofillToneReuseTitle,
        l10n.tipsAutofillToneReuseDesc,
      ),
      _Tip(
        'autofillMisfill',
        l10n.tipsAutofillMisfillTitle,
        l10n.tipsAutofillMisfillDesc,
      ),
      _Tip('homeWidget', l10n.tipsHomeWidgetTitle, l10n.tipsHomeWidgetDesc),
      _Tip(
        'autofillTransparentFix',
        l10n.tipsAutofillTransparentFixTitle,
        l10n.tipsAutofillTransparentFixDesc,
      ),
      _Tip(
        'saveSlotAutoSave',
        l10n.tipsSaveSlotAutoSaveTitle,
        l10n.tipsSaveSlotAutoSaveDesc,
      ),
      _Tip(
        'quickToolSwipe',
        l10n.tipsQuickToolSwipeTitle,
        l10n.tipsQuickToolSwipeDesc,
      ),
      _Tip(
        'toolbarCustomize',
        l10n.tipsToolbarCustomizeTitle,
        l10n.tipsToolbarCustomizeDesc,
      ),
      _Tip('pcDexLayout', l10n.tipsPcDexLayoutTitle, l10n.tipsPcDexLayoutDesc),
      _Tip(
        'commonLayerLipSync',
        l10n.tipsCommonLayerLipSyncTitle,
        l10n.tipsCommonLayerLipSyncDesc,
      ),
      _Tip(
        'commonLayerKeyframe',
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
        'transparentColor',
        l10n.tipsTransparentColorTitle,
        l10n.tipsTransparentColorDesc,
      ),
      _Tip(
        'pressureCurve',
        l10n.tipsPressureCurveTitle,
        l10n.tipsPressureCurveDesc,
      ),
      _Tip('rulerOnion', l10n.tipsRulerOnionTitle, l10n.tipsRulerOnionDesc),
      _Tip(
        'fourPanelBrush',
        l10n.tipsFourPanelBrushTitle,
        l10n.tipsFourPanelBrushDesc,
      ),
      _Tip(
        'gradientTrace',
        l10n.tipsGradientTraceTitle,
        l10n.tipsGradientTraceDesc,
      ),
      _Tip(
        'gradientOutlineHair',
        l10n.tipsGradientOutlineHairTitle,
        l10n.tipsGradientOutlineHairDesc,
      ),
      _Tip('brushFold', l10n.tipsBrushFoldTitle, l10n.tipsBrushFoldDesc),
      _Tip(
        'strokeDecayFade',
        l10n.tipsStrokeDecayFadeTitle,
        l10n.tipsStrokeDecayFadeDesc,
      ),
      _Tip(
        'colorMixingFade',
        l10n.tipsColorMixingFadeTitle,
        l10n.tipsColorMixingFadeDesc,
      ),
      _Tip(
        'radialVignette',
        l10n.tipsRadialVignetteTitle,
        l10n.tipsRadialVignetteDesc,
      ),
      _Tip(
        'clippingGradient',
        l10n.tipsClippingGradientTitle,
        l10n.tipsClippingGradientDesc,
      ),
      _Tip(
        'drawingAreaCamera',
        l10n.tipsDrawingAreaCameraTitle,
        l10n.tipsDrawingAreaCameraDesc,
      ),
      _Tip(
        'autofillBlendMode',
        l10n.tipsAutofillBlendModeTitle,
        l10n.tipsAutofillBlendModeDesc,
      ),
      _Tip(
        'roughLayerRescue',
        l10n.tipsRoughLayerRescueTitle,
        l10n.tipsRoughLayerRescueDesc,
      ),
      _Tip(
        'lineArtExtraction',
        l10n.tipsLineArtExtractionTitle,
        l10n.tipsLineArtExtractionDesc,
      ),
      _Tip(
        'lineColorUsage',
        l10n.tipsLineColorUsageTitle,
        l10n.tipsLineColorUsageDesc,
      ),
      _Tip(
        'blushAutofill',
        l10n.tipsBlushAutofillTitle,
        l10n.tipsBlushAutofillDesc,
      ),
      _Tip(
        'stockingDenier',
        l10n.tipsStockingDenierTitle,
        l10n.tipsStockingDenierDesc,
      ),
    ],
  ),
  _TipCategory(
    title: l10n.tipsCategoryEffects,
    icon: Icons.auto_awesome_outlined,
    tips: [
      _Tip('rainNoise', l10n.tipsRainNoiseTitle, l10n.tipsRainNoiseDesc),
      _Tip(
        'texturePrismVhs',
        l10n.tipsTexturePrismVhsTitle,
        l10n.tipsTexturePrismVhsDesc,
      ),
      _Tip(
        'partKeyframeGroup',
        l10n.tipsPartKeyframeGroupTitle,
        l10n.tipsPartKeyframeGroupDesc,
      ),
      _Tip(
        'outlineAnimeStyle',
        l10n.tipsOutlineAnimeStyleTitle,
        l10n.tipsOutlineAnimeStyleDesc,
      ),
      _Tip(
        'levelsToneCurve',
        l10n.tipsLevelsToneCurveTitle,
        l10n.tipsLevelsToneCurveDesc,
      ),
      _Tip(
        'toneCurveSepia',
        l10n.tipsToneCurveSepiaTitle,
        l10n.tipsToneCurveSepiaDesc,
      ),
      _Tip(
        'cameraLensBlur',
        l10n.tipsCameraLensBlurTitle,
        l10n.tipsCameraLensBlurDesc,
      ),
      _Tip(
        'webmCommonLayer',
        l10n.tipsWebmCommonLayerTitle,
        l10n.tipsWebmCommonLayerDesc,
      ),
      _Tip(
        'leftHandedWorkspace',
        l10n.tipsLeftHandedWorkspaceTitle,
        l10n.tipsLeftHandedWorkspaceDesc,
      ),
      _Tip(
        'blendModeUsage',
        l10n.tipsBlendModeUsageTitle,
        l10n.tipsBlendModeUsageDesc,
      ),
      _Tip(
        'fisheyeChromatic',
        l10n.tipsFisheyeChromaticTitle,
        l10n.tipsFisheyeChromaticDesc,
      ),
      _Tip(
        'lensDistortion',
        l10n.tipsLensDistortionTitle,
        l10n.tipsLensDistortionDesc,
      ),
      _Tip(
        'sphereShading',
        l10n.tipsSphereShadingTitle,
        l10n.tipsSphereShadingDesc,
      ),
      _Tip(
        'backgroundBlend',
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
        'exportFormat',
        l10n.tipsExportFormatTitle,
        l10n.tipsExportFormatDesc,
      ),
      _Tip(
        'gestureShortcut',
        l10n.tipsGestureShortcutTitle,
        l10n.tipsGestureShortcutDesc,
      ),
      _Tip(
        'lowSpecSettings',
        l10n.tipsLowSpecSettingsTitle,
        l10n.tipsLowSpecSettingsDesc,
      ),
      _Tip(
        'seriesPresetFolder',
        l10n.tipsSeriesPresetFolderTitle,
        l10n.tipsSeriesPresetFolderDesc,
      ),
      _Tip(
        'mosaicChromatic',
        l10n.tipsMosaicChromaticTitle,
        l10n.tipsMosaicChromaticDesc,
      ),
      _Tip(
        'pixelToneRetro',
        l10n.tipsPixelToneRetroTitle,
        l10n.tipsPixelToneRetroDesc,
      ),
      _Tip(
        'blurVignetteBg',
        l10n.tipsBlurVignetteBgTitle,
        l10n.tipsBlurVignetteBgDesc,
      ),
      _Tip(
        'sepiaVignette',
        l10n.tipsSepiaVignetteTitle,
        l10n.tipsSepiaVignetteDesc,
      ),
      _Tip(
        'transferDevice',
        l10n.tipsTransferDeviceTitle,
        l10n.tipsTransferDeviceDesc,
      ),
      _Tip(
        'transferCustomization',
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
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
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tips詳細のポップアップ。各ページに図解と本文の両方を必ず表示する。
/// 説明文を読みやすい分量ごとに分割し、1ページに収まる分量ならページ数は
/// 1のまま（＝スワイプ不要）、収まらない場合は必要なだけページ数を
/// 増やして横スライドで読み進める（ページ数の上限は設けない）。右上の
/// 閉じるボタンと、下部のページ位置インジケーター（何ページ中何ページ目か）
/// を常設する。
class _TipDetailDialog extends StatefulWidget {
  final _Tip tip;
  const _TipDetailDialog({required this.tip});

  @override
  State<_TipDetailDialog> createState() => _TipDetailDialogState();
}

class _TipDetailDialogState extends State<_TipDetailDialog> {
  final _pageController = PageController();
  int _page = 0;
  late final List<String> _textPages = _splitIntoPages(widget.tip.description);

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
  static List<String> _splitIntoPages(String text) {
    const maxCharsPerPage = 220;
    final paragraphs = text
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return [text];
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPages = _textPages.length;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 32).clamp(280.0, 480.0);
    final dialogHeight = (screenSize.height - 64).clamp(420.0, 680.0);
    final words = MaterialLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goToPage(_page - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goToPage(_page + 1),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: totalPages,
                        onPageChanged: (p) => setState(() => _page = p),
                        itemBuilder: (context, index) {
                          final capture = tipCaptureFor(widget.tip.id, index);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height:
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(15) *
                                      4.2,
                                  child: SingleChildScrollView(
                                    primary: false,
                                    child: Text(
                                      widget.tip.title,
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
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: dialogHeight * .36,
                                  child: capture == null
                                      ? null
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.asset(
                                            capture,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            semanticLabel: widget.tip.title,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _textPages[index],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (totalPages > 1)
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
  final String id;
  final String title;
  final String description;
  const _Tip(this.id, this.title, this.description);
}
