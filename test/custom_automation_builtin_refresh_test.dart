import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Official automation presets saved on a device are brought up to date:
/// an unedited copy takes the current recipe (the fixed 「線画色トレス」), one
/// no longer shipped (the aurora hologram) is dropped, a newly shipped one
/// is added once, and the user's edits, own automations and deletions stay.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final shipped = {
    for (final p in CustomAutomationBuiltinPresets.all()) p.id: p,
  };

  CustomAutomation step(String id, String command, {DateTime? updatedAt}) =>
      CustomAutomation(
        id: id,
        name: id,
        recordingStartFrame: 0,
        createdAt: epoch,
        updatedAt: updatedAt ?? epoch,
        steps: [
          CustomAutomationStep(
            id: '${id}_1',
            surface: CustomAutomationSurface.canvas,
            command: command,
            label: command,
            recordedFrame: 0,
          ),
        ],
      );

  String encode(CustomAutomation a) => jsonEncode(a.toJson());

  test('saved official presets follow the shipped ones', () async {
    final oldTrace = step(
      'builtin_lineart_color_trace',
      'canvas.visibleCompositeToNewTop',
    );
    final aurora = step('builtin_aurora_hologram', 'canvas.filterApply');
    final edited = step(
      'builtin_draft_to_lineart',
      'canvas.layerDuplicate',
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    final own = step(
      'automation_1',
      'canvas.layerDuplicate',
      updatedAt: DateTime.utc(2026, 9, 2),
    );
    // builtin_analog_lineart_extract is missing: the user deleted it.
    SharedPreferences.setMockInitialValues({
      'custom_automations_v1': [
        oldTrace,
        aurora,
        edited,
        own,
      ].map(encode).toList(),
      'custom_automation_favorites_v1': ['builtin_aurora_hologram'],
    });
    final service = CustomAutomationService();
    await service.init();
    final byId = {for (final a in service.items) a.id: a};
    expect(byId.keys, {
      'builtin_lineart_color_trace',
      'builtin_draft_to_lineart',
      'automation_1',
    });
    expect(
      encode(byId['builtin_lineart_color_trace']!),
      encode(shipped['builtin_lineart_color_trace']!),
      reason: 'the current recipe',
    );
    expect(
      byId['builtin_lineart_color_trace']!.steps.first.command,
      'canvas.colorsBelowClippedAbove',
    );
    expect(encode(byId['builtin_draft_to_lineart']!), encode(edited));
    expect(service.favoriteIds, isEmpty, reason: 'aurora is gone');
    // Saved as refreshed.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('custom_automations_v1')!;
    expect(saved.any((s) => s.contains('builtin_aurora_hologram')), isFalse);
    expect(
      saved.any((s) => s.contains('canvas.colorsBelowClippedAbove')),
      isTrue,
    );
  });

  test(
    'a newly shipped preset is added once, a deleted one stays away',
    () async {
      final newest = shipped.keys.last;
      SharedPreferences.setMockInitialValues({
        'custom_automations_v1': <String>[],
        // Every preset but the newest was given before (and deleted since).
        'custom_automation_offered_builtins_v1': shipped.keys
            .where((id) => id != newest)
            .toList(),
      });
      final first = CustomAutomationService();
      await first.init();
      expect(first.items.map((a) => a.id), [newest]);
      await first.delete(newest);
      final again = CustomAutomationService();
      await again.init();
      expect(again.items, isEmpty, reason: 'not brought back once deleted');
    },
  );

  test('a fresh install gets every official preset', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CustomAutomationService();
    await service.init();
    expect(service.items.map((a) => a.id).toSet(), shipped.keys.toSet());
    expect(
      service.items.map((a) => a.id),
      isNot(contains('builtin_aurora_hologram')),
    );
  });
}
