import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_extension_settings.dart';
import 'package:niarim/screens/help/help_screen.dart';
import 'package:niarim/screens/tips/tips_screen.dart';

void main() {
  const base = Brush(
    id: 'test',
    name: 'Test',
    size: 20,
    opacity: 100,
    spacing: 10,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    fadeMode: FadeMode.off,
    strokeDecay: false,
  );

  Widget host(
    Brush brush,
    ValueChanged<Brush> onChanged, {
    Locale locale = const Locale('ja'),
    VoidCallback? onPickOutlineColor,
    VoidCallback? onEyedropOutlineColor,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Builder(
          builder: (context) => BrushExtensionSettings(
            brush: brush,
            onChanged: onChanged,
            labels: BrushExtensionLabels.fromLocalizations(
              AppLocalizations.of(context)!,
            ),
            onPickOutlineColor: onPickOutlineColor,
            onEyedropOutlineColor: onEyedropOutlineColor,
          ),
        ),
      ),
    ),
  );

  testWidgets('lateral repeat dependants are hidden while disabled', (
    tester,
  ) async {
    await tester.pumpWidget(host(base, (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('横方向反復個数'), findsNothing);
    expect(find.text('横方向間隔'), findsNothing);

    await tester.tap(find.text('横方向反復'));
    await tester.pump();
    expect(find.text('横方向反復個数'), findsOneWidget);
    expect(find.text('横方向間隔'), findsOneWidget);
  });

  testWidgets('fold mode and controls require outline and fold enabled', (
    tester,
  ) async {
    final changes = <Brush>[];
    await tester.pumpWidget(host(base, changes.add));
    await tester.pumpAndSettle();
    expect(find.text('折り返し'), findsNothing);
    expect(find.byKey(const Key('brush-fold-mode')), findsNothing);

    await tester.tap(find.text('縁取り'));
    await tester.pump();
    expect(find.text('折り返し'), findsOneWidget);
    expect(find.byKey(const Key('brush-fold-mode')), findsNothing);

    await tester.tap(find.text('折り返し'));
    await tester.pump();
    expect(changes.last.foldEnabled, isTrue);
    expect(find.text('発生角度'), findsOneWidget);
    expect(find.text('カーブ開始位置'), findsOneWidget);
    expect(find.text('折り返し長さ'), findsOneWidget);
    expect(find.text('カーブ強度'), findsOneWidget);
    expect(find.byKey(const Key('brush-fold-mode')), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(find.byType(Slider), findsNWidgets(5));
    expect(find.text('ウェーブ'), findsNothing);
    expect(find.text('終点からウェーブにする範囲'), findsNothing);
    expect(find.text('ウェーブ発生角度'), findsNothing);
    await tester.tap(find.text('折り返し'));
    await tester.pump();
    expect(changes.last.foldEnabled, isFalse);
    expect(find.byKey(const Key('brush-fold-mode')), findsNothing);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('縁取り'));
    await tester.pump();
    expect(find.text('折り返し'), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  final translatedModes = <Locale, (String, List<String>)>{
    Locale('ja'): ('折りたたみタイプ', ['ウェーブ俯瞰', 'ウェーブ煽り', '右巻き', '左巻き', '三日月カール']),
    Locale('en'): (
      'Fold mode',
      [
        'Wave (top view)',
        'Wave (low angle)',
        'Right curl',
        'Left curl',
        'Crescent curl',
      ],
    ),
    Locale('es'): (
      'Modo de pliegue',
      [
        'Onda (vista superior)',
        'Onda (contrapicado)',
        'Rizo a la derecha',
        'Rizo a la izquierda',
        'Rizo de media luna',
      ],
    ),
    Locale('fr'): (
      'Type de repli',
      [
        'Ondulation en plongée',
        'Ondulation en contre-plongée',
        'Boucle à droite',
        'Boucle à gauche',
        'Boucle en croissant',
      ],
    ),
    Locale('ko'): (
      '접힘 유형',
      ['웨이브 (위에서 보기)', '웨이브 (아래에서 보기)', '오른쪽 컬', '왼쪽 컬', '초승달 컬'],
    ),
    Locale('zh'): ('折返类型', ['波浪俯视', '波浪仰视', '右卷', '左卷', '月牙卷']),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'): (
      '折返類型',
      ['波浪俯視', '波浪仰視', '右捲', '左捲', '月牙捲'],
    ),
  };

  for (final entry in translatedModes.entries) {
    testWidgets('fold dropdown offers five localized modes in ${entry.key}', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          base.copyWith(outlineEnabled: true, foldEnabled: true),
          (_) {},
          locale: entry.key,
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<HairFoldMode>>(
        find.byKey(const Key('brush-fold-mode')),
      );
      expect(dropdown.decoration.labelText, entry.value.$1);
      final button = tester.widget<DropdownButton<HairFoldMode>>(
        find.descendant(
          of: find.byKey(const Key('brush-fold-mode')),
          matching: find.byType(DropdownButton<HairFoldMode>),
        ),
      );
      expect(button.items!.map((item) => item.value).toList(), const [
        HairFoldMode.waveTopView,
        HairFoldMode.waveLowAngle,
        HairFoldMode.curlRight,
        HairFoldMode.curlLeft,
        HairFoldMode.crescent,
      ]);
      expect(
        button.items!.map((item) => (item.child as Text).data).toList(),
        entry.value.$2,
      );
    });
  }

  testWidgets('long fold labels fit a narrow settings panel', (tester) async {
    tester.view.physicalSize = const Size(260, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        base.copyWith(
          outlineEnabled: true,
          foldEnabled: true,
          foldMode: HairFoldMode.waveLowAngle,
        ),
        (_) {},
        locale: const Locale('fr'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final modeField = find.byKey(const Key('brush-fold-mode'));
    await tester.ensureVisible(modeField);
    await tester.tap(modeField);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Boucle à gauche').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fold help opens the localized topic from brush settings', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BrushExtensionSettings(
              brush: base.copyWith(outlineEnabled: true),
              onChanged: (_) {},
              labels: BrushExtensionLabels.fromLocalizations(
                AppLocalizations.of(context)!,
              ),
              onPickOutlineColor: null,
              onEyedropOutlineColor: null,
            ),
          ),
        ),
        GoRoute(
          path: '/help',
          builder: (context, state) =>
              HelpScreen(initialTopic: state.uri.queryParameters['topic']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('brush-fold-help')));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(HelpScreen)))!;
    expect(find.text(l10n.helpBrushFoldTitle), findsOneWidget);
    expect(find.text(l10n.helpBrushFoldDesc), findsOneWidget);
    expect(
      tester
          .widget<ExpansionTile>(find.byType(ExpansionTile))
          .initiallyExpanded,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in translatedModes.entries) {
    testWidgets('fold tip includes all five modes in ${entry.key}', (
      tester,
    ) async {
      await tester.pumpWidget(host(base, (_) {}, locale: entry.key));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BrushExtensionSettings)),
      )!;

      expect(
        allTipEntries(l10n),
        contains((l10n.tipsBrushFoldTitle, l10n.tipsBrushFoldDesc)),
      );
      for (final mode in entry.value.$2) {
        expect(l10n.helpBrushFoldDesc, contains(mode));
        expect(l10n.tipsBrushFoldDesc, contains(mode));
      }
    });
  }

  testWidgets('selecting a fold mode is propagated and survives fold toggles', (
    tester,
  ) async {
    final changes = <Brush>[];
    await tester.pumpWidget(
      host(base.copyWith(outlineEnabled: true, foldEnabled: true), changes.add),
    );
    await tester.pumpAndSettle();

    final modeField = find.byKey(const Key('brush-fold-mode'));
    await tester.ensureVisible(modeField);
    await tester.tap(modeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('左巻き').last);
    await tester.pumpAndSettle();
    expect(changes.last.foldMode, HairFoldMode.curlLeft);
    expect(changes.last.foldEnabled, isTrue);

    await tester.ensureVisible(find.text('折り返し'));
    await tester.tap(find.text('折り返し'));
    await tester.pump();
    expect(changes.last.foldEnabled, isFalse);
    expect(changes.last.foldMode, HairFoldMode.curlLeft);

    await tester.tap(find.text('折り返し'));
    await tester.pump();
    expect(changes.last.foldEnabled, isTrue);
    expect(changes.last.foldMode, HairFoldMode.curlLeft);
    final dropdown = tester.widget<DropdownButton<HairFoldMode>>(
      find.descendant(
        of: modeField,
        matching: find.byType(DropdownButton<HairFoldMode>),
      ),
    );
    expect(dropdown.value, HairFoldMode.curlLeft);
  });

  testWidgets('curve strength uses ten discrete levels with neutral five', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(base.copyWith(outlineEnabled: true, foldEnabled: true), (_) {}),
    );
    await tester.pumpAndSettle();
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    final strength = sliders.singleWhere(
      (slider) => slider.min == 1 && slider.max == 10,
    );
    expect(strength.value, 5);
    expect(strength.divisions, 9);
  });

  testWidgets('outline exposes picker and eyedropper actions', (tester) async {
    var picked = 0;
    var eyedropped = 0;
    await tester.pumpWidget(
      host(
        base.copyWith(outlineEnabled: true),
        (_) {},
        onPickOutlineColor: () => picked++,
        onEyedropOutlineColor: () => eyedropped++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('brush-outline-color-picker')));
    await tester.tap(find.byKey(const Key('brush-outline-eyedropper')));
    expect(picked, 1);
    expect(eyedropped, 1);
  });
}
