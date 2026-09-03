import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/responsive.dart';
import '../../widgets/stepped_slider.dart';
import '../save_tree/save_tree_screen.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

class PerformanceSettingsScreen extends StatefulWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  State<PerformanceSettingsScreen> createState() =>
      _PerformanceSettingsScreenState();
}

class _PerformanceSettingsScreenState extends State<PerformanceSettingsScreen> {
  /// 品質変更：PerformanceServiceを更新してからSaveTreeServiceを同期する
  /// プリセット間変更で保存方式が変わる場合は変更フローを経由する
  Future<void> _onQualityChanged(QualityLevel level) async {
    final perf = context.read<PerformanceService>();
    final saveService = context.read<SaveTreeService>();
    final prevMode = perf.saveMode;
    final prevSlot = perf.slotCount;
    perf.setQualityLevel(level);
    final newMode = perf.saveMode;
    final newSlot = perf.slotCount;
    final modeChanged = prevMode != newMode;
    final slotReduced =
        newMode == SaveMode.slot &&
        prevMode == SaveMode.slot &&
        newSlot < prevSlot;
    if (modeChanged || slotReduced) {
      if (!context.mounted) return;
      await _applyToAllProjects(
        context: context,
        saveService: saveService,
        newIsTreeMode: newMode == SaveMode.tree,
        newSlotMax: newMode == SaveMode.slot ? newSlot : null,
      );
    } else {
      saveService.setTreeMode(newMode == SaveMode.tree);
      if (newMode == SaveMode.slot) saveService.setSlotMax(newSlot);
    }
  }

  /// カスタム保存方式変更：変更フローを経由する
  Future<void> _onCustomSaveModeChanged(
    BuildContext context,
    SaveMode newMode,
    PerformanceService perf,
  ) async {
    final saveService = context.read<SaveTreeService>();
    final newIsTree = newMode == SaveMode.tree;
    final newSlotMax = newIsTree ? null : perf.slotCount;
    await _applyToAllProjects(
      context: context,
      saveService: saveService,
      newIsTreeMode: newIsTree,
      newSlotMax: newSlotMax,
    );
    if (!context.mounted) return;
    perf.setCustomSaveMode(newMode);
  }

  /// カスタムスロット数変更：削減時は変更フローを経由する
  Future<void> _onCustomSlotCountChanged(
    BuildContext context,
    int newCount,
    PerformanceService perf,
  ) async {
    final saveService = context.read<SaveTreeService>();
    await _applyToAllProjects(
      context: context,
      saveService: saveService,
      newIsTreeMode: false,
      newSlotMax: newCount,
    );
    if (!context.mounted) return;
    perf.setCustomSlotCount(newCount);
  }

