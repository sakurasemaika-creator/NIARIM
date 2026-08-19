import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'tip_diagrams.dart';

/// ヘルプ（機能の説明）とは別に、「こうすると便利」という活用方法を
/// 紹介するTipsページ。ホーム画面のハンバーガーメニューから開く。
/// 各項目は「図解＋要点」「タイトル＋詳しい説明」の2ページを横スライドで
/// 見られる構成にし、1画面あたりの図・文章を大きく表示できるようにしている。
/// ヘルプ画面と同様、タイトル・説明・カテゴリ名から検索できる。
class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TipCategory> _buildCategories(AppLocalizations l10n) => [
        _TipCategory(
          title: l10n.tipsCategoryVideo,
          icon: Icons.movie_creation_outlined,
          tips: [
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsClipDuplicateTitle, l10n.tipsClipDuplicateDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsAudioRepeatTitle, l10n.tipsAudioRepeatDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsVerticalRubyTitle, l10n.tipsVerticalRubyDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsFadeEndCardTitle, l10n.tipsFadeEndCardDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsEndCardWatermarkTitle, l10n.tipsEndCardWatermarkDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsVerticalPixelFontTitle, l10n.tipsVerticalPixelFontDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsStampBlendModeTitle, l10n.tipsStampBlendModeDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsGifLoopTitle, l10n.tipsGifLoopDesc),
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsVideoTrimReuseTitle, l10n.tipsVideoTrimReuseDesc),
            _Tip(TipDiagramKind.timelineMarker, l10n.tipsTimelineMarkerTitle, l10n.tipsTimelineMarkerDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEfficiency,
          icon: Icons.speed_outlined,
          tips: [
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillPresetTitle, l10n.tipsAutofillPresetDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsBrushFavoriteTitle, l10n.tipsBrushFavoriteDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsBrushTrySaveTreeTitle, l10n.tipsBrushTrySaveTreeDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsEyedropperGestureTitle, l10n.tipsEyedropperGestureDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsMagicWandLassoTitle, l10n.tipsMagicWandLassoDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsCommonLayerFolderTitle, l10n.tipsCommonLayerFolderDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsQuickToolPenSubTitle, l10n.tipsQuickToolPenSubDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillToneReuseTitle, l10n.tipsAutofillToneReuseDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsSaveSlotAutoSaveTitle, l10n.tipsSaveSlotAutoSaveDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsQuickToolSwipeTitle, l10n.tipsQuickToolSwipeDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsToolbarCustomizeTitle, l10n.tipsToolbarCustomizeDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryDrawing,
          icon: Icons.brush_outlined,
          tips: [
            _Tip(TipDiagramKind.onionSkin, l10n.tipsOnionSkinTitle, l10n.tipsOnionSkinDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsPressureCurveTitle, l10n.tipsPressureCurveDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsRulerOnionTitle, l10n.tipsRulerOnionDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsGradientTraceTitle, l10n.tipsGradientTraceDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsStrokeDecayFadeTitle, l10n.tipsStrokeDecayFadeDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsColorMixingFadeTitle, l10n.tipsColorMixingFadeDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsRadialVignetteTitle, l10n.tipsRadialVignetteDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsClippingGradientTitle, l10n.tipsClippingGradientDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsColorPickerLongPressTitle, l10n.tipsColorPickerLongPressDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsDrawingAreaCameraTitle, l10n.tipsDrawingAreaCameraDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillBlendModeTitle, l10n.tipsAutofillBlendModeDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEffects,
          icon: Icons.auto_awesome_outlined,
          tips: [
            _Tip(TipDiagramKind.effectFilter, l10n.tipsEffectFilterTitle, l10n.tipsEffectFilterDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsCameraKeyframeTitle, l10n.tipsCameraKeyframeDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsRainNoiseTitle, l10n.tipsRainNoiseDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsPartKeyframeGroupTitle, l10n.tipsPartKeyframeGroupDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsOutlineAnimeStyleTitle, l10n.tipsOutlineAnimeStyleDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsLevelsToneCurveTitle, l10n.tipsLevelsToneCurveDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsToneCurveSepiaTitle, l10n.tipsToneCurveSepiaDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsCameraLensBlurTitle, l10n.tipsCameraLensBlurDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsWebmCommonLayerTitle, l10n.tipsWebmCommonLayerDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsLeftHandedWorkspaceTitle, l10n.tipsLeftHandedWorkspaceDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryExport,
          icon: Icons.ios_share_outlined,
          tips: [
            _Tip(TipDiagramKind.exportFormat, l10n.tipsExportFormatTitle, l10n.tipsExportFormatDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsGestureShortcutTitle, l10n.tipsGestureShortcutDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsLowSpecSettingsTitle, l10n.tipsLowSpecSettingsDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsSeriesPresetFolderTitle, l10n.tipsSeriesPresetFolderDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsMosaicChromaticTitle, l10n.tipsMosaicChromaticDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsPixelToneRetroTitle, l10n.tipsPixelToneRetroDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsBlurVignetteBgTitle, l10n.tipsBlurVignetteBgDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsSepiaVignetteTitle, l10n.tipsSepiaVignetteDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsFolderHierarchyTitle, l10n.tipsFolderHierarchyDesc),
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsTransferDeviceTitle, l10n.tipsTransferDeviceDesc),
          ],
        ),
      ];

  bool _matches(_Tip tip, String category) =>
      _searchQuery.isEmpty ||
      tip.title.contains(_searchQuery) ||
      tip.description.contains(_searchQuery) ||
      category.contains(_searchQuery);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final categories = _buildCategories(l10n)
        .map((c) => _TipCategory(title: c.title, icon: c.icon, tips: c.tips.where((t) => _matches(t, c.title)).toList()))
        .where((c) => c.tips.isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipsScreenTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.tipsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(l10n.helpNoResults,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
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
                                  Icon(category.icon, size: 18, color: scheme.primary),
                                  const SizedBox(width: 6),
                                  Text(category.title,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.primary)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final tip in category.tips) _TipCard(tip: tip),
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

/// 1件のTipsを「図解＋要点」「詳しい説明」の2ページで横スライド表示する
/// カード。ページ位置はドットインジケーターで示す。
class _TipCard extends StatefulWidget {
  final _Tip tip;
  const _TipCard({required this.tip});

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      children: [
                        Expanded(child: Center(child: TipDiagram(widget.tip.diagram))),
                        const SizedBox(height: 8),
                        Text(widget.tip.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.tip.title,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.primary)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(widget.tip.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCategory {
  final String title;
  final IconData icon;
  final List<_Tip> tips;
  const _TipCategory({required this.title, required this.icon, required this.tips});
}

class _Tip {
  final TipDiagramKind diagram;
  final String title;
  final String description;
  const _Tip(this.diagram, this.title, this.description);
}
