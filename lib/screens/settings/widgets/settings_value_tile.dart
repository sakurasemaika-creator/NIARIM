import 'package:flutter/material.dart';

import '../../../config/accent_text_theme.dart';
import '../../../widgets/action_beside_or_below.dart';
import '../../../widgets/keep_together_text.dart';

/// A tappable setting with a current value. Place the value below the label
/// when the translation or system text size leaves too little room beside it.
class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileTheme = ListTileTheme.of(context);
    final titleStyle =
        tileTheme.titleTextStyle ??
        theme.listTileTheme.titleTextStyle ??
        theme.textTheme.titleMedium;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );

    final label = messageText(title, style: titleStyle);
    final hint = subtitle;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                heightFactor: 1,
                child: ActionBesideOrBelow(
                  gap: 12,
                  spacing: 4,
                  minTextFraction: 0.62,
                  text: hint != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            label,
                            messageText(hint, style: detailStyle),
                          ],
                        )
                      : label,
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: messageText(
                          value,
                          textAlign: TextAlign.end,
                          style: detailStyle?.copyWith(
                            color: AccentTextTheme.of(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
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
