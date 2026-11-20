import 'dart:ui';

import '../../l10n/app_localizations.dart';
import 'tip_diagram_data.dart';
import 'tip_screen_capture.dart';

/// Screen captures from NIARIM's Flutter UI, paired with the action they show.
List<TipScreenCapture> tipCaptures(
  TipTopic topic,
  int page,
  AppLocalizations words,
) => switch ((topic, page)) {
  (TipTopic.saveSlotAutoSave, 0) => [
    TipScreenCapture(
      'assets/tips/captures/app_phone_manual-crop-000010062.webp',
      const Size(780, 1047),
      words.saveDataManualTab,
      const [Rect.fromLTWH(0.42, 0.43, 0.31, 0.12)],
    ),
    TipScreenCapture(
      'assets/tips/captures/app_phone_auto-crop-000010043.webp',
      const Size(780, 726),
      words.helpAutoSaveTitle,
      const [
        Rect.fromLTWH(0.483, 0.193, 0.223, 0.12),
        Rect.fromLTWH(0.037, 0.333, 0.915, 0.41),
      ],
    ),
    TipScreenCapture(
      'assets/tips/captures/app_phone_auto_confirm-crop-05249579.webp',
      const Size(702, 927),
      words.saveTreeRestoreAction,
      const [
        Rect.fromLTWH(0.19, 0.23, 0.62, 0.291),
        Rect.fromLTWH(0.585, 0.783, 0.24, 0.128),
      ],
    ),
    TipScreenCapture(
      'assets/tips/captures/app_phone_auto_canvas-crop-002810057.webp',
      const Size(780, 492),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.014, 0.02, 0.972, 0.95)],
    ),
  ],
  (TipTopic.timelineMarker, 0) => [
    TipScreenCapture(
      'assets/tips/captures/timeline_phone_before.webp',
      const Size(585, 1266),
      words.timelineMarkerTrackLabel,
      const [Rect.fromLTWH(0.525, 0.79, 0.07, 0.055)],
    ),
    TipScreenCapture(
      'assets/tips/captures/timeline_phone_edit.webp',
      const Size(585, 1266),
      words.commonEdit,
      const [Rect.fromLTWH(0.11, 0.31, 0.79, 0.41)],
    ),
    TipScreenCapture(
      'assets/tips/captures/timeline_phone_note.webp',
      const Size(585, 1266),
      words.timelineMarkerTrackLabel,
      const [Rect.fromLTWH(0.49, 0.8, 0.42, 0.16)],
    ),
  ],
  (TipTopic.commonLayerKeyframe, 0) => [
    TipScreenCapture(
      'assets/tips/captures/layer_keyframe_before-crop-0012100100.webp',
      const Size(585, 1114),
      words.layerPanelKeyframeLabel,
      const [Rect.fromLTWH(0.13, 0.185, 0.72, 0.3)],
    ),
    TipScreenCapture(
      'assets/tips/captures/layer_keyframe_drag-crop-0012100100.webp',
      const Size(585, 1114),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.13, 0.185, 0.72, 0.3)],
    ),
  ],
  (TipTopic.drawingAreaCamera, 0) => [
    TipScreenCapture(
      'assets/tips/captures/drawing-area.webp',
      const Size(800, 1600),
      words.newProjectDrawingAreaTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/camera_before-crop-0012100100.webp',
      const Size(585, 1114),
      words.helpCameraKeyframeTitle,
      const [Rect.fromLTWH(0.15, 0.17, 0.7, 0.33)],
    ),
    TipScreenCapture(
      'assets/tips/captures/camera_drag-crop-0012100100.webp',
      const Size(585, 1114),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.15, 0.17, 0.7, 0.33)],
    ),
  ],
  (TipTopic.audioRepeat, 0) => [
    TipScreenCapture(
      'assets/tips/captures/audio-open.webp',
      const Size(800, 1600),
      words.projectListMaterialAudio,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/audio-fade-controls.webp',
      const Size(800, 1600),
      '${words.timelineClipFadeInLabel} / ${words.timelineClipFadeOutLabel}',
      const [Rect.fromLTWH(0.04, 0.55, 0.91, 0.405)],
    ),
  ],
  (TipTopic.clipDuplicate, 0) => [
    TipScreenCapture(
      'assets/tips/captures/video-open.webp',
      const Size(800, 1600),
      words.projectListMaterialVideo,
      const [Rect.fromLTWH(0.03, 0.8, 0.94, 0.175)],
    ),
    TipScreenCapture(
      'assets/tips/captures/video-duplicate-control.webp',
      const Size(800, 1600),
      words.commonDuplicate,
      const [Rect.fromLTWH(0.53, 0.62, 0.44, 0.09)],
    ),
    TipScreenCapture(
      'assets/tips/captures/video-duplicated.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.025, 0.8, 0.95, 0.178)],
    ),
  ],
  (TipTopic.videoTrimReuse, 0) => [
    TipScreenCapture(
      'assets/tips/captures/video-trim.webp',
      const Size(800, 1600),
      '${words.timelineClipUseStartLabel} / ${words.timelineClipUseEndLabel}',
      const [Rect.fromLTWH(0.028, 0.714, 0.944, 0.274)],
    ),
    TipScreenCapture(
      'assets/tips/captures/video-trimmed.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.028, 0.714, 0.944, 0.274)],
    ),
  ],
  (TipTopic.verticalRuby, 0) => [
    TipScreenCapture(
      'assets/tips/captures/ruby-controls.webp',
      const Size(800, 1600),
      words.canvasTextVertical,
      const [Rect.fromLTWH(0.04, 0.18, 0.917, 0.285)],
    ),
    TipScreenCapture(
      'assets/tips/captures/ruby-help.webp',
      const Size(800, 1600),
      words.canvasHelpRubyTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/ruby-result.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.07, 0.136, 0.86, 0.535)],
    ),
  ],
  (TipTopic.textCaption, 0) => [
    TipScreenCapture(
      'assets/tips/textCaption.webp',
      const Size(484, 650),
      words.canvasTextInputTitle,
      const [Rect.fromLTWH(0.14, 0.204, 0.72, 0.28)],
    ),
  ],
  (TipTopic.verticalPixelFont, 0) => [
    TipScreenCapture(
      'assets/tips/captures/video-open.webp',
      const Size(800, 1600),
      words.projectListMaterialVideo,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/onion-skin.webp',
      const Size(800, 1600),
      words.workspaceDockPanelOnionSkin,
      const [],
    ),
  ],
  (TipTopic.endCardWatermark, 0) => [
    TipScreenCapture(
      'assets/tips/endCardWatermark.webp',
      const Size(600, 617),
      words.settingsWatermarkTitle,
      const [],
    ),
  ],
  (TipTopic.stampBlendMode, 0) => [
    TipScreenCapture(
      'assets/tips/blendModeUsage.webp',
      const Size(360, 623),
      words.helpBlendModeTitle,
      const [],
    ),
  ],
  (TipTopic.communityYoutube, 0) => [
    TipScreenCapture(
      'assets/tips/communityYoutube.webp',
      const Size(488, 504),
      words.helpCommunityTitle,
      const [],
    ),
  ],
  (TipTopic.autofillPreset, 0) => [
    TipScreenCapture(
      'assets/tips/autofillPreset.webp',
      const Size(488, 538),
      words.homeDrawerAutofillPreset,
      const [Rect.fromLTWH(0.043, 0.22, 0.907, 0.49)],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill_preset_p1-before-ui.webp',
      const Size(800, 1600),
      words.assetTagLineArt,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill_preset_p1-after-ui.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
  ],
  (TipTopic.officialAutomationPresets, 0) => [
    TipScreenCapture(
      'assets/tips/captures/builtin_draft_to_lineart-settings.webp',
      const Size(800, 1600),
      words.customAutomationTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/builtin_draft_to_lineart-confirm.webp',
      const Size(800, 1600),
      words.commonApply,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/builtin_draft_to_lineart-after-ui.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/builtin_analog_lineart_extract-after-ui.webp',
      const Size(800, 1600),
      words.customAutomationBuiltinAnalogLineart,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/builtin_lineart_color_trace-after-ui.webp',
      const Size(800, 1600),
      words.customAutomationBuiltinLineartColorTrace,
      const [],
    ),
  ],
  (TipTopic.autofillBaseCoat, 0) => [
    TipScreenCapture(
      'assets/tips/captures/autofill_preset_builtin_gray_underpaint-before-ui.webp',
      const Size(800, 1600),
      words.assetTagLineArt,
      const [Rect.fromLTWH(0.037, 0.15, 0.92, 0.48)],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill_preset_builtin_gray_underpaint-after-ui.webp',
      const Size(800, 1600),
      words.helpAutoFillTitle,
      const [Rect.fromLTWH(0.037, 0.15, 0.92, 0.48)],
    ),
  ],
  (TipTopic.autofillManualPartColor, 0) => [
    TipScreenCapture(
      'assets/tips/captures/normal-layer-above.webp',
      const Size(800, 1600),
      words.layerPanelMenuNormalLayer,
      const [],
    ),
  ],
  (TipTopic.autofillManualPartColor, 1) => [
    TipScreenCapture(
      'assets/tips/captures/autofill-lineart-menu.webp',
      const Size(800, 1600),
      words.layerPanelMenuLineartLayer,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-part-assign.webp',
      const Size(800, 1600),
      words.layerPanelMenuPartAssign,
      const [],
    ),
  ],
  (TipTopic.autofillManualPartColor, 2) => [
    TipScreenCapture(
      'assets/tips/captures/autofill-generate-mode.webp',
      const Size(800, 1600),
      words.layerPanelAutofillRepaintTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-color-before.webp',
      const Size(800, 1600),
      words.layerPanelMenuAutofillLayer,
      const [],
    ),
  ],
  (TipTopic.autofillManualPartColor, 3) => [
    TipScreenCapture(
      'assets/tips/autofillManualPartColor.webp',
      const Size(439, 650),
      words.layerPanelAutofillColorUpdateTitle,
      const [Rect.fromLTWH(0.095, 0.42, 0.806, 0.208)],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-color-after.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
  ],
  (TipTopic.brushFavorite, 0) => [
    TipScreenCapture(
      'assets/tips/brushFavorite.webp',
      const Size(600, 478),
      words.transferItemBrush,
      const [Rect.fromLTWH(0.44, 0.25, 0.48, 0.26)],
    ),
  ],
  (TipTopic.brushTrySaveTree, 0) => [
    TipScreenCapture(
      'assets/tips/captures/app_wide_manual.webp',
      const Size(1200, 750),
      words.saveTreeScreenTitleTree,
      const [Rect.fromLTWH(0.008, 0.89, 0.14, 0.065)],
    ),
    TipScreenCapture(
      'assets/tips/captures/brush-settings.webp',
      const Size(800, 1600),
      words.transferItemBrush,
      const [Rect.fromLTWH(0.03, 0.276, 0.938, 0.281)],
    ),
    TipScreenCapture(
      'assets/tips/captures/app_wide_manual_confirm.webp',
      const Size(1200, 750),
      words.saveTreeRestoreAction,
      const [Rect.fromLTWH(0.326, 0.27, 0.357, 0.46)],
    ),
  ],
  (TipTopic.eyedropperGesture, 0) => [
    TipScreenCapture(
      'assets/tips/gestureShortcut.webp',
      const Size(430, 650),
      words.settingsGestureTitle,
      const [],
    ),
  ],
  (TipTopic.magicWandLasso, 0) => [
    TipScreenCapture(
      'assets/tips/magicWandLasso.webp',
      const Size(441, 650),
      words.toolbarSelectLasso,
      const [Rect.fromLTWH(0.11, 0.79, 0.79, 0.14)],
    ),
  ],
  (TipTopic.commonLayerFolder, 0) => [
    TipScreenCapture(
      'assets/tips/captures/common-layer-convert.webp',
      const Size(800, 1600),
      words.layerPanelConvertToCommonLabel,
      const [Rect.fromLTWH(0.078, 0.35, 0.842, 0.34)],
    ),
    TipScreenCapture(
      'assets/tips/captures/common-layer-range.webp',
      const Size(800, 1600),
      words.layerPanelCommonRangeTitle,
      const [Rect.fromLTWH(0.124, 0.322, 0.744, 0.364)],
    ),
    TipScreenCapture(
      'assets/tips/captures/common-layer.webp',
      const Size(800, 1600),
      words.helpCommonLayerTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/layer-folder.webp',
      const Size(800, 1600),
      words.helpFolderTitle,
      const [],
    ),
  ],
  (TipTopic.quickToolPenSub, 0) => [
    TipScreenCapture(
      'assets/tips/quickToolPenSub.webp',
      const Size(441, 650),
      words.toolbarItemPen,
      const [Rect.fromLTWH(0.04, 0.03, 0.51, 0.565)],
    ),
  ],
  (TipTopic.quickToolVariant, 0) => [
    TipScreenCapture(
      'assets/tips/quickToolVariant.webp',
      const Size(454, 650),
      words.helpQuickToolTitle,
      const [Rect.fromLTWH(0.37, 0.35, 0.61, 0.44)],
    ),
  ],
  (TipTopic.autofillToneReuse, 0) => [
    TipScreenCapture(
      'assets/tips/captures/autofill-preset-parts.webp',
      const Size(800, 1600),
      words.homeDrawerAutofillPreset,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-part-tone-crop-07049189.webp',
      const Size(797, 1600),
      words.autofillPartUseToneCheckbox,
      const [Rect.fromLTWH(0.042, 0.707, 0.899, 0.112)],
    ),
  ],
  (TipTopic.autofillMisfill, 0) => [
    TipScreenCapture(
      'assets/tips/captures/autofill-color-before.webp',
      const Size(800, 1600),
      words.autofillPartSelectColorButton,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/autofillManualPartColor.webp',
      const Size(439, 650),
      words.layerPanelAutofillColorUpdateTitle,
      const [Rect.fromLTWH(0.095, 0.42, 0.806, 0.208)],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-color-after.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
  ],
  (TipTopic.homeWidget, 0) => [
    TipScreenCapture(
      'assets/tips/homeWidget.webp',
      const Size(462, 650),
      words.widgetSettingsTitle,
      const [Rect.fromLTWH(0.05, 0.45, 0.9, 0.37)],
    ),
    TipScreenCapture(
      'assets/tips/captures/widget-projects.webp',
      const Size(800, 1600),
      words.themePreviewScreenProjects,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/widget-frame.webp',
      const Size(800, 1600),
      words.timelineFrameTrackLabel,
      const [],
    ),
  ],
  (TipTopic.autofillTransparentFix, 0) => [
    TipScreenCapture(
      'assets/tips/transparentColor.webp',
      const Size(496, 650),
      words.canvasBackgroundTransparent,
      const [],
    ),
  ],
  (TipTopic.quickToolSwipe, 0) => [
    TipScreenCapture(
      'assets/tips/quickToolVariant.webp',
      const Size(454, 650),
      words.helpQuickToolTitle,
      const [Rect.fromLTWH(0.37, 0.35, 0.61, 0.44)],
    ),
  ],
  (TipTopic.toolbarCustomize, 0) => [
    TipScreenCapture(
      'assets/tips/toolbarCustomize.webp',
      const Size(470, 650),
      words.workspaceToolbarEditSection,
      const [Rect.fromLTWH(0.045, 0.18, 0.9, 0.65)],
    ),
  ],
  (TipTopic.pcDexLayout, 0) => [
    TipScreenCapture(
      'assets/tips/captures/workspace-controls.webp',
      const Size(800, 1600),
      words.settingsWorkspaceTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/leftHandedWorkspace.webp',
      const Size(470, 650),
      words.workspacePcModeSection,
      const [Rect.fromLTWH(0.047, 0.335, 0.89, 0.51)],
    ),
    TipScreenCapture(
      'assets/tips/pcDexLayout.webp',
      const Size(780, 504),
      words.workspacePcModeAlwaysPc,
      const [],
    ),
  ],
  (TipTopic.commonLayerLipSync, 0) => [
    TipScreenCapture(
      'assets/tips/captures/common-layer-convert.webp',
      const Size(800, 1600),
      words.layerPanelConvertToCommonLabel,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/common-layer-range.webp',
      const Size(800, 1600),
      words.layerPanelCommonRangeTitle,
      const [Rect.fromLTWH(0.124, 0.322, 0.744, 0.364)],
    ),
  ],
  (TipTopic.transparentColor, 0) => [
    TipScreenCapture(
      'assets/tips/transparentColor.webp',
      const Size(496, 650),
      words.canvasBackgroundTransparent,
      const [],
    ),
  ],
  (TipTopic.pressureCurve, 0) => [
    TipScreenCapture(
      'assets/tips/captures/pressure-controls.webp',
      const Size(800, 1600),
      words.penSettingsCurveSection,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/pressureCurve.webp',
      const Size(449, 650),
      words.penSettingsCurveCustom,
      const [Rect.fromLTWH(0.09, 0.41, 0.82, 0.56)],
    ),
  ],
  (TipTopic.rulerOnion, 0) => [
    TipScreenCapture(
      'assets/tips/captures/perspective-ruler.webp',
      const Size(800, 1600),
      words.rulerTypeOnePoint,
      const [Rect.fromLTWH(0.05, 0.17, 0.89, 0.475)],
    ),
    TipScreenCapture(
      'assets/tips/captures/onion-skin.webp',
      const Size(800, 1600),
      words.workspaceDockPanelOnionSkin,
      const [Rect.fromLTWH(0.501, 0.074, 0.441, 0.107)],
    ),
  ],
  (TipTopic.fourPanelBrush, 0) => [
    TipScreenCapture(
      'assets/tips/captures/four-panel-settings.webp',
      const Size(800, 1600),
      words.rulerTypeLine,
      const [Rect.fromLTWH(0.004, 0.331, 0.988, 0.321)],
    ),
    TipScreenCapture(
      'assets/tips/captures/four-panel-result-crop-002610067.webp',
      const Size(960, 787),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.116, 0.3, 0.752, 0.353)],
    ),
  ],
  (TipTopic.gradientTrace, 0) => [
    TipScreenCapture(
      'assets/tips/gradientTrace.webp',
      const Size(458, 650),
      words.autofillPartGradientSetButton,
      const [],
    ),
  ],
  (TipTopic.gradientOutlineHair, 0) => [
    TipScreenCapture(
      'assets/tips/gradientTrace.webp',
      const Size(458, 650),
      words.autofillPartOutlineLabel,
      const [],
    ),
  ],
  (TipTopic.brushFold, 0) => [
    TipScreenCapture(
      'assets/tips/brushFold.webp',
      const Size(302, 650),
      words.brushFold,
      const [Rect.fromLTWH(0.045, 0.165, 0.9, 0.725)],
    ),
  ],
  (TipTopic.strokeDecayFade, 0) => [
    TipScreenCapture(
      'assets/tips/captures/brush-settings.webp',
      const Size(800, 1600),
      words.brushSettingsFadeModeTitle,
      const [Rect.fromLTWH(0.052, 0.735, 0.89, 0.251)],
    ),
    TipScreenCapture(
      'assets/tips/captures/brush-decay.webp',
      const Size(800, 1600),
      words.helpStrokeDecayTitle,
      const [Rect.fromLTWH(0.035, 0.28, 0.907, 0.072)],
    ),
  ],
  (TipTopic.colorMixingFade, 0) => [
    TipScreenCapture(
      'assets/tips/captures/brush-mixing.webp',
      const Size(800, 1600),
      words.helpColorMixingTitle,
      const [Rect.fromLTWH(0.055, 0.419, 0.89, 0.202)],
    ),
    TipScreenCapture(
      'assets/tips/captures/brush-settings.webp',
      const Size(800, 1600),
      words.brushSettingsFadeModeTitle,
      const [Rect.fromLTWH(0.052, 0.735, 0.89, 0.251)],
    ),
  ],
  (TipTopic.radialVignette, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0009_default-settings.webp',
      const Size(960, 1920),
      words.filterNameVignette,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0009_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.clippingGradient, 0) => [
    TipScreenCapture(
      'assets/tips/captures/layer-clipping-menu.webp',
      const Size(800, 1600),
      words.helpClippingTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/clipping-gradient-render.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
  ],
  (TipTopic.autofillBlendMode, 0) => [
    TipScreenCapture(
      'assets/tips/captures/autofill-blend-mode-crop-06039290.webp',
      const Size(790, 1600),
      words.autofillPartBlendModeLabel,
      const [Rect.fromLTWH(0.04, 0.84, 0.897, 0.138)],
    ),
    TipScreenCapture(
      'assets/tips/captures/autofill-blend-options-crop-07029297.webp',
      const Size(718, 1600),
      words.blendModeOverlay,
      const [
        Rect.fromLTWH(0.042, 0.2, 0.9, 0.054),
        Rect.fromLTWH(0.041, 0.66, 0.9, 0.053),
      ],
    ),
  ],
  (TipTopic.roughLayerRescue, 0) => [
    TipScreenCapture(
      'assets/tips/roughLayerRescue.webp',
      const Size(500, 650),
      words.layerPanelBrightnessToAlphaLabel,
      const [],
    ),
  ],
  (TipTopic.lineArtExtraction, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0029_default-settings.webp',
      const Size(960, 1920),
      words.filterNameColorAdjust,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0014_default-settings.webp',
      const Size(960, 1920),
      words.filterNameThreshold,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/builtin_analog_lineart_extract-after-ui.webp',
      const Size(800, 1600),
      words.timelinePreviewPlaceholder,
      const [],
    ),
  ],
  (TipTopic.lineColorUsage, 0) => [
    TipScreenCapture(
      'assets/tips/lineColorUsage.webp',
      const Size(602, 650),
      words.autofillPartLineColorLabel,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/line-color-mode-crop-07039189.webp',
      const Size(786, 1600),
      words.autofillLineColorModeSameAsFill,
      const [Rect.fromLTWH(0.078, 0.266, 0.82, 0.263)],
    ),
  ],
  (TipTopic.blushAutofill, 0) => [
    TipScreenCapture(
      'assets/tips/blushAutofill.webp',
      const Size(478, 650),
      words.layerPanelAutofillMethodTitle,
      const [],
    ),
  ],
  (TipTopic.stockingDenier, 0) => [
    TipScreenCapture(
      'assets/tips/captures/stocking-denier-real-crop-23258175.webp',
      const Size(557, 960),
      words.toneTitle,
      const [Rect.fromLTWH(0.029, 0.45, 0.93, 0.531)],
    ),
  ],
  (TipTopic.rainNoise, 0) => [
    TipScreenCapture(
      'assets/tips/rainNoise.webp',
      const Size(485, 650),
      '${words.timelineEffectTypeRain} / ${words.timelineEffectTypeAnimatedNoise}',
      const [Rect.fromLTWH(0.046, 0.555, 0.907, 0.39)],
    ),
  ],
  (TipTopic.texturePrismVhs, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0022_default-settings.webp',
      const Size(960, 1920),
      words.filterNamePrism,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0022_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.partKeyframeGroup, 0) => [
    TipScreenCapture(
      'assets/tips/partKeyframeGroup.webp',
      const Size(488, 633),
      words.layerPanelKeyframeLabel,
      const [Rect.fromLTWH(0.06, 0.5, 0.86, 0.471)],
    ),
  ],
  (TipTopic.outlineAnimeStyle, 0) => [
    TipScreenCapture(
      'assets/tips/captures/outline-anime-step-1.webp',
      const Size(960, 1920),
      words.filterNameOutline,
      const [Rect.fromLTWH(0.021, 0.554, 0.95, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/outline-anime-step-2.webp',
      const Size(960, 1806),
      words.filterNameAnimeStyle,
      const [Rect.fromLTWH(0.020, 0.522, 0.960, 0.458)],
    ),
    TipScreenCapture(
      'assets/tips/captures/outline-anime-result.webp',
      const Size(960, 1496),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.009, 0.063, 0.982, 0.408)],
    ),
  ],
  (TipTopic.levelsToneCurve, 0) => [
    TipScreenCapture(
      'assets/tips/captures/levels-tone-step-1.webp',
      const Size(960, 1920),
      words.filterNameLevels,
      const [Rect.fromLTWH(0.021, 0.554, 0.95, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/levels-tone-step-2.webp',
      const Size(960, 1920),
      words.filterNameToneCurve,
      const [Rect.fromLTWH(0.021, 0.554, 0.95, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/levels-tone-result.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.164, 0.922, 0.375)],
    ),
  ],
  (TipTopic.toneCurveSepia, 0) => [
    TipScreenCapture(
      'assets/tips/toneCurveSepia.webp',
      const Size(485, 650),
      '${words.filterNameToneCurve} / ${words.timelineEffectTypeSepia}',
      const [Rect.fromLTWH(0.048, 0.594, 0.906, 0.381)],
    ),
  ],
  (TipTopic.cameraLensBlur, 0) => [
    TipScreenCapture(
      'assets/tips/captures/camera_drag.webp',
      const Size(585, 1266),
      words.helpCameraKeyframeTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0002_default-settings.webp',
      const Size(960, 1920),
      words.filterNameLensBlur,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0002_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.webmCommonLayer, 0) => [
    TipScreenCapture(
      'assets/tips/captures/common-layer-convert.webp',
      const Size(800, 1600),
      words.layerPanelConvertToCommonLabel,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/export-formats.webp',
      const Size(800, 1600),
      words.exportFormatSection,
      const [Rect.fromLTWH(0.025, 0.254, 0.948, 0.29)],
    ),
  ],
  (TipTopic.leftHandedWorkspace, 0) => [
    TipScreenCapture(
      'assets/tips/leftHandedWorkspace.webp',
      const Size(470, 650),
      words.workspaceLeftHandedMode,
      const [],
    ),
  ],
  (TipTopic.blendModeUsage, 0) => [
    TipScreenCapture(
      'assets/tips/captures/blend_multiply-settings.webp',
      const Size(960, 1920),
      words.blendModeMultiply,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/blend_multiply-after-ui.webp',
      const Size(960, 1920),
      words.blendModeMultiply,
      const [Rect.fromLTWH(0.038, 0.154, 0.925, 0.49)],
    ),
    TipScreenCapture(
      'assets/tips/captures/blend_screen-after-ui.webp',
      const Size(960, 1920),
      words.blendModeScreen,
      const [Rect.fromLTWH(0.038, 0.154, 0.925, 0.49)],
    ),
    TipScreenCapture(
      'assets/tips/captures/blend_overlay-after-ui.webp',
      const Size(960, 1920),
      words.blendModeOverlay,
      const [Rect.fromLTWH(0.038, 0.154, 0.925, 0.49)],
    ),
  ],
  (TipTopic.fisheyeChromatic, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0015_default-settings.webp',
      const Size(960, 1806),
      words.filterNameFisheye,
      const [Rect.fromLTWH(0.020, 0.522, 0.960, 0.458)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0016_default-settings.webp',
      const Size(960, 1797),
      words.filterNameChromaticAberration,
      const [Rect.fromLTWH(0.020, 0.519, 0.960, 0.461)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0016_default-after-ui.webp',
      const Size(960, 1681),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.009, 0.056, 0.982, 0.363)],
    ),
  ],
  (TipTopic.lensDistortion, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0017_default-settings.webp',
      const Size(960, 1806),
      words.filterLensMaskTitle,
      const [Rect.fromLTWH(0.020, 0.522, 0.960, 0.458)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0017_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.sphereShading, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0028_default-settings.webp',
      const Size(960, 1920),
      words.filterNameSphereShading,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0028_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.backgroundBlend, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0020_default-settings.webp',
      const Size(960, 1920),
      words.filterNameBackgroundBlend,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0020_default-after-ui.webp',
      const Size(960, 1920),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.04, 0.165, 0.92, 0.375)],
    ),
  ],
  (TipTopic.exportFormat, 0) => [
    TipScreenCapture(
      'assets/tips/captures/export-formats.webp',
      const Size(800, 1600),
      words.exportFormatSection,
      const [Rect.fromLTWH(0.021, 0.157, 0.953, 0.427)],
    ),
  ],
  (TipTopic.gestureShortcut, 0) => [
    TipScreenCapture(
      'assets/tips/gestureShortcut.webp',
      const Size(430, 650),
      words.settingsGestureTitle,
      const [Rect.fromLTWH(0.03, 0.115, 0.899, 0.625)],
    ),
    TipScreenCapture(
      'assets/tips/captures/gesture-controls.webp',
      const Size(800, 1600),
      words.settingsGestureTitle,
      const [],
    ),
  ],
  (TipTopic.lowSpecSettings, 0) => [
    TipScreenCapture(
      'assets/tips/lowSpecSettings.webp',
      const Size(488, 644),
      words.settingsPerformanceTitle,
      const [Rect.fromLTWH(0.04, 0.21, 0.9, 0.716)],
    ),
  ],
  (TipTopic.seriesPresetFolder, 0) => [
    TipScreenCapture(
      'assets/tips/seriesPresetFolder.webp',
      const Size(428, 650),
      words.helpFolderTitle,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/autofillPreset.webp',
      const Size(488, 538),
      words.homeDrawerAutofillPreset,
      const [],
    ),
    TipScreenCapture(
      'assets/tips/captures/project-preset-filter.webp',
      const Size(800, 1600),
      words.autofillPartAddDialogTitle,
      const [],
    ),
  ],
  (TipTopic.mosaicChromatic, 0) => [
    TipScreenCapture(
      'assets/tips/captures/mosaic-chromatic-step-1.webp',
      const Size(960, 1617),
      words.filterNameMosaic,
      const [Rect.fromLTWH(0.020, 0.466, 0.960, 0.512)],
    ),
    TipScreenCapture(
      'assets/tips/captures/mosaic-chromatic-step-2.webp',
      const Size(960, 1797),
      words.filterNameChromaticAberration,
      const [Rect.fromLTWH(0.020, 0.519, 0.960, 0.461)],
    ),
    TipScreenCapture(
      'assets/tips/captures/mosaic-chromatic-result.webp',
      const Size(960, 1496),
      words.timelinePreviewPlaceholder,
      const [Rect.fromLTWH(0.009, 0.063, 0.982, 0.408)],
    ),
  ],
  (TipTopic.pixelToneRetro, 0) => [
    TipScreenCapture(
      'assets/tips/captures/pixel-stamp.webp',
      const Size(800, 1600),
      words.stampTitle,
      const [Rect.fromLTWH(0.034, 0.072, 0.58, 0.075)],
    ),
    TipScreenCapture(
      'assets/tips/captures/pixel-tone-real-crop-23258175.webp',
      const Size(557, 958),
      words.toneTitle,
      const [Rect.fromLTWH(0.023, 0.44, 0.943, 0.248)],
    ),
  ],
  (TipTopic.blurVignetteBg, 0) => [
    TipScreenCapture(
      'assets/tips/captures/Filter0001_default-settings.webp',
      const Size(960, 1617),
      words.filterNameGaussianBlur,
      const [Rect.fromLTWH(0.020, 0.466, 0.960, 0.512)],
    ),
    TipScreenCapture(
      'assets/tips/captures/Filter0009_default-settings.webp',
      const Size(960, 1920),
      words.filterNameVignette,
      const [Rect.fromLTWH(0.02, 0.55, 0.96, 0.43)],
    ),
  ],
  (TipTopic.sepiaVignette, 0) => [
    TipScreenCapture(
      'assets/tips/sepiaVignette.webp',
      const Size(485, 650),
      '${words.timelineEffectTypeSepia} / ${words.filterNameVignette}',
      const [Rect.fromLTWH(0.04, 0.61, 0.91, 0.35)],
    ),
  ],
  (TipTopic.transferDevice, 0) => [
    TipScreenCapture(
      'assets/tips/captures/transfer_01_screen.webp',
      const Size(739, 1600),
      words.transferScreenTitle,
      const [Rect.fromLTWH(0.025, 0.169, 0.951, 0.692)],
    ),
  ],
  (TipTopic.transferCustomization, 0) => [
    TipScreenCapture(
      'assets/tips/transferDevice.webp',
      const Size(385, 650),
      words.transferScreenTitle,
      const [Rect.fromLTWH(0.038, 0.185, 0.92, 0.7)],
    ),
  ],
  _ => const [],
};
