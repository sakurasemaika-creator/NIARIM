import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_file_trash_service.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/responsive.dart';
import '../save_tree/save_tree_screen.dart';
import '../../utils/line_break.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

class PerformanceSettingsScreen extends StatefulWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  State<PerformanceSettingsScreen> createState() =>
      _PerformanceSettingsScreenState();
}

class _PerformanceSettingsScreenState extends State<PerformanceSettingsScreen> {
  bool _changingTrashRetention = false;

  Future<void> _onQualityChanged(QualityLevel level) async {
    final perf = context.read<PerformanceService>();
    if (await _changeSaveSettings(
      context,
      perf.saveModeFor(level),
      perf.slotCountFor(level),
    )) {
      perf.setQualityLevel(level);
    }
  }

  Future<void> _onCustomSaveModeChanged(
    BuildContext context,
    SaveMode newMode,
    PerformanceService perf,
  ) async {
    if (await _changeSaveSettings(context, newMode, perf.slotCount)) {
      perf.setCustomSaveMode(newMode);
    }
  }

  Future<void> _onCustomSlotCountChanged(
    BuildContext context,
    int newCount,
    PerformanceService perf,
  ) async {
    if (await _changeSaveSettings(context, SaveMode.slot, newCount)) {
      perf.setCustomSlotCount(newCount);
    }
  }

