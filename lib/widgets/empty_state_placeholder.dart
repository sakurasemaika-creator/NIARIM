import 'package:flutter/material.dart';
import '../config/font_fallback.dart';

/// 一覧画面が空のときに表示する共通プレースホルダー。円形の色付き
/// アイコンバッジ・くらむぼんの太字タイトル・淡色の補足文という構成を、
/// プロジェクト一覧・共有一覧・ゴミ箱一覧・作品一覧・素材一覧など
/// すべての一覧画面で統一するために切り出している。
class EmptyStatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;

  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
