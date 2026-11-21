// 契約状態の画面の「プレミアム会員について詳しく見る」のボタンの名前が、
// 1字だけの行を作らない（DISC180）。
//
// ボタンは画面の幅いっぱい（320pxの画面で名前の欄は約220px）で、日本語の
// 名前（16字、くらむぼん14px）が1字分だけ入らず、「プレミアム会員について
// 詳しく見」「る」と最後の1字だけが次の行に出ていた。日本語は字と字の間の
// どこでも行を変えるので、Flutterは入るところまで詰めて折る。
//
// 7言語×320/360px×文字1.0/1.3/2.0で、名前のどの行も字（文字・数字。
// 句読点・括弧は数えない）が2つ以上あること、行に入る語（欧文・韓国語）を
// 途中で折らないこと、日本語の最後の語（「詳しく見る」）を行の途中で
// 分けないことを見る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/membership_benefits_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/line_break.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'membership-detail-button';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Example';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends GoogleAuthService {
  final _user = _Account();
  @override
  GoogleSignInAccount? get account => _user;
  @override
  bool get isConfigured => true;
}

/// 字（文字・数字）。句読点・括弧・空白は数えない。
final RegExp _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  test('japaneseLastPhraseParts keeps the last Japanese phrase', () {
    expect(japaneseLastPhraseParts('プレミアム会員について詳しく見る'), ['詳しく見る']);
    expect(japaneseLastPhraseParts('設定を保存する'), ['保存する']);
    // ひらがなの無い文・語の境目の無い文は何もしない。
    expect(japaneseLastPhraseParts('了解高级会员'), isEmpty);
    expect(japaneseLastPhraseParts('Learn about Premium'), isEmpty);
    expect(japaneseLastPhraseParts('保存'), isEmpty);
    // 最後の語が文の前の方にもある文は、どちらをつなぐか分からないので何も
    // しない。
    expect(japaneseLastPhraseParts('保存する前に保存する'), isEmpty);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('membership detail button leaves no one-letter line ($tag)', (
      tester,
    ) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      final premium = PremiumService();
      addTearDown(premium.dispose);
      final root = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(
              value: SettingsService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
            // 接続先の無い作品広場（特典の情報は「確認できませんでした」）。
            ChangeNotifierProvider<CommunityService>.value(
              value: CommunityService(),
            ),
          ],
          child: RepaintBoundary(
            key: root,
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const MembershipBenefitsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = l10n.rewardNavigationMembershipDetail;
      final problems = <String>[];
      final tooWide = <String>[];
      for (final width in [320.0, 360.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 740);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
          final at = '${width.toInt()}px x$scale';
          final button = find.byKey(const Key('membershipLearnPremiumButton'));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final paragraphs = [
            for (final p in textParagraphsIn(button))
              if (p.text
                      .toPlainText(includeSemanticsLabels: false)
                      .replaceAll('\u2060', '')
                      .replaceAll('\u200b', '') ==
                  label)
                p,
          ];
          if (paragraphs.length != 1) {
            problems.add('$at: ${paragraphs.length} labels「$label」');
            continue;
          }
          final paragraph = paragraphs.single;
          final lines = ParagraphLines(paragraph);
          final shown = lines.lines.join(' / ');
          for (final line in lines.lines) {
            if (_letter.allMatches(line).length == 1) {
              problems.add('$at a one-letter line「${line.trim()}」: $shown');
            }
          }
          // 日本語の最後の語（「詳しく見る」）は1つの行に置く（最後の行へ
          // 送る字を語の途中から取らない）。
          if (locale.languageCode == 'ja') {
            const tail = '詳しく見る';
            final text = lines.visible;
            final start = text.lastIndexOf(tail);
            if (start < 0 ||
                lines.breaksWithin(start, start + tail.length).isNotEmpty) {
              problems.add('$at「$tail」is split: $shown');
            }
          }
          final broken = brokenWordUnits(paragraph);
          for (final word in broken.fits) {
            problems.add('$at breaks a word: $word');
          }
          tooWide.addAll(broken.tooWide.map((w) => '$at $w'));
          for (final char in lines.charsOutsideWidth()) {
            problems.add('$at runs past its line: $char');
          }
          if (shots != null && (scale != 1.3)) {
            await tester.runAsync(() async {
              final boundary =
                  root.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$shots/DISC180-${tag}_${width.toInt()}_x'
                '${scale.toString().replaceAll('.', '')}.png',
              ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
              image.dispose();
            });
          }
        }
      }
      expect(tester.takeException(), isNull);
      for (final word in tooWide) {
        debugPrint('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
