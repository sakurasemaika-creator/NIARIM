import '../l10n/app_localizations.dart';
import '../models/custom_automation.dart';
import '../models/filter_def.dart';
import 'filter_display_name.dart';

/// The official presets' names as shipped (and stored on the device), each
/// shown in the app's language until the user renames it.
const _builtinNames = {
  '線画作成（デジタル）': _BuiltinName.draftToLineart,
  '線画抽出（アナログ）': _BuiltinName.analogLineart,
  '線画色トレス': _BuiltinName.lineartColorTrace,
};

enum _BuiltinName { draftToLineart, analogLineart, lineartColorTrace }

/// An automation's (or a draft's) [name] in the app's language: the
/// official presets' shipped names are translated; any other name is the
/// user's own.
String customAutomationDisplayName(AppLocalizations l10n, String name) =>
    switch (_builtinNames[name]) {
      _BuiltinName.draftToLineart => l10n.customAutomationBuiltinDraftToLineart,
      _BuiltinName.analogLineart => l10n.customAutomationBuiltinAnalogLineart,
      _BuiltinName.lineartColorTrace =>
        l10n.customAutomationBuiltinLineartColorTrace,
      null => name,
    };

/// What a step does, in the app's language, worked out from its command and
/// settings (the label stored with it is a fallback for commands this
/// version does not describe).
String customAutomationStepLabel(
  AppLocalizations l10n,
  CustomAutomationStep step,
) {
  final args = step.args;
  num? number(String key) => args[key] is num ? args[key] as num : null;
  switch (step.command) {
    case 'canvas.selectFrame':
    case 'timeline.selectFrame':
      final frame = number('frame');
      if (frame != null) {
        return l10n.customAutomationStepFrame(frame.round() + 1);
      }
    case 'timeline.addFrame':
      return l10n.customAutomationStepAddFrame;
    case 'canvas.brushSize':
      final size = number('value');
      if (size != null) {
        return l10n.customAutomationStepBrushSize(_trimmed(size.toDouble()));
      }
    case 'canvas.brushOpacity':
      final opacity = number('value');
      if (opacity != null) {
        return l10n.customAutomationStepBrushOpacity(opacity.round());
      }
    case 'canvas.tool':
      final tool = args['tool'];
      if (tool is String) {
        return l10n.customAutomationStepTool(_toolName(l10n, tool));
      }
    case 'canvas.color':
      final argb = number('argb');
      if (argb != null) {
        final rgb = (argb.toInt() & 0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0')
            .toUpperCase();
        return l10n.customAutomationStepColor('#$rgb');
      }
    case 'canvas.filter':
    case 'canvas.filterApply':
      final raw = args['filter'];
      if (raw is Map) {
        try {
          final filter = FilterDef.fromJson(raw.cast<String, dynamic>());
          return l10n.customAutomationStepFilter(
            filterDisplayName(l10n, filter),
          );
        } catch (_) {
          // An unreadable snapshot keeps its stored label.
        }
      }
    case 'canvas.brightnessToAlpha':
      return l10n.layerPanelBrightnessToAlphaLabel;
    case 'canvas.colorsBelowClippedAbove':
      return l10n.customAutomationStepColorsBelowClipped;
    case 'canvas.layerDuplicate':
      return l10n.customAutomationStepDuplicateLayer;
    case 'canvas.mergeDown':
      return l10n.customAutomationStepMergeDown;
    case 'canvas.colorTraceAdjust':
      return l10n.customAutomationStepColorTraceAdjust;
    case 'canvas.visibleCompositeToNewTop':
      return l10n.customAutomationStepVisibleComposite;
    case 'canvas.autofillRun':
      return l10n.layerPanelMenuRunAutofill;
  }
  return step.label;
}

String _trimmed(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// A drawing tool (by its stored name) as the toolbar names it.
String _toolName(AppLocalizations l10n, String tool) => switch (tool) {
  'pen' => l10n.toolbarItemPen,
  'eraser' => l10n.toolbarItemEraser,
  'bucket' => l10n.toolbarItemBucket,
  'lasso' => l10n.penSubToolTabLassoFill,
  'eyedropper' => l10n.toolbarItemEyedropper,
  'finger' => l10n.toolbarItemFinger,
  'blur' => l10n.toolbarItemBlur,
  'mosaic' => l10n.toolbarItemMosaic,
  'selectRect' => l10n.toolbarSelectRect,
  'selectLasso' => l10n.toolbarSelectLasso,
  'selectMagicWand' => l10n.toolbarSelectMagicWand,
  'move' => l10n.commonMove,
  'ruler' => l10n.canvasRulerTooltip,
  'text' => l10n.toolbarItemText,
  'shape' => l10n.toolbarItemShape,
  'pan' => l10n.toolbarItemPan,
  'meshTransform' => l10n.canvasSelectionMeshTransform,
  _ => tool,
};
