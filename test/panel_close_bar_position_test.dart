import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const panelFiles = <String>[
    'lib/screens/canvas/widgets/brush_panel.dart',
    'lib/screens/canvas/widgets/color_picker_panel.dart',
    'lib/screens/canvas/widgets/filter_panel.dart',
    'lib/screens/canvas/widgets/layer_panel.dart',
    'lib/screens/canvas/widgets/onion_skin_panel.dart',
    'lib/screens/canvas/widgets/quick_tool_panel.dart',
    'lib/screens/canvas/widgets/ruler_panel.dart',
    'lib/screens/canvas/widgets/stamp_panel.dart',
    'lib/screens/canvas/widgets/tone_panel.dart',
  ];

  test(
    'tool detail panels keep the shared close affordance as the final child',
    () {
      final bottomClose = RegExp(
        r'PanelCenterCloseBar\(onClose: (?:widget\.)?onClose\),\s*\],',
        multiLine: true,
      );

      for (final path in panelFiles) {
        final source = File(path).readAsStringSync();
        expect(
          'PanelCenterCloseBar('.allMatches(source).length,
          1,
          reason: '$path must contain exactly one shared close affordance',
        );
        expect(
          bottomClose.hasMatch(source),
          isTrue,
          reason: '$path must place the close affordance after panel content',
        );
      }
    },
  );
}
