import 'package:flutter/material.dart';

/// Resolve chip states after AnimatedTheme has interpolated the formal roles.
class AppChipTheme extends StatelessWidget {
  const AppChipTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuForeground =
        theme.popupMenuTheme.textStyle?.color ?? theme.colorScheme.onSurface;
    final selectedForeground = theme.colorScheme.onSecondary;
    final labelStyle = theme.chipTheme.labelStyle ?? theme.textTheme.labelLarge;
    return Theme(
      // A Theme override lets nested preview Themes retain their own colors.
      data: theme.copyWith(
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: labelStyle?.copyWith(
            color: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return theme.colorScheme.onSurface;
              }
              return states.contains(WidgetState.selected)
                  ? selectedForeground
                  : menuForeground;
            }),
          ),
          checkmarkColor: selectedForeground,
        ),
      ),
      child: child,
    );
  }
}
