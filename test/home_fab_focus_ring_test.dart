import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';

import 'helpers/color_channels.dart';
import 'helpers/home_keyboard_harness.dart';

/// ホームの浮かぶボタン（「一番上へ」・＋）にTabで来たとき、はっきり見える
/// フォーカスの印（ボタンの外側の輪）を出す。以前は塗りが少し暗くなる
/// だけ（約1.15:1）で、どこにフォーカスがあるか分からなかった。輪の色は
/// テーマの色（地の上の文字の色）。
void main() {
  // 暗いテーマ（地も塗りも暗い・明るい文字）でも同じく見える。
  final dark = jsonEncode({
    'id': 'default_dark',
    'name': 'Dark',
    'accentColor': 0xFFFF5C7A,
    'textColor': 0xFFF5F1F0,
    'buttonTextColor': 0xFFFFFFFF,
    'menuTextColor': 0xFFF5F1F0,
    'selectionTextColor': 0xFFFFFFFF,
    'panelBgColor': 0xFF17161C,
    'menuBgColor': 0xFF201F27,
    'selectionColor': 0xFFFF5C7A,
    'updateMarkColor': 0xFFFFB020,
    'isFavorite': false,
  });
  for (final (size, theme) in [
    (const Size(360, 740), null),
    (const Size(1280, 800), null),
    (const Size(360, 740), dark),
  ]) {
    testWidgets('the floating buttons show a focus ring '
        '(${size.width}${theme == null ? '' : ', dark'})', (tester) async {
      final home = await HomeKeyboardHarness.open(
        tester,
        size: size,
        works: 4,
        prefs: {'theme_current_json': ?theme},
      );
      final l10n = home.l10n;
      final fabs = {
        l10n.communityScrollToTop: find.byKey(const Key('homeScrollToTopFab')),
        l10n.commonAdd: find.byWidgetPredicate(
          (w) => w is FloatingActionButton && w.heroTag == 'home-add-project',
        ),
      };
      // 輪を描く所：ボタンの円の上端のすぐ外側。
      Offset ringPoint(Finder fab) {
        final rect = tester.getRect(fab);
        return Offset(rect.center.dx, rect.top - 1.5);
      }

      final unfocused = await home.shot();
      final ring = Theme.of(
        tester.element(find.byType(HomeScreen)),
      ).colorScheme.onSurface;
      for (final MapEntry(key: name, value: fab) in fabs.entries) {
        expect(fab, findsOneWidget, reason: name);
        // その浮かぶボタンへTabで進む。
        for (var i = 0; i < 80 && !home.focusIsIn(fab); i++) {
          await home.tab();
        }
        expect(home.focusIsIn(fab), isTrue, reason: '$name is never focused');
        await home.settle();
        final focused = await home.shot();
        final before = unfocused.at(ringPoint(fab));
        final after = focused.at(ringPoint(fab));
        expect(
          contrastRatio(before, after),
          greaterThanOrEqualTo(3),
          reason: '$name: the focus changes $before to $after only',
        );
        expect(
          (after.red8 - ring.red8).abs() <= 8 &&
              (after.green8 - ring.green8).abs() <= 8 &&
              (after.blue8 - ring.blue8).abs() <= 8,
          isTrue,
          reason: '$name: the ring $after is not the theme colour $ring',
        );
        // ほかの浮かぶボタンには輪を出さない。
        for (final other in fabs.values.where((f) => f != fab)) {
          expect(
            focused.at(ringPoint(other)),
            unfocused.at(ringPoint(other)),
            reason: '$name: another button also shows a ring',
          );
        }
      }
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