  /// 保存方式・保存可能数は端末全体の設定だが、実際の保存データは
  /// プロジェクトごとに管理されている。この画面はどのプロジェクトも
  /// 開いていない文脈で呼ばれるため、保存データを持つ全プロジェクトを1件ずつ
  /// チェックし、新しい上限を超えるものがあれば変更画面（保持するデータの選択・
  /// アーカイブ/完全削除）を順番に経由する。超えないプロジェクトは即時反映される。
  Future<void> _applyToAllProjects({
    required BuildContext context,
    required SaveTreeService saveService,
    required bool newIsTreeMode,
    int? newSlotMax,
  }) async {
    final projects = context.read<ProjectService>().projects;
    for (final project in projects) {
      if (!context.mounted) return;
      await showSaveModeChangeFlowIfNeeded(
        context: context,
        projectId: project.id,
        saveService: saveService,
        newIsTreeMode: newIsTreeMode,
        newSlotMax: newSlotMax,
        projectName: project.name,
      );
    }
    // プロジェクトが1件もない場合、上のループ内では誰もsetTreeMode/setSlotMaxを
    // 呼ばないため、ここで明示的に反映する（既にどれかのプロジェクトで
    // 反映済みの場合は冪等なので害はない）。
    saveService.setTreeMode(newIsTreeMode);
    if (!newIsTreeMode && newSlotMax != null)
      saveService.setSlotMax(newSlotMax);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final perf = context.watch<PerformanceService>();
    final settings = context.watch<SettingsService>();

    return Scaffold(
      // HelpButtonのtopicはヘルプ画面側のトピックキーと一致させる必要があるため、
      // 翻訳対象外の内部識別子として日本語のまま維持する。
      appBar: AppBar(
        title: Text(l10n.perfSettingsScreenTitle),
        actions: const [HelpButton(topic: 'パフォーマンス設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.perfSettingsQualitySection,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
            // 選択状態と変更通知はRadioGroupがまとめて持つ
            // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
            // spreadのままだとRadioGroupを祖先に置けないため、Columnで束ねる
            // （ListViewの子としての並び方は spread と同じ）。
            RadioGroup<QualityLevel>(
              groupValue: perf.qualityLevel,
              onChanged: (v) {
                if (v != null) _onQualityChanged(v);
              },
              child: Column(
                children: QualityLevel.values
                    .map(
                      (level) => RadioListTile<QualityLevel>(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_qualityLabel(l10n, level)),
                            // この端末の性能から判定した推奨プリセット（初回起動時に
                            // 自動選択されたもの）を、後から手動で変更していても
                            // 常にわかるようにする。
                            if (level == perf.defaultPreset) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n.premiumPlanRecommendedBadge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Kuramubon',
                                    fontFamilyFallback: kHeadingFontFallback,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          _qualityDesc(l10n, level),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: level,
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 32),
            // アプリの容量・重さに影響する設定（旧・設定画面「詳細」カテゴリから
            // 移設。品質プリセットとは独立して常に変更可能）。
            Text(
              l10n.perfSettingsCapacitySection,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  ListTile(
                    title: Text(l10n.perfSettingsUndoLimitTitle),
                    subtitle: Text(l10n.perfSettingsUndoLimitSubtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.perfSettingsUndoLimitValue(settings.undoLimit),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showUndoLimitDialog(context, settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.perfSettingsTrashAutoDeleteTitle),
                    subtitle: Text(l10n.perfSettingsTrashAutoDeleteSubtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.trashAutoDeleteDays == 0
                              ? l10n.commonOff
                              : l10n.perfSettingsTrashAutoDeleteValue(
                                  settings.trashAutoDeleteDays,
                                ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showTrashAutoDeleteDialog(context, settings),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Text(
              l10n.perfSettingsCurrentSettingsSection,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
            _infoTile(
              l10n.perfSettingsTiltLabel,
              perf.tiltEnabled ? 'ON' : l10n.commonOff,
            ),
            _infoTile(
              l10n.perfSettingsOnionPrevLabel,
              perf.showPrevOnion
                  ? l10n.perfSettingsOnionFrameCountValue(
                      perf.prevOnionSkinFrames,
                    )
                  : l10n.commonOff,
            ),
            _infoTile(
              l10n.perfSettingsOnionNextLabel,
              perf.showNextOnion
                  ? l10n.perfSettingsOnionFrameCountValue(
                      perf.nextOnionSkinFrames,
                    )
                  : l10n.commonOff,
            ),
            _infoTile(
              l10n.perfSettingsSaveModeLabel,
              _saveModeLabel(l10n, perf.saveMode),
            ),
            if (perf.saveMode == SaveMode.slot)
              _infoTile(
                l10n.perfSettingsSlotCountLabel,
                l10n.perfSettingsSlotCountValue(perf.slotCount),
              ),
            if (perf.qualityLevel == QualityLevel.custom) ...[
              const Divider(height: 32),
              // カスタム操作ボタン行
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: Text(
                        l10n.perfSettingsResetButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showResetDialog(context, perf),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(
                        l10n.perfSettingsCopyPresetButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showCopyPresetDialog(context, perf),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: Text(l10n.perfSettingsTiltSwitchTitle),
                value: perf.tiltEnabled,
                onChanged: (v) => perf.setCustomTilt(v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.perfSettingsShowPrevOnionTitle),
                value: perf.showPrevOnion,
                onChanged: (v) => perf.setCustomShowPrev(v),
                dense: true,
              ),
              if (perf.showPrevOnion) ...[
                Text(
                  l10n.perfSettingsOnionCountPrevLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                _onionSlider(
                  l10n: l10n,
                  value: perf.prevOnionSkinFrames,
                  onChanged: (v) => perf.setCustomOnionSkinPrev(v),
                ),
              ],
              const SizedBox(height: 4),
              SwitchListTile(
                title: Text(l10n.perfSettingsShowNextOnionTitle),
                value: perf.showNextOnion,
                onChanged: (v) => perf.setCustomShowNext(v),
                dense: true,
              ),
              if (perf.showNextOnion) ...[
                Text(
                  l10n.perfSettingsOnionCountNextLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                _onionSlider(
                  l10n: l10n,
                  value: perf.nextOnionSkinFrames,
                  onChanged: (v) => perf.setCustomOnionSkinNext(v),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.perfSettingsSaveModeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              // 選択状態と変更通知はRadioGroupがまとめて持つ
              // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
              RadioGroup<SaveMode>(
                groupValue: perf.saveMode,
                onChanged: (v) {
                  if (v == null || v == perf.saveMode) return;
                  _onCustomSaveModeChanged(context, v, perf);
                },
                child: Column(
                  children: SaveMode.values
                      .map(
                        (mode) => RadioListTile<SaveMode>(
                          title: Text(_saveModeLabel(l10n, mode)),
                          value: mode,
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (perf.saveMode == SaveMode.slot) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.perfSettingsSlotCountLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                _SlotCountSlider(
                  value: perf.slotCount,
                  onChangeEnd: (newCount) =>
                      _onCustomSlotCountChanged(context, newCount, perf),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showUndoLimitDialog(BuildContext context, SettingsService settings) {
    final l10n = AppLocalizations.of(context)!;
    const options = [10, 20, 30, 50, 100, 200];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.perfSettingsUndoLimitTitle),
        // 選択状態と変更通知はRadioGroupがまとめて持つ
        // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
        content: RadioGroup<int>(
          groupValue: settings.undoLimit,
          onChanged: (v) {
            if (v == null) return;
            settings.setUndoLimit(v);
            context.read<UndoManager>().setMaxUndoCount(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (n) => RadioListTile<int>(
                    title: Text(l10n.perfSettingsUndoLimitValue(n)),
                    value: n,
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  void _showTrashAutoDeleteDialog(
    BuildContext context,
    SettingsService settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final options = {
      0: l10n.commonOff,
      30: l10n.perfSettingsTrashAutoDeleteValue(30),
      60: l10n.perfSettingsTrashAutoDeleteValue(60),
      90: l10n.perfSettingsTrashAutoDeleteValue(90),
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.perfSettingsTrashAutoDeleteTitle),
        // 選択状態と変更通知はRadioGroupがまとめて持つ
        // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
        content: RadioGroup<int>(
          groupValue: settings.trashAutoDeleteDays,
          onChanged: (v) {
            if (v == null) return;
            settings.setTrashAutoDelete(v);
            context.read<ProjectService>().sweepExpiredTrash(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.entries
                .map(
                  (e) => RadioListTile<int>(title: Text(e.value), value: e.key),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, PerformanceService perf) {
    final l10n = AppLocalizations.of(context)!;
    final defaultLabel = _qualityLabel(l10n, perf.defaultPreset);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.perfSettingsResetDialogTitle),
        content: Text(l10n.perfSettingsResetDialogBody(defaultLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final saveService = context.read<SaveTreeService>();
              final prevMode = perf.saveMode;
              final prevSlot = perf.slotCount;
              perf.resetCustomToDefault();
              final newMode = perf.saveMode;
              final newSlot = perf.slotCount;
              // 保存方式・スロット数が変わる場合は変更フローを経由
              final modeChanged = prevMode != newMode;
              final slotReduced =
                  newMode == SaveMode.slot &&
                  prevMode == SaveMode.slot &&
                  newSlot < prevSlot;
              if (modeChanged || slotReduced) {
                if (!context.mounted) return;
                await showSaveModeChangeFlowIfNeeded(
                  context: context,
                  projectId: '',
                  saveService: saveService,
                  newIsTreeMode: newMode == SaveMode.tree,
                  newSlotMax: newMode == SaveMode.slot ? newSlot : null,
                );
              } else {
                saveService.setTreeMode(newMode == SaveMode.tree);
                if (newMode == SaveMode.slot) saveService.setSlotMax(newSlot);
              }
            },
            child: Text(l10n.perfSettingsResetConfirmButton),
          ),
        ],
      ),
    );
  }

  void _showCopyPresetDialog(BuildContext context, PerformanceService perf) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.perfSettingsCopyPresetDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.perfSettingsCopyPresetDialogBody),
            const SizedBox(height: 16),
            ...[QualityLevel.low, QualityLevel.medium, QualityLevel.high].map(
              (level) => ListTile(
                dense: true,
                title: Text(_qualityLabel(l10n, level)),
                subtitle: Text(
                  _copyPresetDesc(l10n, level),
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final saveService = context.read<SaveTreeService>();
                  final prevMode = perf.saveMode;
                  final prevSlot = perf.slotCount;
                  perf.copyPresetToCustom(level);
                  final newMode = perf.saveMode;
                  final newSlot = perf.slotCount;
                  final modeChanged = prevMode != newMode;
                  final slotReduced =
                      newMode == SaveMode.slot &&
                      prevMode == SaveMode.slot &&
                      newSlot < prevSlot;
                  if (modeChanged || slotReduced) {
                    if (!context.mounted) return;
                    await showSaveModeChangeFlowIfNeeded(
                      context: context,
                      projectId: '',
                      saveService: saveService,
                      newIsTreeMode: newMode == SaveMode.tree,
                      newSlotMax: newMode == SaveMode.slot ? newSlot : null,
                    );
                  } else {
                    saveService.setTreeMode(newMode == SaveMode.tree);
                    if (newMode == SaveMode.slot)
                      saveService.setSlotMax(newSlot);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _onionSlider({
    required AppLocalizations l10n,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: SteppedSlider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value.toDouble(),
            label: l10n.perfSettingsOnionFrameCountValue(value),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: l10n.perfSettingsOnionFrameCountValue(value),
            style: const TextStyle(fontSize: 12),
            value: value,
            min: 1,
            max: 10,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _qualityLabel(AppLocalizations l10n, QualityLevel l) => switch (l) {
    QualityLevel.low => l10n.perfSettingsQualityLow,
    QualityLevel.medium => l10n.perfSettingsQualityMedium,
    QualityLevel.high => l10n.perfSettingsQualityHigh,
    QualityLevel.custom => l10n.perfSettingsQualityCustom,
  };
  String _qualityDesc(AppLocalizations l10n, QualityLevel l) => switch (l) {
    QualityLevel.low => l10n.perfSettingsQualityDescLow,
    QualityLevel.medium => l10n.perfSettingsQualityDescMedium,
    QualityLevel.high => l10n.perfSettingsQualityDescHigh,
    QualityLevel.custom => l10n.perfSettingsQualityDescCustom,
  };
  String _copyPresetDesc(AppLocalizations l10n, QualityLevel l) => switch (l) {
    QualityLevel.low => l10n.perfSettingsCopyDescLow,
    QualityLevel.medium => l10n.perfSettingsCopyDescMedium,
    QualityLevel.high => l10n.perfSettingsCopyDescHigh,
    QualityLevel.custom => '',
  };
  String _saveModeLabel(AppLocalizations l10n, SaveMode m) => switch (m) {
    SaveMode.slot => l10n.perfSettingsSaveModeSlot,
    SaveMode.tree => l10n.perfSettingsSaveModeTree,
  };
}

/// スロット数スライダー：ドラッグ中はプレビュー表示のみ、指を離した時点で変更フローを起動
class _SlotCountSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChangeEnd;

  const _SlotCountSlider({required this.value, required this.onChangeEnd});

  @override
  State<_SlotCountSlider> createState() => _SlotCountSliderState();
}

class _SlotCountSliderState extends State<_SlotCountSlider> {
  late double _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.value.toDouble();
  }

  @override
  void didUpdateWidget(_SlotCountSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _draft = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: SteppedSlider(
            min: 1,
            max: 20,
            divisions: 19,
            value: _draft,
            label: l10n.perfSettingsSlotCountValue(_draft.round()),
            onChanged: (v) => setState(() => _draft = v),
            onChangeEnd: (v) => widget.onChangeEnd(v.round()),
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: l10n.perfSettingsSlotCountValue(_draft.round()),
            style: const TextStyle(fontSize: 12),
            value: _draft.round(),
            min: 1,
            max: 20,
            onChanged: (v) {
              setState(() => _draft = v.toDouble());
              widget.onChangeEnd(v.round());
            },
          ),
        ),
      ],
    );
  }
}
