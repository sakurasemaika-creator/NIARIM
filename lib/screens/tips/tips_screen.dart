import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'tip_diagrams.dart';

/// ヘルプ（機能の説明）とは別に、「こうすると便利」という活用方法を
/// 紹介するTipsページ。ホーム画面のハンバーガーメニューから開く。
/// 各項目は「図解＋要点」「タイトル＋詳しい説明」の2ページを横スライドで
/// 見られる構成にし、1画面あたりの図・文章を大きく表示できるようにしている。
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  List<_TipCategory> _buildCategories(AppLocalizations l10n) => [
        _TipCategory(
          title: l10n.tipsCategoryVideo,
          icon: Icons.movie_creation_outlined,
          tips: [
            _Tip(TipDiagramKind.clipDuplicate, l10n.tipsClipDuplicateTitle, l10n.tipsClipDuplicateDesc),
            _Tip(TipDiagramKind.textCaption, l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEfficiency,
          icon: Icons.speed_outlined,
          tips: [
            _Tip(TipDiagramKind.autofillPreset, l10n.tipsAutofillPresetTitle, l10n.tipsAutofillPresetDesc),
            _Tip(TipDiagramKind.brushFavorite, l10n.tipsBrushFavoriteTitle, l10n.tipsBrushFavoriteDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryDrawing,
          icon: Icons.brush_outlined,
          tips: [
            _Tip(TipDiagramKind.onionSkin, l10n.tipsOnionSkinTitle, l10n.tipsOnionSkinDesc),
            _Tip(TipDiagramKind.pressureCurve, l10n.tipsPressureCurveTitle, l10n.tipsPressureCurveDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEffects,
          icon: Icons.auto_awesome_outlined,
          tips: [
            _Tip(TipDiagramKind.effectFilter, l10n.tipsEffectFilterTitle, l10n.tipsEffectFilterDesc),
            _Tip(TipDiagramKind.cameraKeyframe, l10n.tipsCameraKeyframeTitle, l10n.tipsCameraKeyframeDesc),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final categories = _buildCategories(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipsScreenTitle)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
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
