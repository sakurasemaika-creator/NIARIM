import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';

void main() {
  test(
    'normal accent action text stays the exact accent without heavy outline',
    () {
      const pink = Color(0xFFFF5C7A);
      const panel = Color(0xFFFAF7F5);
      final scheme = ColorScheme.fromSeed(seedColor: pink).copyWith(
        primary: pink,
        surface: panel,
        onSurface: const Color(0xFF2B2730),
      );
      // The preset used in the original screenshot must render as bright
      // #FF5C7A, matching the slider/selected chips, rather than looking
      // burgundy because an opaque 1px outline covers thin font strokes.
      expect(CanvasIconButton.actionShadows(pink, panel, scheme), isNull);
      expect(scheme.primary, pink);
    },
  );

  test('similar accent and panel colors still get a theme-derived outline', () {
    const yellow = Color(0xFFFFE47A);
    const panel = Color(0xFFFFF4B5);
    final scheme = ColorScheme.fromSeed(seedColor: yellow).copyWith(
      primary: yellow,
      surface: panel,
      onSurface: const Color(0xFF343025),
    );
    final shadows = CanvasIconButton.actionShadows(yellow, panel, scheme);
    expect(shadows, hasLength(8));
    expect(
      shadows!.every(
        (shadow) =>
            shadow.color == scheme.surface || shadow.color == scheme.onSurface,
      ),
      isTrue,
    );
    // Free-floating tools must remain outlined whatever the drawing:
    // they don't have the safety of a known flat background behind them.
    expect(CanvasIconButton.foregroundShadows(yellow, scheme), hasLength(8));
  });
}
