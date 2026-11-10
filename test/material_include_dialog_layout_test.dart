import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';

/// 共有ファイル（.niashare）を作る前の「素材の同梱」ダイアログが、横向きの
/// スマホ・低い画面・大きな文字でもはみ出さず、全部の選択肢と2つのボタンに
/// 届くこと。
void main() {
  testWidgets('the include-materials dialog fits short and landscape screens', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final theme = ThemeService();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final problems = <String>[];
    for (final locale in const ['ja', 'en', 'fr']) {
      for (final (size, bars) in const [
        (Size(800, 360), true),
        (Size(640, 360), false),
        (Size(360, 640), true),
        (Size(390, 844), false),
        (Size(390, 220), false),
        (Size(1440, 900), false),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          final profile =
              '$locale ${size.width.toInt()}x${size.height.toInt()}'
              '${bars ? '+bars' : ''} x$scale';
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view.physicalSize = size;
          tester.view.padding = bars
              ? FakeViewPadding(top: 24, bottom: 48)
              : FakeViewPadding.zero;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.themeData,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const Key('open'),
                      onPressed: () => showMaterialIncludeDialog(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const Key('open')));
          await tester.pumpAndSettle();
          final error = tester.takeException();
          if (error != null) {
            problems.add('$profile: $error'.split('\n').first);
            continue;
          }
          final l10n = AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          )!;
          final dialog = tester.getRect(find.byType(AlertDialog));
          // ボタンは画面の中にあり、押せる（何かに重なっていない）こと。
          for (final label in [l10n.commonCancel, l10n.commonCreate]) {
            final button = find.text(label);
            final rect = tester.getRect(button);
            if (rect.bottom > dialog.bottom + 0.5 ||
                rect.top < dialog.top - 0.5) {
              problems.add('$profile: "$label" outside the dialog');
              continue;
            }
            final hit = tester.hitTestOnBinding(rect.center);
            final owner = tester.renderObject(button);
            if (!hit.path.any((entry) => entry.target == owner)) {
              problems.add('$profile: "$label" is covered');
            }
          }
          // 4つの選択肢は（必要ならダイアログの中をスクロールして）全部届く。
          for (final label in [
            l10n.projectListMaterialImage,
            l10n.projectListMaterialVideo,
            l10n.projectListMaterialAudio,
            l10n.projectListIncludeFontsTitle,
          ]) {
            final option = find.text(label);
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            final rect = tester.getRect(option);
            if (rect.top < dialog.top || rect.bottom > dialog.bottom) {
              problems.add('$profile: "$label" cannot be reached');
              continue;
            }
            final hit = tester.hitTestOnBinding(rect.center);
            final owner = tester.renderObject(option);
            if (!hit.path.any((entry) => entry.target == owner)) {
              problems.add('$profile: "$label" is covered');
            }
          }
          expect(tester.takeException(), isNull, reason: profile);
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
