from pathlib import Path
import re

path = Path('lib/screens/canvas/widgets/brush_panel.dart')
s = path.read_text()

if "import '../../../services/settings_service.dart';" not in s:
    s = s.replace(
        "import '../../../services/brush_service.dart';\n",
        "import '../../../services/brush_service.dart';\nimport '../../../services/settings_service.dart';\n",
    )

marker = "class _BrushSettingsSheetState extends State<_BrushSettingsSheet> {"
start = s.index(marker)
sub = s[start:]
needle = "    final l10n = AppLocalizations.of(context)!;\n"
pos = sub.index(needle)
sub = sub[:pos] + needle + "    final penPressureEnabled = context.read<SettingsService>().penPressureEnabled;\n" + sub[pos + len(needle):]
s = s[:start] + sub

common_start = s.index("          _settingsSection(\n            title: l10n.brushSettingsCommonSection,")
on_start = s.index("          _settingsSection(\n            title: l10n.brushSettingsPressureOnSection,", common_start)
common = s[common_start:on_start]

# Size and opacity are tool-time controls, not brush customization common settings.
common = re.sub(
    r"\n              _sliderRow\(\n                l10n\.brushSettingsSizeLabel,.*?\n              \),\n              _sliderRow\(\n                l10n\.brushSettingsOpacityLabel,.*?\n              \),",
    "",
    common,
    count=1,
    flags=re.S,
)

# Stabilization and strength are also tool-time controls per the approved spec.
common = re.sub(
    r"\n              SwitchListTile\(\n                title: Text\(l10n\.brushSettingsStabilizationTitle\),.*?\n              if \(_brush\.stabilization\)\n                _sliderRow\(.*?\n                \),",
    "",
    common,
    count=1,
    flags=re.S,
)

# Common stays open initially; pressure ON/OFF initial expansion follows app pressure state.
common = common.replace(
    "            title: l10n.brushSettingsCommonSection,\n            children:",
    "            title: l10n.brushSettingsCommonSection,\n            initiallyExpanded: true,\n            children:",
    1,
)
s = s[:common_start] + common + s[on_start:]

s = s.replace(
    "          _settingsSection(\n            title: l10n.brushSettingsPressureOnSection,\n            children:",
    "          _settingsSection(\n            title: l10n.brushSettingsPressureOnSection,\n            initiallyExpanded: penPressureEnabled,\n            children:",
    1,
)
s = s.replace(
    "          _settingsSection(\n            title: l10n.brushSettingsPressureOffSection,\n            children:",
    "          _settingsSection(\n            title: l10n.brushSettingsPressureOffSection,\n            initiallyExpanded: !penPressureEnabled,\n            children:",
    1,
)

s = s.replace(
    "  Widget _settingsSection({\n    required String title,\n    required List<Widget> children,\n  }) {",
    "  Widget _settingsSection({\n    required String title,\n    required bool initiallyExpanded,\n    required List<Widget> children,\n  }) {",
    1,
)
s = s.replace(
    "      initiallyExpanded: true,\n      childrenPadding:",
    "      initiallyExpanded: initiallyExpanded,\n      childrenPadding:",
    1,
)

path.write_text(s)
