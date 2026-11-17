import 'package:flutter/material.dart';

import '../config/accent_text_theme.dart';
import '../config/font_fallback.dart';

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

/// ポップアップメニューの中の小見出し（選べない）。メニューの文字色で、
/// 見出しの書体（くらむぼん）。
class MenuSectionHeading<T> extends PopupMenuEntry<T> {
  const MenuSectionHeading(this.label, {super.key});

  final String label;

  @override
  double get height => 32;

  @override
  bool represents(T? value) => false;

  @override
  State<MenuSectionHeading<T>> createState() => _MenuSectionHeadingState<T>();
}

class _MenuSectionHeadingState<T> extends State<MenuSectionHeading<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color:
                theme.popupMenuTheme.textStyle?.color ??
                theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
