import 'package:flutter/material.dart';
import '../config/accent_text_theme.dart';

/// 今の選択にチェックが付くメニュー項目（読み上げでも選択中と伝える）。
PopupMenuItem<T> checkedMenuItem<T>(
  BuildContext context, {
  required T value,
  required bool checked,
  required String label,
  IconData? icon,
}) {
  final scheme = Theme.of(context).colorScheme;
  return PopupMenuItem<T>(
    value: value,
    child: Semantics(
      selected: checked,
      inMutuallyExclusiveGroup: true,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: checked
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: AccentTextTheme.of(context),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}
