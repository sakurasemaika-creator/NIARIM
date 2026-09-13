from pathlib import Path
import subprocess


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    return text.replace(old, new, 1)


def reset_from_dev(path: str) -> str:
    return subprocess.check_output(
        ['git', 'show', f'origin/dev_branch:{path}'], text=True
    )


brush_path = 'lib/screens/canvas/widgets/brush_panel.dart'
brush = reset_from_dev(brush_path)
brush = replace_once(
    brush,
    "import '../../../models/brush.dart';\n",
    "import '../../../models/brush.dart';\nimport '../../../models/pressure_hardness.dart';\n",
    'pressure hardness import',
)
old_pressure = """          RadioGroup<PressureMode>(
            groupValue: _brush.pressureMode,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(pressureMode: v)),
            child: Column(
              children: PressureMode.values
                  .map(
                    (mode) => RadioListTile<PressureMode>(
                      title: Text(_pressureLabel(l10n, mode)),
                      value: mode,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(),
"""
new_pressure = """          RadioGroup<PressureMode>(
            groupValue: _brush.pressureMode,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                final normalizedStrength = v == PressureMode.off
                    ? _brush.pressureStrength
                    : pressureStrengthForHardness(
                        pressureHardnessForStrength(_brush.pressureStrength),
                      );
                _brush = _brush.copyWith(
                  pressureMode: v,
                  pressureStrength: normalizedStrength,
                );
              });
            },
            child: Column(
              children: PressureMode.values
                  .map(
                    (mode) => RadioListTile<PressureMode>(
                      title: Text(_pressureLabel(l10n, mode)),
                      value: mode,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          _pressureHardnessRow(l10n),
          const Divider(),
"""
brush = replace_once(brush, old_pressure, new_pressure, 'pressure mode controls')
slider_anchor = """  Widget _sliderRow(
    String label,
"""
hardness_helper = """  Widget _pressureHardnessRow(AppLocalizations l10n) {
    final enabled = isPressureHardnessEnabled(_brush.pressureMode);
    final hardness = pressureHardnessForStrength(_brush.pressureStrength);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            l10n.brushSettingsPressureHardnessLabel,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: SteppedSlider(
            min: kMinPressureHardness.toDouble(),
            max: kMaxPressureHardness.toDouble(),
            divisions: kMaxPressureHardness - kMinPressureHardness,
            step: 1,
            value: hardness.toDouble(),
            label: '$hardness',
            onChanged: enabled
                ? (v) => setState(
                    () => _brush = _brush.copyWith(
                      pressureStrength: pressureStrengthForHardness(v.round()),
                    ),
                  )
                : null,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$hardness',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: enabled
                  ? null
                  : ThemeService.activeColorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
"""
brush = replace_once(brush, slider_anchor, hardness_helper, 'hardness row insertion')
Path(brush_path).write_text(brush)

manager_path = 'lib/widgets/custom_automation_manager_sheet.dart'
manager = Path(manager_path).read_text()
rerecord_anchor = """  void _rerecord(BuildContext context, CustomAutomation item) {
    final service = context.read<CustomAutomationService>();
    service.editExisting(item.id);
    service.resumeRecording(surface);
    Navigator.pop(context);
    onRecordingStarted();
  }

  @override
"""
manager_helper = """  void _rerecord(BuildContext context, CustomAutomation item) {
    final service = context.read<CustomAutomationService>();
    service.editExisting(item.id);
    service.resumeRecording(surface);
    Navigator.pop(context);
    onRecordingStarted();
  }

  Future<void> _showItemManager(
    BuildContext context,
    CustomAutomation item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<CustomAutomationService>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name),
              subtitle: Text(l10n.customAutomationStepCount(item.steps.length)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.customAutomationRunAction),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmExecute(context, item);
              },
            ),
            ListTile(
              leading: Icon(
                service.isFavorite(item.id) ? Icons.star : Icons.star_border,
              ),
              title: Text(
                service.isFavorite(item.id)
                    ? l10n.customAutomationUnfavoriteAction
                    : l10n.customAutomationFavoriteAction,
              ),
              onTap: () async {
                await service.toggleFavorite(item.id);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.customAutomationRenameTitle),
              onTap: () {
                Navigator.pop(sheetContext);
                _rename(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.customAutomationExport),
              onTap: () {
                Navigator.pop(sheetContext);
                _export(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fiber_manual_record),
              title: Text(l10n.customAutomationRerecord),
              onTap: () {
                Navigator.pop(sheetContext);
                _rerecord(context, item);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(context, item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
"""
manager = replace_once(manager, rerecord_anchor, manager_helper, 'item manager helper')
old_tile = """                        final item = visibleItems[index];
                        final favorite = service.isFavorite(item.id);
                        return ListTile(
                          key: ValueKey(item.id),
                          onTap: () => _confirmExecute(context, item),
                          title: Row(
                            children: [
                              IconButton(
                                key: ValueKey('custom-automation-favorite-${item.id}'),
                                tooltip: favorite ? 'お気に入り解除' : 'お気に入り登録',
                                icon: Icon(favorite ? Icons.star : Icons.star_border, size: 20),
                                onPressed: () => service.toggleFavorite(item.id),
                              ),
                              Expanded(child: Text(item.name)),
                              IconButton(
                                tooltip: l10n.customAutomationRenameTitle,
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _rename(context, item),
                              ),
                            ],
                          ),
                          subtitle: Text(l10n.customAutomationStepCount(item.steps.length)),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: l10n.customAutomationExport,
                                icon: const Icon(Icons.ios_share, size: 18),
                                onPressed: () => _export(context, item),
                              ),
                              IconButton(
                                tooltip: l10n.customAutomationRerecord,
                                icon: const Icon(Icons.fiber_manual_record, size: 18),
                                onPressed: () => _rerecord(context, item),
                              ),
                              IconButton(
                                tooltip: l10n.commonDelete,
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _delete(context, item),
                              ),
                            ],
                          ),
                        );
"""
new_tile = """                        final item = visibleItems[index];
                        final favorite = service.isFavorite(item.id);
                        return ListTile(
                          key: ValueKey(item.id),
                          onTap: () => _showItemManager(context, item),
                          title: Text(item.name),
                          subtitle: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.customAutomationStepCount(item.steps.length),
                              ),
                              if (favorite)
                                const Icon(Icons.star, size: 16),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        );
"""
manager = replace_once(manager, old_tile, new_tile, 'manager list tile')
Path(manager_path).write_text(manager)


def append_arb_message(path: str, key: str, value: str):
    p = Path(path)
    text = p.read_text()
    if f'"{key}"' in text:
        return
    stripped = text.rstrip()
    if not stripped.endswith('}'):
        raise SystemExit(f'{path}: invalid ARB ending')
    body = stripped[:-1].rstrip()
    if not body.endswith(','):
        body += ','
    body += f'\n  "{key}": "{value}"\n}}\n'
    p.write_text(body)


messages = {
    'brushSettingsPressureHardnessLabel': ('筆圧硬度', 'Pressure hardness'),
    'customAutomationRunAction': ('実行', 'Run'),
    'customAutomationFavoriteAction': ('お気に入りに追加', 'Add to favorites'),
    'customAutomationUnfavoriteAction': ('お気に入りを解除', 'Remove from favorites'),
}
for key, (ja, en) in messages.items():
    append_arb_message('lib/l10n/app_ja.arb', key, ja)
    append_arb_message('lib/l10n/app_en.arb', key, en)