  Future<bool> _changeSaveSettings(
    BuildContext context,
    SaveMode mode,
    int slotCount,
  ) => showSaveModeChangeFlows(
    context: context,
    projects: {
      for (final project in context.read<ProjectService>().projects)
        project.id: project.name,
    },
    saveService: context.read<SaveTreeService>(),
    newIsTreeMode: mode == SaveMode.tree,
    newSlotMax: mode == SaveMode.slot ? slotCount : null,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final perf = context.watch<PerformanceService>();
    final settings = context.watch<SettingsService>();

    return Scaffold(
      // HelpButtonのtopicはヘルプ画面側のトピックキーと一致させる必要があるため、
      // 翻訳対象外の内部識別子として日本語のまま維持する。
      appBar: AppBar(
        // 入らない幅では画面名を出さない（省略記号で切らない）。
        title: FitOrHideTitle(l10n.perfSettingsScreenTitle),
        actions: const [HelpButton(topic: 'パフォーマンス設定')],
      ),
      body: desktopCentered(
        context,
        LayoutBuilder(
          builder: (context, box) => ListView(
            // 見出しの1語が入らない幅（狭い幅・大きな文字・長い言語）では、
            // 左右の余白を詰めてでも語の途中で折らない（8pxまで）。
            padding: EdgeInsets.symmetric(
              vertical: 16,
              horizontal: _sideMargin(context, box.maxWidth, [
                l10n.perfSettingsQualitySection,
                l10n.perfSettingsCapacitySection,
                l10n.perfSettingsCurrentSettingsSection,
              ]),
            ),
            children: [
              Text(l10n.perfSettingsQualitySection, style: _sectionStyle),
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
                        (level) => _RadioRow<QualityLevel>(
                          value: level,
                          // 印は名前の後ろに並べ、入らなければ名前の下へ回す
                          // （名前・印とも語の途中で折らない）。
                          title: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _keepWords(_qualityLabel(l10n, level)),
                              // この端末の性能から判定した推奨プリセット（初回起動時に
                              // 自動選択されたもの）を、後から手動で変更していても
                              // 常にわかるようにする。
                              if (level == perf.defaultPreset)
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
                                    keepKoreanWordsTogether(
                                      l10n.premiumPlanRecommendedBadge,
                                    ),
                                    semanticsLabel:
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
                          ),
                          subtitle: Text(
                            _qualityDesc(l10n, level),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 32),
              // アプリの容量・重さに影響する設定（旧・設定画面「詳細」カテゴリから
              // 移設。品質プリセットとは独立して常に変更可能）。
              Text(l10n.perfSettingsCapacitySection, style: _sectionStyle),
              SizedBox(height: 8),
              Card(
                elevation: 1,
                shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                  alpha: 0.15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    _ValueTile(
                      title: l10n.perfSettingsUndoLimitTitle,
                      subtitle: l10n.perfSettingsUndoLimitSubtitle,
                      value: l10n.perfSettingsUndoLimitValue(
                        settings.undoLimit,
                      ),
                      onTap: () => _showUndoLimitDialog(context, settings),
                    ),
                    const Divider(height: 1),
                    _ValueTile(
                      title: l10n.perfSettingsTrashAutoDeleteTitle,
                      subtitle: l10n.perfSettingsTrashAutoDeleteSubtitle,
                      value: settings.trashAutoDeleteDays == 0
                          ? l10n.perfSettingsTrashAutoDeleteOff
                          : l10n.perfSettingsTrashAutoDeleteValue(
                              settings.trashAutoDeleteDays,
                            ),
                      onTap: () =>
                          _showTrashAutoDeleteDialog(context, settings),
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
                perf.tiltEnabled
                    ? l10n.perfSettingsTiltOn
                    : l10n.perfSettingsTiltOff,
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
                // 並べて入らなければ下の行へ回す（ボタンの名前を語の途中で
                // 折らない）。
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: _keepWords(
                        l10n.perfSettingsResetButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showResetDialog(context, perf),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: _keepWords(
                        l10n.perfSettingsCopyPresetButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showCopyPresetDialog(context, perf),
                    ),
                  ],
                ),
                _SwitchRow(
                  title: l10n.perfSettingsTiltSwitchTitle,
                  value: perf.tiltEnabled,
                  onChanged: (v) => perf.setCustomTilt(v),
                ),
                const SizedBox(height: 8),
                _SwitchRow(
                  title: l10n.perfSettingsShowPrevOnionTitle,
                  value: perf.showPrevOnion,
                  onChanged: (v) => perf.setCustomShowPrev(v),
                ),
                if (perf.showPrevOnion) ...[
                  _onionSlider(
                    l10n: l10n,
                    label: l10n.perfSettingsOnionCountPrevLabel,
                    value: perf.prevOnionSkinFrames,
                    onChanged: (v) => perf.setCustomOnionSkinPrev(v),
                  ),
                ],
                const SizedBox(height: 4),
                _SwitchRow(
                  title: l10n.perfSettingsShowNextOnionTitle,
                  value: perf.showNextOnion,
                  onChanged: (v) => perf.setCustomShowNext(v),
                ),
                if (perf.showNextOnion) ...[
                  _onionSlider(
                    l10n: l10n,
                    label: l10n.perfSettingsOnionCountNextLabel,
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
                          (mode) => _RadioRow<SaveMode>(
                            value: mode,
                            title: _keepWords(_saveModeLabel(l10n, mode)),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (perf.saveMode == SaveMode.slot) ...[
                  const SizedBox(height: 8),
                  _SlotCountSlider(
                    label: l10n.perfSettingsSlotCountLabel,
                    value: perf.slotCount,
                    onChangeEnd: (newCount) =>
                        _onCustomSlotCountChanged(context, newCount, perf),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 左右の余白：ふだんは16px。[headings]の1語が入らないときだけ、入るまで
  /// 詰める（8pxまで）。
  double _sideMargin(
    BuildContext context,
    double width,
    List<String> headings,
  ) {
    var widest = 0.0;
    for (final heading in headings) {
      for (final word in heading.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: DefaultTextStyle.of(context).style.merge(_sectionStyle),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
    }
    return ((width - widest) / 2).clamp(8.0, 16.0);
  }

  void _showUndoLimitDialog(BuildContext context, SettingsService settings) {
    final l10n = AppLocalizations.of(context)!;
    const options = [10, 20, 30, 50, 100, 200];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(l10n.perfSettingsUndoLimitTitle)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
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
      ),
    );
  }

  Future<void> _showTrashAutoDeleteDialog(
    BuildContext context,
    SettingsService settings,
  ) async {
    if (_changingTrashRetention) return;
    final l10n = AppLocalizations.of(context)!;
    final options = {
      0: l10n.perfSettingsTrashAutoDeleteOff,
      30: l10n.perfSettingsTrashAutoDeleteValue(30),
      60: l10n.perfSettingsTrashAutoDeleteValue(60),
      90: l10n.perfSettingsTrashAutoDeleteValue(90),
    };
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(l10n.perfSettingsTrashAutoDeleteTitle)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        // 選択状態と変更通知はRadioGroupがまとめて持つ
        // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
        content: RadioGroup<int>(
          groupValue: settings.trashAutoDeleteDays,
          onChanged: (value) {
            if (value != null) Navigator.pop(ctx, value);
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
      ),
    );
    if (!context.mounted ||
        days == null ||
        days == settings.trashAutoDeleteDays) {
      return;
    }
    _changingTrashRetention = true;
    try {
      if (days == 0) {
        await settings.setTrashAutoDelete(days);
        return;
      }
      await _applyTrashRetention(context, settings, days);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
    } finally {
      _changingTrashRetention = false;
    }
  }

  Future<void> _applyTrashRetention(
    BuildContext context,
    SettingsService settings,
    int days,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final messenger = ScaffoldMessenger.of(context);
    if (service.projectsLoadFailed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeProjectsLoadFailed)),
      );
      return;
    }
    final cutoff = DateTime.now().subtract(Duration(days: days));
    bool expires(DateTime? deleted) =>
        deleted != null && !deleted.isAfter(cutoff);
    final projects = [
      for (final project in service.trash)
        if (service.trashedFolderOf(project.id) == null &&
            expires(service.deletedAtOf(project.id)))
          project.id,
    ];
    final folders = [
      for (final folder in service.trashedFolders)
        if (expires(folder.deletedAt) &&
            !service.trashedFolderHasUnreadWorks(folder))
          folder,
    ];
    final files = (await LocalFileTrashService.list())
        .where((entry) => expires(entry.deletedAt))
        .toList();
    if (!context.mounted) return;
    final count = projects.length + folders.length + files.length;
    if (count > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(l10n.homePermanentDeleteConfirmTitle),
          content: Text(l10n.perfSettingsTrashApplyConfirm(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l10n.homePermanentDelete),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await settings.setTrashAutoDelete(days);
    if (count == 0) return;

    // Delete the reviewed entries only. Other entries may expire while the
    // confirmation is on screen and will be handled by the normal sweep.
    var failed = false;
    Future<void> remove(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stack) {
        failed = true;
        AppErrorReporter.record(error, stack);
      }
    }

    for (final projectId in projects) {
      await remove(() => service.permanentDelete(projectId));
    }
    for (final folder in folders) {
      await remove(
        () => service.permanentDeleteTrashedFolder(folder.folder.id),
      );
      if (service.trash.any(
        (project) => folder.projectIds.contains(project.id),
      )) {
        failed = true;
      }
    }
    for (final entry in files) {
      await remove(() async {
        if (!await LocalFileTrashService.deleteUnlessRestoring(entry)) {
          failed = true;
        }
      });
    }
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failed
                ? l10n.homeTrashOperationFailed
                : l10n.perfSettingsTrashApplied(count),
          ),
        ),
      );
    }
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
              final preset = perf.defaultPreset;
              if (await _changeSaveSettings(
                context,
                perf.saveModeFor(preset),
                perf.slotCountFor(preset),
              )) {
                perf.resetCustomToDefault();
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
                  if (await _changeSaveSettings(
                    context,
                    perf.saveModeFor(level),
                    perf.slotCountFor(level),
                  )) {
                    perf.copyPresetToCustom(level);
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
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return LabeledSlider(
      label: label,
      labelStyle: _sliderHeadingStyle,
      min: 1,
      max: 10,
      divisions: 9,
      value: value.toDouble(),
      sliderLabel: l10n.perfSettingsOnionFrameCountValue(value),
      valueText: l10n.perfSettingsOnionFrameCountValue(value),
      onChanged: (v) => onChanged(v.round()),
    );
  }

  /// 項目名と値。並べると項目名が語の途中で折れるときは、値を項目名の
  /// 下（行の終わりの側）へ回す。
  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ActionBesideOrBelow(
        minTextFraction: 0,
        spacing: 2,
        text: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        action: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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

/// 品質・容量の節の見出し。
const _sectionStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
);

/// スライダーの項目名（オニオンスキン枚数・スロット数）。他の小見出しと
/// 同じ太字の見出しフォント。
const _sliderHeadingStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
);

/// スロット数スライダー：ドラッグ中はプレビュー表示のみ、指を離した時点で変更フローを起動
class _SlotCountSlider extends StatefulWidget {
  final String label;
  final int value;
  final Future<void> Function(int) onChangeEnd;

  const _SlotCountSlider({
    required this.label,
    required this.value,
    required this.onChangeEnd,
  });

  @override
  State<_SlotCountSlider> createState() => _SlotCountSliderState();
}

class _SlotCountSliderState extends State<_SlotCountSlider> {
  late double _draft;
  bool _applying = false;

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

  Future<void> _apply(double value) async {
    if (_applying) return;
    final requested = value.round();
    if (requested == widget.value) return;
    setState(() => _applying = true);
    try {
      await widget.onChangeEnd(requested);
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
          _draft = widget.value.toDouble();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LabeledSlider(
      label: widget.label,
      labelStyle: _sliderHeadingStyle,
      min: 1,
      max: 20,
      divisions: 19,
      value: _draft,
      sliderLabel: l10n.perfSettingsSlotCountValue(_draft.round()),
      valueText: l10n.perfSettingsSlotCountValue(_draft.round()),
      onChanged: _applying ? null : (v) => setState(() => _draft = v),
      onChangeEnd: _apply,
    );
  }
}

/// 韓国語の語を途中で折らない文（見出しの書体の項目名・ボタン用。読み上げは
/// 元の文）。
Text _keepWords(String text, {TextStyle? style}) =>
    Text(keepKoreanWordsTogether(text), semanticsLabel: text, style: style);

/// 項目名・説明と今の値の行（押すと選ぶダイアログを開く）。値は右端に
/// 置き、並べると項目名・説明が語の途中で折れるときは説明の下へ回す。
class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileTheme = ListTileTheme.of(context);
    final titleStyle =
        tileTheme.titleTextStyle ??
        theme.listTileTheme.titleTextStyle ??
        theme.textTheme.bodyLarge;
    final subtitleStyle =
        tileTheme.subtitleTextStyle ??
        theme.listTileTheme.subtitleTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    // 押すと選ぶダイアログを開く行なので、読み上げではボタンとして伝える
    // （ListTileと同じ）。
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ActionBesideOrBelow(
              minTextFraction: 0,
              text: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keepKoreanWordsTogether(title),
                    semanticsLabel: title,
                    style: titleStyle,
                  ),
                  Text(subtitle, style: subtitleStyle),
                ],
              ),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: theme.textTheme.labelLarge),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 項目名とスイッチの行。並べると項目名が語の途中で折れるときは、スイッチを
/// 項目名の下（行の終わりの側）へ回す。行のどこを押しても切り替わる。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        ListTileTheme.of(context).titleTextStyle ??
        theme.listTileTheme.titleTextStyle ??
        theme.textTheme.bodyLarge;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ActionBesideOrBelow(
            minTextFraction: 0,
            text: Text(
              keepKoreanWordsTogether(title),
              semanticsLabel: title,
              style: titleStyle,
            ),
            // キーボードのTabは行（InkWell）に1か所だけ止まる
            // （SwitchListTileと同じ。スイッチにも止まると2か所になる）。
            action: ExcludeFocus(
              child: Switch(value: value, onChanged: onChanged),
            ),
          ),
        ),
      ),
    );
  }
}

