import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/widgets/ad_banner_mock_widget.dart';
import 'package:niarim/widgets/progress_dialog.dart';
import 'package:niarim/services/ad_placement_policy.dart';
import 'package:niarim/services/ad_modal_visibility_observer.dart';
import 'package:provider/provider.dart';

/// A free user who can see the mock slot when it fits.
class _FreePremiumService extends PremiumService {
  @override
  bool get isPremium => false;
}

/// A paying member.
class _MemberPremiumService extends PremiumService {
  @override
  bool get isPremium => true;
}

Widget _localizedApp(Widget home, {bool premium = false}) {
  return ChangeNotifierProvider<PremiumService>(
    create: (_) => premium ? _MemberPremiumService() : _FreePremiumService(),
    child: _app(home),
  );
}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('ja'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

void main() {
  testWidgets('modal visibility observer tracks dialogs and their removal', (
    tester,
  ) async {
    final observer = AdModalVisibilityObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('confirm')),
              ),
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(observer.isModalVisible.value, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(observer.isModalVisible.value, isFalse);
  });

  test('route policy excludes navigation, account and form screens', () {
    for (final path in [
      '/',
      '/new-project',
      '/export/123',
      '/settings',
      '/settings/error-log',
      '/premium',
      '/rewards',
      '/earn-coins',
      '/membership',
      '/creator-missions',
      '/storage',
      '/autofill-presets',
      '/unknown',
      '/community/work/123',
    ]) {
      expect(isBannerEligibleRoute(path), isFalse, reason: path);
    }
    for (final path in [
      '/project/123',
      '/canvas/123',
      '/timeline/123',
      '/materials/123',
      '/save-tree/123',
      '/tips',
      '/help',
      '/settings/license',
      '/settings/privacy-policy',
    ]) {
      expect(isBannerEligibleRoute(path), isTrue, reason: path);
    }
    for (final path in ['/community', '/community/work/123']) {
      expect(
        isBannerEligibleRoute(path, hasLocalContent: false),
        isFalse,
        reason: path,
      );
      expect(
        isBannerEligibleRoute(path, hasLocalContent: true),
        isTrue,
        reason: path,
      );
    }
    for (final path in ['/home', '/shared', '/trash']) {
      expect(
        isBannerEligibleRoute(path, hasLocalContent: false),
        isFalse,
        reason: path,
      );
      expect(
        isBannerEligibleRoute(path, hasLocalContent: true),
        isTrue,
        reason: path,
      );
    }
  });

  testWidgets(
    'processing popup keeps the top banner visible while both ad areas coexist',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider<PremiumService>(
          create: (_) => _FreePremiumService(),
          child: MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Match NIARIM's real MaterialApp.router.builder arrangement:
            // the persistent banner is OUTSIDE the Navigator's modal barrier.
            builder: (context, child) => AdPersistentRootFrame(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ProgressDialog(
                      title: '動画書き出し中',
                      progress: 0.5,
                      onCancel: _noop,
                    ),
                  ),
                  child: const Text('start export'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('start export'));
      await tester.pump();

      final top = find.byKey(const Key('fixed-banner-ad-mock'));
      final middle = find.byKey(const Key('medium-rectangle-ad-mock'));
      expect(top, findsOneWidget);
      expect(middle, findsOneWidget);
      expect(find.byType(ProgressDialog), findsOneWidget);
      // The modal route must occupy the content area, not darken/cover the
      // persistent ad in the separate upper region.
      final bannerRect = tester.getRect(top);
      final popupRect = tester.getRect(find.byType(AlertDialog));
      expect(popupRect.top, greaterThanOrEqualTo(bannerRect.bottom));
      await tester.ensureVisible(middle);
      await tester.pump();
      final midRect = tester.getRect(middle);
      expect(midRect.top, greaterThan(bannerRect.bottom));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ineligible routes keep the banner hidden without affecting content',
    (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const AdPersistentRootFrame(
            allowBanner: false,
            child: Scaffold(body: Text('legal / privacy')),
          ),
        ),
      );
      expect(
        find.byKey(const Key('persistent-horizontal-ad-mock')),
        findsNothing,
      );
      expect(find.text('legal / privacy'), findsOneWidget);
    },
  );

  testWidgets('横長広告はSafeArea内の画面最上部に固定され操作領域と離れる', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _localizedApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: AdMockPageFrame(
            child: Scaffold(
              appBar: AppBar(key: const Key('page-app-bar')),
              body: const Center(child: Text('page')),
            ),
          ),
        ),
      ),
    );

    final bannerSlotRect = tester.getRect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
    );
    final bannerRect = tester.getRect(
      find.byKey(const Key('fixed-banner-ad-mock')),
    );
    final appBarRect = tester.getRect(find.byKey(const Key('page-app-bar')));

    expect(bannerRect.top, greaterThanOrEqualTo(24 + 8));
    expect(bannerRect.width, 320);
    expect(bannerRect.height, 50);
    expect(appBarRect.top - bannerSlotRect.bottom, greaterThanOrEqualTo(16));
    expect(bannerRect.bottom, lessThan(appBarRect.top));
  });

  testWidgets(
    'the fixed banner only appears when it fits without losing page state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final banner = find.byKey(const Key('fixed-banner-ad-mock'));
      final input = find.byType(TextField);
      await tester.pumpWidget(
        _localizedApp(
          const AdMockPageFrame(
            child: Scaffold(
              body: Align(alignment: Alignment.topCenter, child: TextField()),
            ),
          ),
        ),
      );
      await tester.enterText(input, 'Retain this input');
      await tester.pump();
      for (final (size, show) in [
        (const Size(320, 394), true),
        (const Size(640, 393), false),
        (const Size(319, 800), false),
        (const Size(240, 220), false),
        (const Size(360, 800), true),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(banner, show ? findsOneWidget : findsNothing, reason: '$size');
        if (show) expect(tester.getSize(banner), const Size(320, 50));
        expect(input.hitTestable(), findsOneWidget);
        expect(find.text('Retain this input'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('SP portrait, landscape and DeX/PC widths reserve a correctly '
      'sized banner with no content overlap or clipping', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final (viewport, expected) in <(Size, Size?)>[
      (const Size(280, 640), null),
      (const Size(319, 700), null),
      (const Size(320, 568), const Size(320, 50)),
      (const Size(360, 780), const Size(320, 50)),
      (const Size(393, 852), const Size(320, 50)),
      (const Size(430, 932), const Size(320, 50)),
      (const Size(640, 360), null),
      (const Size(800, 440), const Size(320, 50)),
      (const Size(480, 720), const Size(320, 50)),
      (const Size(600, 800), const Size(468, 60)),
      (const Size(800, 600), const Size(728, 90)),
      (const Size(1024, 768), const Size(728, 90)),
      (const Size(1280, 720), const Size(728, 90)),
      (const Size(1440, 900), const Size(728, 90)),
      (const Size(1920, 1080), const Size(728, 90)),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(
        _localizedApp(
          const AdPersistentRootFrame(
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Material(
                  child: SizedBox(
                    key: Key('interactive-controls'),
                    height: 56,
                    child: Text('project actions'),
                  ),
                ),
              ),
              body: Center(child: Text('project content')),
            ),
          ),
        ),
      );
      await tester.pump();
      final banner = find.byKey(const Key('fixed-banner-ad-mock'));
      expect(
        banner,
        expected == null ? findsNothing : findsOneWidget,
        reason: 'viewport $viewport',
      );
      if (expected != null) {
        final rect = tester.getRect(banner);
        final controls = tester.getRect(
          find.byKey(const Key('interactive-controls')),
        );
        expect(rect.size, expected, reason: '$viewport');
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
        expect(rect.top, greaterThanOrEqualTo(8));
        expect(rect.bottom, lessThanOrEqualTo(controls.top - 16));
        expect(controls.bottom, lessThan(viewport.height));
      }
      expect(find.text('project content'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $viewport');
    }
  });

  testWidgets('system insets, keyboard and too-short windows disable banner', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final (padding, insets, expected) in <(EdgeInsets, EdgeInsets, bool)>[
      (const EdgeInsets.only(top: 24, bottom: 24), EdgeInsets.zero, true),
      (const EdgeInsets.only(left: 24, right: 24), EdgeInsets.zero, false),
      (EdgeInsets.zero, const EdgeInsets.only(bottom: 270), false),
    ]) {
      await tester.pumpWidget(
        _localizedApp(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 780),
              padding: padding,
              viewInsets: insets,
            ),
            child: const AdPersistentRootFrame(
              child: Scaffold(body: Text('editor controls')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('fixed-banner-ad-mock')),
        expected ? findsOneWidget : findsNothing,
      );
      expect(find.text('editor controls'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('medium rectangle never clips a narrow SP popup or DeX window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final (screen, shouldFit) in <(Size, bool)>[
      (const Size(280, 640), false),
      (const Size(319, 740), false),
      (const Size(320, 800), true),
      (const Size(360, 780), true),
      (const Size(393, 852), true),
      (const Size(800, 600), true),
      (const Size(1024, 768), true),
      (const Size(1440, 900), true),
    ]) {
      tester.view.physicalSize = screen;
      await tester.pumpWidget(
        _localizedApp(
          const Scaffold(
            body: Center(
              child: ProgressDialog(
                title: '処理中',
                progress: 0.5,
                onCancel: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final ad = find.byKey(const Key('medium-rectangle-ad-mock'));
      expect(
        ad,
        shouldFit ? findsOneWidget : findsNothing,
        reason: 'screen $screen',
      );
      if (shouldFit) {
        await tester.ensureVisible(ad);
        await tester.pump();
        final rect = tester.getRect(ad);
        final dialog = tester.getRect(find.byType(AlertDialog));
        expect(rect.size, const Size(300, 250));
        expect(rect.left, greaterThanOrEqualTo(dialog.left));
        expect(rect.right, lessThanOrEqualTo(dialog.right));
      }
      expect(find.text('処理中'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$screen');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('処理中の中型レクタングル広告は300×250で注記より下にある', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: Center(
            child: ProgressDialog(
              title: '処理中',
              progress: 0.5,
              cancelHint: 'キャンセルに関する注記',
              onCancel: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('medium-rectangle-ad-mock')),
    );
    await tester.pump();

    final adRect = tester.getRect(
      find.byKey(const Key('medium-rectangle-ad-mock')),
    );
    final hintRect = tester.getRect(find.text('キャンセルに関する注記'));
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    final cancelRect = tester.getRect(find.text('キャンセル'));

    expect(adRect.top, greaterThan(hintRect.bottom));
    expect(adRect.size, const Size(300, 250));
    expect(adRect.left, greaterThanOrEqualTo(dialogRect.left));
    expect(adRect.right, lessThanOrEqualTo(dialogRect.right));
    expect(cancelRect.top, greaterThan(adRect.bottom));

    // ProgressDialogの定期Timerを確実に破棄する。
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MaterialPageRouteで開く画面にも横長広告フレームが付く', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                adMockMaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('next page')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('next page'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsOneWidget,
    );
  });

  testWidgets('アプリ全体の固定バナーはルート別フレームと重複しない', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _localizedApp(
        const AdPersistentRootFrame(
          child: AdMockPageFrame(
            child: Scaffold(body: Center(child: Text('作品広場'))),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fixed-banner-ad-mock')), findsOneWidget);
    expect(find.text('作品広場'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('プレミアム会員にはルート共通広告を表示しない', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const AdPersistentRootFrame(
          child: AdMockPageFrame(child: Scaffold(body: Text('page'))),
        ),
        premium: true,
      ),
    );
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsNothing,
    );
  });

  testWidgets('プレミアム会員には広告枠を出さない', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const AdMockPageFrame(child: Scaffold(body: Text('page'))),
        premium: true,
      ),
    );
    expect(find.text('page'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsNothing,
    );
  });
}

void _noop() {}
