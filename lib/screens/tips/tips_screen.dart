import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'tip_diagrams.dart';

/// ヘルプ（機能の説明）とは別に、「こうすると便利」という活用方法を
/// 紹介するTipsページ。ホーム画面のハンバーガーメニューから開く。
/// 一覧はタイトルだけのコンパクトな行にし、タップするとポップアップ
/// （_TipDetailDialog）で「図解＋要点」→「詳しい説明」を横スライドで
/// 読める構成にしている。説明の分量に応じてページ数は可変（固定2ページ
/// に限らない）で、下部にページ位置インジケーター、右上に閉じるボタンを
/// 常設する。ヘルプ画面と同様、タイトル・説明・カテゴリ名から検索できる。
class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

/// 進捗ダイアログ（ProgressDialog、仕様書13：書き出し・複数フレーム加工時）が
/// 10秒おきにランダム表示するTips用に、全カテゴリのTipsをタイトル・説明の
/// ペアへ平坦化して返す。Tips画面本体（[_TipsScreenState._buildCategories]）
/// と同じ一覧を参照するため、内容を追加・変更してもここでの二重管理は不要。
List<(String title, String description)> allTipEntries(AppLocalizations l10n) {
  return _buildTipCategories(l10n)
      .expand((c) => c.tips)
      .map((t) => (t.title, t.description))
      .toList();
}

class _TipsScreenState extends State<TipsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TipCategory> _buildCategories(AppLocalizations l10n) => _buildTipCategories(l10n);

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
                              for (final tip in category.tips) _TipListTile(tip: tip),
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
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsClipDuplicateTitle, l10n.tipsClipDuplicateDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsAudioRepeatTitle, l10n.tipsAudioRepeatDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsVerticalRubyTitle, l10n.tipsVerticalRubyDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsEndCardWatermarkTitle, l10n.tipsEndCardWatermarkDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsVerticalPixelFontTitle, l10n.tipsVerticalPixelFontDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsStampBlendModeTitle, l10n.tipsStampBlendModeDesc),
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
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsQuickToolVariantTitle, l10n.tipsQuickToolVariantDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillToneReuseTitle, l10n.tipsAutofillToneReuseDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsSaveSlotAutoSaveTitle, l10n.tipsSaveSlotAutoSaveDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsQuickToolSwipeTitle, l10n.tipsQuickToolSwipeDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsToolbarCustomizeTitle, l10n.tipsToolbarCustomizeDesc),
            _Tip(TipDiagramKind.pcDexLayout, l10n.tipsPcDexLayoutTitle, l10n.tipsPcDexLayoutDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsCommonLayerLipSyncTitle, l10n.tipsCommonLayerLipSyncDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsCommonLayerKeyframeTitle, l10n.tipsCommonLayerKeyframeDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryDrawing,
          icon: Icons.brush_outlined,
          tips: [
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsTransparentColorTitle, l10n.tipsTransparentColorDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsPressureCurveTitle, l10n.tipsPressureCurveDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsRulerOnionTitle, l10n.tipsRulerOnionDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsGradientTraceTitle, l10n.tipsGradientTraceDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsStrokeDecayFadeTitle, l10n.tipsStrokeDecayFadeDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsColorMixingFadeTitle, l10n.tipsColorMixingFadeDesc),
            _Tip(TipDiagramKind.onionSkin, l10n.tipsRadialVignetteTitle, l10n.tipsRadialVignetteDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsClippingGradientTitle, l10n.tipsClippingGradientDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsDrawingAreaCameraTitle, l10n.tipsDrawingAreaCameraDesc),
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillBlendModeTitle, l10n.tipsAutofillBlendModeDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEffects,
          icon: Icons.auto_awesome_outlined,
          tips: [
            _Tip(TipDiagramKind.effectFilter, l10n.tipsRainNoiseTitle, l10n.tipsRainNoiseDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsPartKeyframeGroupTitle, l10n.tipsPartKeyframeGroupDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsOutlineAnimeStyleTitle, l10n.tipsOutlineAnimeStyleDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsLevelsToneCurveTitle, l10n.tipsLevelsToneCurveDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsToneCurveSepiaTitle, l10n.tipsToneCurveSepiaDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsCameraLensBlurTitle, l10n.tipsCameraLensBlurDesc),
            _Tip(TipDiagramKind.exportFormat, l10n.tipsWebmCommonLayerTitle, l10n.tipsWebmCommonLayerDesc),
            _Tip(TipDiagramKind.gestureShortcut, l10n.tipsLeftHandedWorkspaceTitle, l10n.tipsLeftHandedWorkspaceDesc),
            _Tip(TipDiagramKind.effectFilter, l10n.tipsBlendModeUsageTitle, l10n.tipsBlendModeUsageDesc),
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
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsTransferDeviceTitle, l10n.tipsTransferDeviceDesc),
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsTransferCustomizationTitle, l10n.tipsTransferCustomizationDesc),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: SizedBox(width: 40, height: 40, child: TipDiagram(tip.diagram)),
        title: Text(tip.title, style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => showDialog(context: context, builder: (_) => _TipDetailDialog(tip: tip)),
      ),
    );
  }
}

/// Tips詳細のポップアップ。1ページ目は図解＋タイトル、2ページ目以降は
/// 説明文を読みやすい分量ごとに分割したページで、横スライドで読み進める。
/// 説明の分量に応じてページ数は可変（固定2ページに限らない）。右上の
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

  /// 説明文を約140字ごとの読みやすい分量に分割する。改行（段落）の区切りを
  /// 優先して尊重し、1段落だけで上限を超える場合はそのまま1ページにする。
  static List<String> _splitIntoPages(String text) {
    const maxCharsPerPage = 140;
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return [text];
    final pages = <String>[];
    var current = '';
    for (final p in paragraphs) {
      final candidate = current.isEmpty ? p : '$current\n$p';
      if (candidate.length > maxCharsPerPage && current.isNotEmpty) {
        pages.add(current);
        current = p;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) pages.add(current);
    return pages.isEmpty ? [text] : pages;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPages = 1 + _textPages.length;
    return Dialog(
      child: SizedBox(
        width: 360,
        height: 420,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
                        child: Column(
                          children: [
                            Expanded(child: Center(child: TipDiagram(widget.tip.diagram))),
                            const SizedBox(height: 12),
                            Text(widget.tip.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                      ),
                      for (final page in _textPages)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.tip.title,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.primary)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(page, style: const TextStyle(fontSize: 13, height: 1.5)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // ページ位置インジケーター（何ページ中何ページ目か）。ページ数が
                // 多い説明でもドットが横に溢れないよう、6ページを超えたら
                // 「n / N」のテキスト表示に切り替える。
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: totalPages <= 6
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(totalPages, (i) {
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
                        )
                      : Text('${_page + 1} / $totalPages',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            // 右上の閉じるボタン
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
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
