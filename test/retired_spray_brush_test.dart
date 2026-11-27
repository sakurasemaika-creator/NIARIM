// 組み込みのスプレー（Brush0013）は外した（所有者の判断、2026-11-27
// 「スプレーってブラシ使わないんでいらないですけしてください」）。前の版の保存に
// 残っていても、起動は止まらず、壊れた項目も残らない：
// - ブラシの一覧から外し（利用者が作った複製は残す）、使っていたなら隣の
//   ブラシ（消したときと同じ、後ろのブラシ）へ移る。
// - 覚えた太さ・不透明度、早替えツール、ショートカットからも外す。
// - 引き継ぎ（.niatra）で受け取っても足さない。
import 'dart:convert';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _ja = lookupAppLocalizations(const Locale('ja'));

/// The spray as an older version saved it.
Brush _spray() => Brush.fromJson({
  ...BrushService.builtInBrushes
      .singleWhere((b) => b.id == 'Brush0003')
      .toJson(),
  'id': 'Brush0013',
  'name': 'スプレー',
  'spacing': 10,
  'scatter': 0.9,
});

/// The brush list an older version saved: the spray between the airbrush and
/// the blur, and the user's own copy of it.
List<String> _savedList() => [
  for (final brush in BrushService.builtInBrushes) ...[
    jsonEncode(brush.toJson()),
    if (brush.id == 'Brush0003') jsonEncode(_spray().toJson()),
  ],
  jsonEncode(
    _spray().toJson()
      ..['id'] = 'Brush1700000000000_0'
      ..['name'] = 'スプレー (コピー)',
  ),
];

String _tool(String id, String toolKey, {String? brushId}) => jsonEncode(
  QuickToolEntry(
    id: id,
    label: id,
    toolKey: toolKey,
    brushId: brushId,
  ).toJson(),
);

String _key(String id, LogicalKeyboardKey key, {String? brushId}) => jsonEncode(
  ShortcutBinding(
    id: id,
    label: id,
    keyId: key.keyId,
    toolKey: 'pen',
    brushId: brushId,
  ).toJson(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'brushes': _savedList(),
      'brushes_current_id': 'Brush0013',
      'brush_builtin_working_values': jsonEncode({
        'Brush0013': {'size': 30},
        'Brush0003': {'size': 50},
      }),
      'quick_tool_entries': [
        _tool('spray', 'pen', brushId: 'Brush0013'),
        _tool('eraser', 'eraser'),
      ],
      'shortcut_bindings': [
        _key('spray', LogicalKeyboardKey.keyS, brushId: 'Brush0013'),
        _key('pen', LogicalKeyboardKey.keyP, brushId: 'Brush0002'),
      ],
    });
  });

  test('a saved spray is taken out of the brushes, and the brush after it '
      'is in use', () async {
    for (var start = 0; start < 2; start++) {
      final brushes = BrushService();
      await brushes.init();
      final ids = brushes.brushes.map((b) => b.id).toList();
      expect(ids, isNot(contains('Brush0013')), reason: 'start $start');
      expect(ids, contains('Brush1700000000000_0'), reason: 'their copy');
      expect(brushes.currentBrush?.id, 'Brush0011', reason: 'start $start');
      // The airbrush keeps its own remembered width.
      expect(brushes.brushes.singleWhere((b) => b.id == 'Brush0003').size, 50);
      brushes.dispose();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs
          .getStringList('brushes')!
          .map((e) => (jsonDecode(e) as Map<String, dynamic>)['id']),
      isNot(contains('Brush0013')),
    );
    expect(prefs.getString('brushes_current_id'), 'Brush0011');
    final working =
        jsonDecode(prefs.getString('brush_builtin_working_values')!)
            as Map<String, dynamic>;
    expect(working.keys, ['Brush0003']);
  });

  test('a saved spray tool and key are taken out', () async {
    for (var start = 0; start < 2; start++) {
      final tools = QuickToolService();
      await tools.init();
      expect(tools.entries.map((e) => e.id), ['eraser']);
      final keys = ShortcutService();
      await keys.init();
      expect(keys.bindings.map((b) => b.id), isNot(contains('spray')));
      expect(keys.bindings.map((b) => b.id), contains('pen'));
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('quick_tool_entries'), hasLength(1));
    expect(
      prefs.getStringList('shortcut_bindings')!.join(),
      isNot(contains('Brush0013')),
    );
  });

  test('a received spray, spray tool or spray key is not added', () async {
    final brushes = BrushService();
    await brushes.init();
    final before = brushes.brushes.length;
    await brushes.mergeTransferred(
      [_spray()],
      copyNames: TransferCopyNames(_ja),
      currentBrushId: 'Brush0013',
    );
    expect(brushes.brushes.length, before);
    expect(brushes.brushes.map((b) => b.id), isNot(contains('Brush0013')));

    final tools = QuickToolService();
    await tools.init();
    await tools.mergeTransferred([
      _tool('spray2', 'pen', brushId: 'Brush0013'),
    ], copyNames: TransferCopyNames(_ja));
    expect(tools.entries.map((e) => e.id), ['eraser']);
    tools.replaceAll([
      QuickToolEntry.fromJson(
        jsonDecode(_tool('spray3', 'pen', brushId: 'Brush0013'))
            as Map<String, dynamic>,
      ),
      QuickToolEntry.fromJson(
        jsonDecode(_tool('picker', 'eyedropper')) as Map<String, dynamic>,
      ),
    ]);
    expect(tools.entries.map((e) => e.id), ['picker']);

    final keys = ShortcutService();
    await keys.init();
    await keys.mergeTransferred([
      _key('spray2', LogicalKeyboardKey.keyQ, brushId: 'Brush0013'),
    ]);
    expect(keys.bindings.map((b) => b.id), isNot(contains('spray2')));
    brushes.dispose();
  });
}
