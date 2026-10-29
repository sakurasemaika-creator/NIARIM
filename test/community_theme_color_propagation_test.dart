import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_header_quality_test.dart' as quality;

void main() {
  testWidgets(
    'configured colors reach cards and preview without neutral replacement',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      final community = CommunityService();
      final preview = CommunityPreviewService();
      addTearDown(themes.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final work = community.discoverableWorks.first;
      for (final preset in [
        AppThemePreset.defaultLight.copyWith(
          id: ThemeService.customCurrentId,
          textColor: const Color(0xFF16593A),
          menuTextColor: const Color(0xFF17325A),
          buttonTextColor: const Color(0xFFFFE3FC),
          selectionTextColor: const Color(0xFFCAF3ED),
          menuBgColor: const Color(0xFFFFE5B7),
          panelBgColor: const Color(0xFFEAF1D5),
          accentColor: const Color(0xFF9C4AB5),
          selectionColor: const Color(0xFFD65F31),
        ),
        AppThemePreset.defaultDark.copyWith(
          id: ThemeService.customCurrentId,
          textColor: const Color(0xFFF1D596),
          menuTextColor: const Color(0xFFD7E8FE),
          buttonTextColor: const Color(0xFF17325A),
          selectionTextColor: const Color(0xFF271938),
          menuBgColor: const Color(0xFF23354A),
          panelBgColor: const Color(0xFF1C2833),
          accentColor: const Color(0xFF78AFC5),
          selectionColor: const Color(0xFFC681A6),
        ),
      ]) {
        themes.previewCurrent(preset);
        preview.show(work);
        await tester.pumpWidget(
          quality.host(
            themes,
            community,
            preview,
            locale: const Locale('en'),
            scale: 1,
          ),
        );
        await tester.pumpAndSettle();
        final root = find.byType(CommunityFloatingPreview);
        final bar = find.descendant(
          of: root,
          matching: find.byKey(const Key('communityPreviewControls')),
        );
        expect(tester.widget<Container>(bar).color, preset.menuBgColor);
        for (final button in tester.widgetList<IconButton>(
          find.descendant(of: bar, matching: find.byType(IconButton)),
        )) {
          expect((button.icon as Icon).color, preset.menuTextColor);
        }
        final details = tester.renderObject<RenderParagraph>(
          find.descendant(of: bar, matching: find.text('Details')),
        );
        expect(details.text.style!.color, preset.menuTextColor);
        final card = find.byType(CommunityWorkCard).first;
        expect(
          tester
              .widget<Card>(
                find.descendant(of: card, matching: find.byType(Card)),
              )
              .color,
          preset.menuBgColor,
        );
        final bookmark = tester.widget<IconButton>(
          find.descendant(of: card, matching: find.byType(IconButton)).first,
        );
        expect((bookmark.icon as Icon).color, preset.textColor);
        // The floating preview can cover the plaza's expanded search header.
        // Move it through its drag gesture before operating the underlying menu.
        final drag = find.descendant(
          of: root,
          matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onPanUpdate != null,
          ),
        );
        await tester.drag(drag, const Offset(600, 250));
        await tester.pumpAndSettle();
        final videoFilter = find.byKey(const Key('communitySortButton'));
        expect(videoFilter.hitTestable(), findsOneWidget);
        await tester.tap(videoFilter);
        await tester.pumpAndSettle();
        final item = find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<String> && w.value == 'type:0',
        );
        final menu = find
            .ancestor(of: item, matching: find.byType(Material))
            .first;
        expect(
          tester.widget<Material>(menu).color,
          preset.menuBgColor,
          reason: 'A menu must use the configured menu background',
        );
        await tester.tap(item);
        await tester.pumpAndSettle();
        final wasPlaying = find
            .descendant(of: bar, matching: find.byIcon(Icons.pause))
            .evaluate()
            .isNotEmpty;
        await tester.tap(
          find.ancestor(
            of: find.descendant(
              of: bar,
              matching: find.byIcon(
                wasPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
            matching: find.byType(IconButton),
          ),
        );
        await tester.pump();
        expect(
          find.descendant(
            of: bar,
            matching: find.byIcon(wasPlaying ? Icons.play_arrow : Icons.pause),
          ),
          findsOneWidget,
        );
        expect(preview.work?.id, work.id);
        expect(themes.current.toJson(), preset.toJson());
      }
      await tester.tap(
        find.ancestor(
          of: find.descendant(
            of: find.byType(CommunityFloatingPreview),
            matching: find.byIcon(Icons.close),
          ),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(preview.work, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
