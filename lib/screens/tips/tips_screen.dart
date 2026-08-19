import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// ヘルプ（機能の説明）とは別に、「こうすると便利」という活用方法を
/// 紹介するTipsページ。ホーム画面のハンバーガーメニューから開く。
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  List<_TipCategory> _buildCategories(AppLocalizations l10n) => [
        _TipCategory(
          title: l10n.tipsCategoryVideo,
          icon: Icons.movie_creation_outlined,
          tips: [
            _Tip(l10n.tipsClipDuplicateTitle, l10n.tipsClipDuplicateDesc),
            _Tip(l10n.tipsTextCaptionTitle, l10n.tipsTextCaptionDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEfficiency,
          icon: Icons.speed_outlined,
          tips: [
            _Tip(l10n.tipsAutofillPresetTitle, l10n.tipsAutofillPresetDesc),
            _Tip(l10n.tipsBrushFavoriteTitle, l10n.tipsBrushFavoriteDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryDrawing,
          icon: Icons.brush_outlined,
          tips: [
            _Tip(l10n.tipsOnionSkinTitle, l10n.tipsOnionSkinDesc),
            _Tip(l10n.tipsPressureCurveTitle, l10n.tipsPressureCurveDesc),
          ],
        ),
        _TipCategory(
          title: l10n.tipsCategoryEffects,
          icon: Icons.auto_awesome_outlined,
          tips: [
            _Tip(l10n.tipsEffectFilterTitle, l10n.tipsEffectFilterDesc),
            _Tip(l10n.tipsCameraKeyframeTitle, l10n.tipsCameraKeyframeDesc),
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
                  for (final tip in category.tips)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tip.title,
                                style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(tip.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
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
  final String title;
  final String description;
  const _Tip(this.title, this.description);
}
