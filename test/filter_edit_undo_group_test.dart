import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pick_filter_card.dart';

/// Undo in the filter editor takes back one whole edit at a time: dragging a
/// slider or a curve point is one step, not one step per frame of the drag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => '${Directory.systemTemp.path}/niarim_filter_edit_undo',
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  group('FilterService edit groups', () {
    Future<FilterService> service() async {
      final s = FilterService();
      await s.init();
      s.selectFilter('Filter0001');
      return s;
    }

    test('every change outside a group is its own step', () async {
      final s = await service();
      final start = s.currentFilter!.strength;
      s.updateFilterParams('Filter0001', strength: start + 1);
      s.updateFilterParams('Filter0001', strength: start + 2);
      s.undoFilterEdit();
      expect(s.currentFilter!.strength, start + 1);
      s.undoFilterEdit();
      expect(s.currentFilter!.strength, start);
      expect(s.canUndoFilterEdit, isFalse);
    });

    test(
      'a group of changes is one step, and Redo brings back its end',
      () async {
        final s = await service();
        final start = s.currentFilter!.strength;
        s.beginFilterEditGroup();
        for (var i = 1; i <= 30; i++) {
          s.updateFilterParams('Filter0001', strength: start + i / 3);
        }
        s.endFilterEditGroup();
        final end = s.currentFilter!.strength;

        s.undoFilterEdit();
        expect(s.currentFilter!.strength, start);
        expect(s.canUndoFilterEdit, isFalse);
        s.redoFilterEdit();
        expect(s.currentFilter!.strength, end);
        expect(s.canRedoFilterEdit, isFalse);
      },
    );

    test('two drags are two steps', () async {
      final s = await service();
      final start = s.currentFilter!.strength;
      for (final target in [start + 3, start + 6]) {
        s.beginFilterEditGroup();
        s.updateFilterParams('Filter0001', strength: target - 1);
        s.updateFilterParams('Filter0001', strength: target);
        s.endFilterEditGroup();
      }
      s.undoFilterEdit();
      expect(s.currentFilter!.strength, start + 3);
      s.undoFilterEdit();
      expect(s.currentFilter!.strength, start);
    });

    test('a change to the same value is not a step', () async {
      final s = await service();
      s.updateFilterParams('Filter0001', strength: s.currentFilter!.strength);
      s.beginFilterEditGroup();
      s.endFilterEditGroup();
      expect(s.canUndoFilterEdit, isFalse);
    });
  });

  group('FilterPanel', () {
    Future<FilterService> openPanel(
      WidgetTester tester,
      String filterId,
    ) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final providers = await tester.runAsync(buildAppProviders);
      Widget app(Widget home) => MultiProvider(
        providers: providers!,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      );
      await tester.pumpWidget(app(const SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      final projects = context.read<ProjectService>();
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'filter-edit-undo',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 96,
          exportHeight: 96,
        ),
      ))!;
      final sceneId = projects.scenesOf(project.id).first.id;
      final layerId = projects
          .layersOf(project.id, sceneId, 0)
          .firstWhere((layer) => layer.type == model.LayerType.normal)
          .id;
      await tester.pumpWidget(
        app(
          FilterPanel(
            projectId: project.id,
            sceneId: sceneId,
            layerId: layerId,
            frameIndex: 0,
            onClose: () {},
          ),
        ),
      );
      await pickFilterCard(tester, filterId);
      await tester.pump();
      return tester.element(find.byType(FilterPanel)).read<FilterService>();
    }

    Future<void> drag(
      WidgetTester tester,
      Offset from,
      List<Offset> steps,
    ) async {
      final gesture = await tester.startGesture(from);
      for (final step in steps) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    testWidgets('dragging a slider is one Undo step', (tester) async {
      final service = await openPanel(tester, 'Filter0001');
      final start = service.currentFilter!.strength;
      final slider = find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byType(Slider),
      );
      final rect = tester.getRect(slider.first);
      await drag(tester, Offset(rect.left + 30, rect.center.dy), [
        for (var i = 0; i < 12; i++) const Offset(12, 0),
      ]);
      expect(service.currentFilter!.strength, isNot(start));
      expect(service.canUndoFilterEdit, isTrue);

      await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
      await tester.pump();
      expect(service.currentFilter!.strength, start);
      expect(service.canUndoFilterEdit, isFalse, reason: 'a single step');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dragging a tone-curve point is one Undo step', (tester) async {
      final service = await openPanel(tester, 'Filter0004');
      final before = service.currentFilter!.toJson();
      final editor = find.byKey(const ValueKey('tone-curve-editor-0'));
      await tester.ensureVisible(editor);
      await tester.pump();
      final rect = tester.getRect(editor);
      final controls = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(FilterPanel),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      );
      final scrolledBefore = controls.position.pixels;
      expect(scrolledBefore, greaterThan(0), reason: 'room to scroll back');
      // Grab the top-right end of the curve and pull it straight down, the
      // way the panel's own scrolling would otherwise take the drag.
      await drag(tester, rect.topRight + const Offset(-2, 2), [
        for (var i = 0; i < 10; i++) const Offset(0, 6),
      ]);
      expect(
        controls.position.pixels,
        scrolledBefore,
        reason: 'the controls did not scroll under the drag',
      );
      expect(service.currentFilter!.toneCurvePoints, isNotEmpty);
      expect(service.currentFilter!.toJson(), isNot(before));
      expect(service.canUndoFilterEdit, isTrue);

      await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
      await tester.pump();
      expect(service.currentFilter!.toJson(), before);
      expect(service.canUndoFilterEdit, isFalse, reason: 'a single step');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
