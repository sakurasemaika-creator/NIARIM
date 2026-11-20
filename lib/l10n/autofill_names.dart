import '../models/autofill_preset.dart';
import '../services/autofill_preset_service.dart';
import 'app_localizations.dart';

extension AutofillPresetDisplayName on AutofillPreset {
  String displayName(AppLocalizations l10n) {
    if (!AutofillPresetService.hasDefaultPresetName(this)) return name;
    return switch (id) {
      'builtin_gray_underpaint' => l10n.autofillSampleGray,
      'p1' => l10n.autofillSampleLead,
      'p2' => l10n.autofillSampleHeroine,
      _ => name,
    };
  }
}

extension AutofillPartDisplayName on AutofillPart {
  String displayName(AppLocalizations l10n) {
    if (!AutofillPresetService.hasDefaultPartName(this)) return name;
    final words = id.split('_');
    if (id == 'builtin_gray_underpaint_base') {
      return l10n.autofillSamplePartUnderpaint;
    }
    if (words[1] == 'eye' && words.length == 3) {
      return switch (words.last) {
        'white' => l10n.autofillSamplePartEyeWhite,
        'pupil' => l10n.autofillSamplePartPupil,
        'iris' => l10n.autofillSamplePartIris,
        _ => name,
      };
    }
    final base = switch (words[1]) {
      'hair' => l10n.autofillSamplePartHair,
      'skin' => l10n.autofillSamplePartSkin,
      'eye' => l10n.autofillSamplePartIris,
      'top' => l10n.autofillSamplePartTop,
      'bottom' => l10n.autofillSamplePartBottom,
      'shoes' => l10n.autofillSamplePartShoes,
      'ribbon' => l10n.autofillSamplePartRibbon,
      _ => null,
    };
    if (base == null) return name;
    return switch (words.last) {
      'base' => base,
      's1' => l10n.autofillSamplePartShadow(base, 1),
      's2' => l10n.autofillSamplePartShadow(base, 2),
      'hl' when words[1] == 'eye' => l10n.autofillSamplePartCatchlight,
      'hl' => l10n.autofillSamplePartHighlight(base),
      _ => name,
    };
  }
}
