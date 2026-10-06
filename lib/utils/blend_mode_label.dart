import '../l10n/app_localizations.dart';
import '../models/layer.dart';

/// The name a blend mode is shown by (the layer panel's list, the auto-fill
/// parts, sphere shading's blend modes).
String blendModeLabel(AppLocalizations l10n, LayerBlendMode mode) =>
    switch (mode) {
      LayerBlendMode.normal => l10n.blendModeNormal,
      LayerBlendMode.multiply => l10n.blendModeMultiply,
      LayerBlendMode.screen => l10n.blendModeScreen,
      LayerBlendMode.overlay => l10n.blendModeOverlay,
      LayerBlendMode.addition => l10n.blendModeAddition,
      LayerBlendMode.subtract => l10n.blendModeSubtract,
      LayerBlendMode.darken => l10n.blendModeDarken,
      LayerBlendMode.lighten => l10n.blendModeLighten,
      LayerBlendMode.colorBurn => l10n.blendModeColorBurn,
      LayerBlendMode.colorDodge => l10n.blendModeColorDodge,
      LayerBlendMode.hardLight => l10n.blendModeHardLight,
      LayerBlendMode.softLight => l10n.blendModeSoftLight,
      LayerBlendMode.difference => l10n.blendModeDifference,
      LayerBlendMode.hue => l10n.blendModeHue,
      LayerBlendMode.saturation => l10n.blendModeSaturation,
      LayerBlendMode.color => l10n.blendModeColor,
      LayerBlendMode.luminosity => l10n.blendModeLuminosity,
      LayerBlendMode.linearBurn => l10n.blendModeLinearBurn,
      LayerBlendMode.linearDodge => l10n.blendModeLinearDodge,
      LayerBlendMode.vividLight => l10n.blendModeVividLight,
      LayerBlendMode.linearLight => l10n.blendModeLinearLight,
      LayerBlendMode.pinLight => l10n.blendModePinLight,
      LayerBlendMode.hardMix => l10n.blendModeHardMix,
      LayerBlendMode.exclusion => l10n.blendModeExclusion,
      LayerBlendMode.divide => l10n.blendModeDivide,
    };
