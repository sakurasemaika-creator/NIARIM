import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';

/// 作品を一覧表示する画面（新着・ランキング・投稿者別作品一覧等）で
/// 共通して使う「動画の種類」絞り込み。CommunityWork.isShortを直接
/// 見せる代わりに、ユーザーが選ぶ選択肢としては「総合」「縦画面のみ」
/// 「横画面のみ」の3択に丸める。
enum VideoTypeFilter { all, shortOnly, longOnly }

extension VideoTypeFilterX on VideoTypeFilter {
  List<CommunityWork> apply(List<CommunityWork> works) {
    return switch (this) {
      VideoTypeFilter.all => works,
      VideoTypeFilter.shortOnly => works.where((w) => w.isShort).toList(),
      VideoTypeFilter.longOnly => works.where((w) => !w.isShort).toList(),
    };
  }

  String label(AppLocalizations l10n) => switch (this) {
        VideoTypeFilter.all => l10n.communityVideoTypeFilterAll,
        VideoTypeFilter.shortOnly => l10n.communityVideoTypeFilterShortOnly,
        VideoTypeFilter.longOnly => l10n.communityVideoTypeFilterLongOnly,
      };
}

/// 動画の種類（総合／縦画面のみ／横画面のみ）を切り替えるプルダウン。
/// 選択中の項目にはチェックマークを付ける（`CheckedPopupMenuItem`）。
class VideoTypeFilterButton extends StatelessWidget {
  final VideoTypeFilter value;
  final ValueChanged<VideoTypeFilter> onChanged;

  const VideoTypeFilterButton({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<VideoTypeFilter>(
      tooltip: l10n.communityVideoTypeFilterTooltip,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final type in VideoTypeFilter.values)
          CheckedPopupMenuItem<VideoTypeFilter>(
            value: type,
            checked: value == type,
            child: Text(type.label(l10n)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_outlined, size: 18),
            const SizedBox(width: 4),
            Text(value.label(l10n), style: const TextStyle(fontSize: 12)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
