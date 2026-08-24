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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.tipsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon', color: scheme.primary)),
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
            _Tip(TipDiagramSpec(TipDiagramKind.clipDuplicate), l10n.tipsClipDuplicateTitle, l10n.tipsClipDuplicateDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.textCaption), l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.content_copy, iconB: Icons.graphic_eq),
                l10n.tipsAudioRepeatTitle, l10n.tipsAudioRepeatDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.text_rotate_vertical, iconB: Icons.text_fields),
                l10n.tipsVerticalRubyTitle, l10n.tipsVerticalRubyDesc),
            _Tip(
                TipDiagramSpec(TipDiagramKind.pairCombo,
                    iconA: Icons.branding_watermark, iconB: Icons.movie_filter_outlined, separator: '≠'),
                l10n.tipsEndCardWatermarkTitle,
                l10n.tipsEndCardWatermarkDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.videocam_outlined, iconB: Icons.brush),
                l10n.tipsVerticalPixelFontTitle, l10n.tipsVerticalPixelFontDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.approval, iconB: Icons.layers),
                l10n.tipsStampBlendModeTitle, l10n.tipsStampBlendModeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.flowArrow, iconA: Icons.content_cut, iconB: Icons.repeat),
                l10n.tipsVideoTrimReuseTitle, l10n.tipsVideoTrimReuseDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.timelineMarker), l10n.tipsTimelineMarkerTitle, l10n.tipsTimelineMarkerDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEfficiency,
          icon: Icons.speed_outlined,
          tips: [
            _Tip(TipDiagramSpec(TipDiagramKind.autofillPreset), l10n.tipsAutofillPresetTitle, l10n.tipsAutofillPresetDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.brushFavorite), l10n.tipsBrushFavoriteTitle, l10n.tipsBrushFavoriteDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.tune, iconB: Icons.history),
                l10n.tipsBrushTrySaveTreeTitle, l10n.tipsBrushTrySaveTreeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.gestureShortcut, iconA: Icons.colorize),
                l10n.tipsEyedropperGestureTitle, l10n.tipsEyedropperGestureDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.selectionTool), l10n.tipsMagicWandLassoTitle, l10n.tipsMagicWandLassoDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.layerFolder), l10n.tipsCommonLayerFolderTitle, l10n.tipsCommonLayerFolderDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.restart_alt, iconB: Icons.edit),
                l10n.tipsQuickToolPenSubTitle, l10n.tipsQuickToolPenSubDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.restart_alt, iconB: Icons.tune),
                l10n.tipsQuickToolVariantTitle, l10n.tipsQuickToolVariantDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.edit_outlined, iconB: Icons.grain),
                l10n.tipsAutofillToneReuseTitle, l10n.tipsAutofillToneReuseDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.saveSlot), l10n.tipsSaveSlotAutoSaveTitle, l10n.tipsSaveSlotAutoSaveDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.gestureShortcut, iconA: Icons.swipe_up_alt),
                l10n.tipsQuickToolSwipeTitle, l10n.tipsQuickToolSwipeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.toolbarCustomize), l10n.tipsToolbarCustomizeTitle, l10n.tipsToolbarCustomizeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pcDexLayout), l10n.tipsPcDexLayoutTitle, l10n.tipsPcDexLayoutDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.groups_outlined, iconB: Icons.person_outline),
                l10n.tipsCommonLayerLipSyncTitle, l10n.tipsCommonLayerLipSyncDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.groups_outlined, iconB: Icons.timeline),
                l10n.tipsCommonLayerKeyframeTitle, l10n.tipsCommonLayerKeyframeDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryDrawing,
          icon: Icons.brush_outlined,
          tips: [
            _Tip(TipDiagramSpec(TipDiagramKind.transparentColor), l10n.tipsTransparentColorTitle, l10n.tipsTransparentColorDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pressureCurve), l10n.tipsPressureCurveTitle, l10n.tipsPressureCurveDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.straighten, iconB: Icons.layers),
                l10n.tipsRulerOnionTitle, l10n.tipsRulerOnionDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.gradient, iconB: Icons.colorize),
                l10n.tipsGradientTraceTitle, l10n.tipsGradientTraceDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.brush, iconB: Icons.opacity),
                l10n.tipsStrokeDecayFadeTitle, l10n.tipsStrokeDecayFadeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.palette, iconB: Icons.opacity),
                l10n.tipsColorMixingFadeTitle, l10n.tipsColorMixingFadeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.radialVignette), l10n.tipsRadialVignetteTitle, l10n.tipsRadialVignetteDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.layers, iconB: Icons.gradient),
                l10n.tipsClippingGradientTitle, l10n.tipsClippingGradientDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.crop_free, iconB: Icons.videocam_outlined),
                l10n.tipsDrawingAreaCameraTitle, l10n.tipsDrawingAreaCameraDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.auto_fix_high, iconB: Icons.opacity),
                l10n.tipsAutofillBlendModeTitle, l10n.tipsAutofillBlendModeDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.edit_note, iconB: Icons.brightness_6),
                l10n.tipsRoughLayerRescueTitle, l10n.tipsRoughLayerRescueDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.lineArtExtraction), l10n.tipsLineArtExtractionTitle, l10n.tipsLineArtExtractionDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.lineColorModes), l10n.tipsLineColorUsageTitle, l10n.tipsLineColorUsageDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.blushGradient), l10n.tipsBlushAutofillTitle, l10n.tipsBlushAutofillDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.checkroom_outlined, iconB: Icons.grid_on),
                l10n.tipsStockingDenierTitle, l10n.tipsStockingDenierDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEffects,
          icon: Icons.auto_awesome_outlined,
          tips: [
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.water_drop, iconB: Icons.blur_on),
                l10n.tipsRainNoiseTitle, l10n.tipsRainNoiseDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.timeline, iconB: Icons.groups_outlined),
                l10n.tipsPartKeyframeGroupTitle, l10n.tipsPartKeyframeGroupDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.border_color, iconB: Icons.movie_filter_outlined),
                l10n.tipsOutlineAnimeStyleTitle, l10n.tipsOutlineAnimeStyleDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pressureCurve, iconA: Icons.tune),
                l10n.tipsLevelsToneCurveTitle, l10n.tipsLevelsToneCurveDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.show_chart, iconB: Icons.filter_vintage),
                l10n.tipsToneCurveSepiaTitle, l10n.tipsToneCurveSepiaDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.cameraKeyframe), l10n.tipsCameraLensBlurTitle, l10n.tipsCameraLensBlurDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.layers_outlined, iconB: Icons.groups_outlined),
                l10n.tipsWebmCommonLayerTitle, l10n.tipsWebmCommonLayerDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.mirrorLayout), l10n.tipsLeftHandedWorkspaceTitle, l10n.tipsLeftHandedWorkspaceDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.layers, iconB: Icons.checklist),
                l10n.tipsBlendModeUsageTitle, l10n.tipsBlendModeUsageDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.panorama_fish_eye, iconB: Icons.color_lens),
                l10n.tipsFisheyeChromaticTitle, l10n.tipsFisheyeChromaticDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.highlight_alt, iconB: Icons.remove_red_eye),
                l10n.tipsLensDistortionTitle, l10n.tipsLensDistortionDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryExport,
          icon: Icons.ios_share_outlined,
          tips: [
            _Tip(TipDiagramSpec(TipDiagramKind.exportFormat), l10n.tipsExportFormatTitle, l10n.tipsExportFormatDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.gestureShortcut, iconA: Icons.bolt),
                l10n.tipsGestureShortcutTitle, l10n.tipsGestureShortcutDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.performanceGauge), l10n.tipsLowSpecSettingsTitle, l10n.tipsLowSpecSettingsDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.filter_alt, iconB: Icons.folder),
                l10n.tipsSeriesPresetFolderTitle, l10n.tipsSeriesPresetFolderDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.grid_view, iconB: Icons.blur_linear),
                l10n.tipsMosaicChromaticTitle, l10n.tipsMosaicChromaticDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.grid_on, iconB: Icons.grain),
                l10n.tipsPixelToneRetroTitle, l10n.tipsPixelToneRetroDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.blur_on, iconB: Icons.brightness_low),
                l10n.tipsBlurVignetteBgTitle, l10n.tipsBlurVignetteBgDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.effectFilter), l10n.tipsSepiaVignetteTitle, l10n.tipsSepiaVignetteDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.deviceTransfer), l10n.tipsTransferDeviceTitle, l10n.tipsTransferDeviceDesc),
            _Tip(TipDiagramSpec(TipDiagramKind.pairCombo, iconA: Icons.palette, iconB: Icons.sync_alt),
                l10n.tipsTransferCustomizationTitle, l10n.tipsTransferCustomizationDesc),
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
    // 図解は一覧の時点では表示しない（ポップアップを開いてから表示する）。
    // 40×40の小さな領域に押し込めて表示すると、画面全体を模した図解が
    // つぶれて崩れて見えるうえ、60件超の一覧すべてを常時描画するのは
    // 無駄が大きいため、詳細ポップアップ（_TipDetailDialog）側でのみ描画する。
    // カード自体は影付きで浮かせ、電球アイコンのバッジを添える。
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog(context: context, builder: (_) => _TipDetailDialog(tip: tip)),
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
                      colors: [scheme.tertiary.withValues(alpha: 0.25), scheme.tertiary.withValues(alpha: 0.1)],
                    ),
                  ),
                  child: Icon(Icons.lightbulb_outline, color: scheme.tertiary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tip.title,
                      style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600, fontSize: 13)),
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
  /// そのまま1ページにする。どのページにも図解を併記するため、文章だけの
  /// ページより少し広めの上限にしている。
  static List<String> _splitIntoPages(String text) {
    const maxCharsPerPage = 220;
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return [text];
    final totalLength = paragraphs.fold<int>(0, (sum, p) => sum + p.length) + (paragraphs.length - 1);
    final pageCount = (totalLength / maxCharsPerPage).ceil().clamp(1, paragraphs.length);
    if (pageCount <= 1) return [paragraphs.join('\n')];
    final targetPerPage = totalLength / pageCount;
    final pages = <String>[];
    var current = '';
    for (final p in paragraphs) {
      final candidate = current.isEmpty ? p : '$current\n$p';
      final remainingPages = pageCount - pages.length;
      if (candidate.length > targetPerPage && current.isNotEmpty && remainingPages > 1) {
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
    final totalPages = _textPages.length;
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
                      for (final page in _textPages)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
                          // タイトルは上寄せ・図解は中央寄せ・本文は下寄せに
                          // なるよう、縦方向をExpandedで区切って配分する。
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // タイトル（上寄せ、くらむぼんフォント）。
                              Text(widget.tip.title,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Kuramubon',
                                      color: scheme.primary)),
                              // 図解（中央寄せ。すべてのページで併記する、
                              // 文章だけのページを作らない）。
                              Expanded(
                                flex: 4,
                                child: Center(
                                  child: SizedBox(height: 84, child: TipDiagram(widget.tip.diagram)),
                                ),
                              ),
                              // 本文（下寄せ。ページ内に収まらない分量は
                              // スクロールできる）。
                              Expanded(
                                flex: 5,
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: SingleChildScrollView(
                                    child: Text(page, style: const TextStyle(fontSize: 13, height: 1.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // ページ位置インジケーター（何ページ中何ページ目か）。1ページに
                // 収まる説明ではスワイプ自体が不要なため表示しない。ページ数が
                // 多い説明でもドットが横に溢れないよう、6ページを超えたら
                // 「n / N」のテキスト表示に切り替える。
                if (totalPages > 1)
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
  final TipDiagramSpec diagram;
  final String title;
  final String description;
  const _Tip(this.diagram, this.title, this.description);
}
