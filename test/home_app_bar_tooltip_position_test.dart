import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/home_keyboard_harness.dart';

/// ホームの上部バーのボタン（戻る・表示サイズ・検索・メニュー、検索中の
/// 名前／タグの切り替え・検索を閉じる）の吹き出しは、すぐ下のタブの列に
/// 重ならない（タブの列の下に出す）。スマホ（長押し）・PC（マウスを
/// 重ねる）×7言語。
///
/// 以前は吹き出しの既定の位置（ボタンの真ん中から24px下）で、検索を閉じる
/// ボタンの「閉じる／Fermer」がゴミ箱のタブのアイコンに重なって出た
/// （DISC205）。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  for (final (label, size, pc) in const [
    ('phone 360', Size(360, 740), false),
    ('PC 1280', Size(1280, 800), true),
  ]) {
    for (final language in languages) {
      testWidgets('$language $label: top bar tooltips stay below the tabs', (
        tester,
      ) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          works: 2,
          prefs: {'force_pc_mode': pc ? 1 : 0},
        );
        final l10n = home.l10n;
        final tabs = tester.getRect(find.byType(TabBar));
        final problems = <String>[];
        TestGesture? mouse;
        if (pc) {
          mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
        }

        /// [button]の吹き出し（[message]）を出し、描かれた範囲がタブの列に
        /// 重ならないかを見る。
        Future<void> check(
          Finder button,
          String message, {
          String? shotName,
        }) async {
          expect(button, findsOneWidget, reason: message);
          if (pc) {
            await mouse!.moveTo(tester.getCenter(button));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1200));
          } else {
            await tester.longPress(button);
            await tester.pump(const Duration(milliseconds: 300));
          }
          final shown = find.descendant(
            of: find.byType(Overlay),
            matching: find.text(message),
          );
          if (shown.evaluate().isEmpty) {
            problems.add('no tooltip "$message"');
          } else {
            // 吹き出しの面（文字の上下の余白を含む）。
            final rect = tester.getRect(shown.last).inflate(4);
            if (rect.overlaps(tabs)) {
              problems.add('"$message" $rect covers the tabs $tabs');
            }
            if (!(Offset.zero & size).contains(rect.center)) {
              problems.add('"$message" $rect is off screen');
            }
          }
          if (shotName != null) {
            // 確かめに見る画面（build/home-top-bar-tooltips/）。
            final shot = await home.shot();
            final image = img.Image.fromBytes(
              width: shot.width,
              height: shot.height,
              bytes: shot.rgba.buffer,
              numChannels: 4,
            );
            Directory(
              'build/home-top-bar-tooltips',
            ).createSync(recursive: true);
            File(
              'build/home-top-bar-tooltips/$shotName.png',
            ).writeAsBytesSync(img.encodePng(image));
          }
          if (pc) {
            await mouse!.moveTo(Offset(size.width / 2, size.height - 4));
          }
          Tooltip.dismissAllToolTips();
          await tester.pump(const Duration(seconds: 2));
        }

        // 検索していないとき（プロジェクトのタブ）。起動画面へ戻る矢印は
        // 上のバーの左上。
        await check(
          find.byKey(const Key('homeBackToSplashButton')),
          l10n.homeBackToSplashTooltip,
        );
        await check(
          find.byKey(const Key('homeCollectionViewModeMenu')),
          l10n.homeViewModeTooltip,
        );
        await check(
          find.byKey(const Key('homeSearchButton')),
          l10n.commonSearch,
        );
        final menuTip = MaterialLocalizations.of(
          tester.element(find.byKey(const Key('homeMenuButton'))),
        ).openAppDrawerTooltip;
        await check(find.byKey(const Key('homeMenuButton')), menuTip);

        // 検索中（プロジェクトのタブ：名前／タグの切り替えがある）。
        await tester.tap(find.byKey(const Key('homeSearchButton')));
        await home.settle();
        await check(
          find.byKey(const Key('homeSearchTagToggle')),
          l10n.projectDetailTagsQuickAction,
        );
        await check(
          find.byKey(const Key('homeSearchCloseButton')),
          l10n.commonClose,
        );
        await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
        await home.settle();

        // ゴミ箱のタブで検索中（報告の場面：閉じるボタンがゴミ箱のタブの上）。
        await tester.tap(find.byKey(const ValueKey('home_tab_3')));
        await home.settle();
        await tester.tap(find.byKey(const Key('homeSearchButton')));
        await home.settle();
        await check(
          find.byKey(const Key('homeSearchCloseButton')),
          l10n.commonClose,
          shotName: '${language}_${pc ? 'pc' : 'sp'}_trash_close',
        );
        await check(find.byKey(const Key('homeMenuButton')), menuTip);

        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