/// 選択肢の行（[RadioGroup]の中に置く）。丸は名前の前に置き、並べると名前・
/// 説明が語の途中で折れるときは名前の上へ回す。行のどこを押しても選べる。
class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({required this.value, required this.title, this.subtitle});

  final T value;
  final Widget title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        ListTileTheme.of(context).titleTextStyle ??
        theme.listTileTheme.titleTextStyle ??
        theme.textTheme.bodyLarge;
    final subtitleStyle =
        ListTileTheme.of(context).subtitleTextStyle ??
        theme.listTileTheme.subtitleTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    return MergeSemantics(
      child: InkWell(
        // キーボードのフォーカスは丸（Radio）が受ける。丸はRadioGroupの
        // 一員なので、Tabはまとまりの選んだ丸に1か所だけ止まり、矢印で
        // 選び直せる（行も止まると選択肢ごとに止まり、矢印が効かない）。
        canRequestFocus: false,
        onTap: () => RadioGroup.maybeOf<T>(context)?.onChanged(value),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
          child: ActionBesideOrBelow(
            actionFirst: true,
            // 丸を名前の横に置くか上に置くかは、名前の文字12字分が残る幅か
            // だけで決め、選択肢のどの行もそろえる（行ごとの文で決めると、
            // 説明が折り返す行だけ丸が上へ回り、中国語では字の間の折り返しを
            // 語の途中と取り違えて全部の行で上へ回った）。
            minTextWidth:
                MediaQuery.textScalerOf(
                  context,
                ).scale(titleStyle?.fontSize ?? 16) *
                12,
            gap: 8,
            spacing: 0,
            text: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(style: titleStyle, child: title),
                if (subtitle != null)
                  DefaultTextStyle.merge(
                    style: subtitleStyle,
                    child: subtitle!,
                  ),
              ],
            ),
            action: Radio<T>(value: value),
          ),
        ),
      ),
    );
  }
}
