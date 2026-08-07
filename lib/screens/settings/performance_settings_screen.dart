import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../widgets/responsive.dart';
import '../save_tree/save_tree_screen.dart';
import '../../widgets/help_button.dart';

class PerformanceSettingsScreen extends StatefulWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  State<PerformanceSettingsScreen> createState() =>
      _PerformanceSettingsScreenState();
}

class _PerformanceSettingsScreenState
    extends State<PerformanceSettingsScreen> {
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
    final slotReduced = newMode == SaveMode.slot &&
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

  /// カスタム保存方式変更：仕様書23に従い変更フローを経由する
  Future<void> _onCustomSaveModeChanged(
      BuildContext context, SaveMode newMode, PerformanceService perf) async {
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
      BuildContext context, int newCount, PerformanceService perf) async {
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

  /// 保存方式・保存可能数は端末全体の設定（仕様書09）だが、実際の保存データは
  /// プロジェクトごとに管理されている（仕様書23）。この画面はどのプロジェクトも
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
    if (!newIsTreeMode && newSlotMax != null) saveService.setSlotMax(newSlotMax);
  }

  @override
  Widget build(BuildContext context) {
    final perf = context.watch<PerformanceService>();

    return Scaffold(
      appBar: AppBar(title: const Text('パフォーマンス設定'), actions: const [HelpButton()]),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('品質設定',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...QualityLevel.values.map((level) => RadioListTile<QualityLevel>(
                title: Text(_qualityLabel(level)),
                subtitle: Text(_qualityDesc(level),
                    style: const TextStyle(fontSize: 12)),
                value: level,
                groupValue: perf.qualityLevel,
                onChanged: (v) {
                  if (v != null) _onQualityChanged(v);
                },
              )),
          const Divider(height: 32),
          const Text('現在の設定',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _infoTile('傾き検知', perf.tiltEnabled ? 'ON' : 'OFF'),
          _infoTile('オニオンスキン（前）',
              perf.showPrevOnion ? '${perf.prevOnionSkinFrames}枚' : 'OFF'),
          _infoTile('オニオンスキン（後）',
              perf.showNextOnion ? '${perf.nextOnionSkinFrames}枚' : 'OFF'),
          _infoTile('保存方式', _saveModeLabel(perf.saveMode)),
          if (perf.saveMode == SaveMode.slot)
            _infoTile('スロット数', '${perf.slotCount}件'),
          if (perf.qualityLevel == QualityLevel.custom) ...[
            const Divider(height: 32),
            // カスタム操作ボタン行
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('初期値に戻す', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showResetDialog(context, perf),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('現在のプリセットをコピー', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showCopyPresetDialog(context, perf),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('ペンの傾きをブラシに反映'),
              value: perf.tiltEnabled,
              onChanged: (v) => perf.setCustomTilt(v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('前フレームを表示'),
              value: perf.showPrevOnion,
              onChanged: (v) => perf.setCustomShowPrev(v),
              dense: true,
            ),
            if (perf.showPrevOnion) ...[
              const Text('オニオンスキン枚数（前）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _onionSlider(
                value: perf.prevOnionSkinFrames,
                onChanged: (v) => perf.setCustomOnionSkinPrev(v),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('後フレームを表示'),
              value: perf.showNextOnion,
              onChanged: (v) => perf.setCustomShowNext(v),
              dense: true,
            ),
            if (perf.showNextOnion) ...[
              const Text('オニオンスキン枚数（後）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _onionSlider(
                value: perf.nextOnionSkinFrames,
                onChanged: (v) => perf.setCustomOnionSkinNext(v),
              ),
            ],
            const SizedBox(height: 8),
            const Text('保存方式',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...SaveMode.values.map((mode) => RadioListTile<SaveMode>(
                  title: Text(_saveModeLabel(mode)),
                  value: mode,
                  groupValue: perf.saveMode,
                  onChanged: (v) {
                    if (v == null || v == perf.saveMode) return;
                    _onCustomSaveModeChanged(context, v, perf);
                  },
                  dense: true,
                )),
            if (perf.saveMode == SaveMode.slot) ...[
              const SizedBox(height: 8),
              const Text('スロット数',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _SlotCountSlider(
                value: perf.slotCount,
                onChangeEnd: (newCount) =>
                    _onCustomSlotCountChanged(context, newCount, perf),
              ),
            ],
          ],
        ],
      )),
    );
  }

  void _showResetDialog(BuildContext context, PerformanceService perf) {
    final defaultLabel = _qualityLabel(perf.defaultPreset);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カスタム品質設定を初期値に戻しますか？'),
        content: Text(
          '初期値は、初回起動時に端末性能から自動判定された「$defaultLabel」の設定になります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
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
              final slotReduced = newMode == SaveMode.slot &&
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
            child: const Text('戻す'),
          ),
        ],
      ),
    );
  }

  void _showCopyPresetDialog(BuildContext context, PerformanceService perf) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('コピーするプリセットを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('カスタム設定へコピーするプリセットを選択してください。'),
            const SizedBox(height: 16),
            ...[
              QualityLevel.low,
              QualityLevel.medium,
              QualityLevel.high,
            ].map((level) => ListTile(
                  dense: true,
                  title: Text(_qualityLabel(level)),
                  subtitle: Text(_copyPresetDesc(level),
                      style: const TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final saveService = context.read<SaveTreeService>();
                    final prevMode = perf.saveMode;
                    final prevSlot = perf.slotCount;
                    perf.copyPresetToCustom(level);
                    final newMode = perf.saveMode;
                    final newSlot = perf.slotCount;
                    final modeChanged = prevMode != newMode;
                    final slotReduced = newMode == SaveMode.slot &&
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
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }


  Widget _onionSlider(
      {required int value, required ValueChanged<int> onChanged}) {
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value.toDouble(),
            label: '$value枚',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
            width: 40,
            child: Text('$value枚', style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _qualityLabel(QualityLevel l) => switch (l) {
        QualityLevel.low => '低品質',
        QualityLevel.medium => '中品質',
        QualityLevel.high => '高品質',
        QualityLevel.custom => 'カスタム',
      };
  String _qualityDesc(QualityLevel l) => switch (l) {
        QualityLevel.low => '低スペック端末向け（オニオン前後1枚・スロット5件）',
        QualityLevel.medium => '中スペック端末向け（オニオン前後3枚・スロット10件）',
        QualityLevel.high => '高スペック端末向け（オニオン前後5枚・ツリー方式）',
        QualityLevel.custom => '各項目を個別設定',
      };
  String _copyPresetDesc(QualityLevel l) => switch (l) {
        QualityLevel.low => '前後1枚表示・軽量動作',
        QualityLevel.medium => '前後3枚表示・標準',
        QualityLevel.high => '前後5枚表示・高品質',
        QualityLevel.custom => '',
      };
  String _saveModeLabel(SaveMode m) => switch (m) {
        SaveMode.slot => 'スロット方式',
        SaveMode.tree => 'ツリー方式',
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
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            min: 1,
            max: 20,
            divisions: 19,
            value: _draft,
            label: '${_draft.round()}件',
            onChanged: (v) => setState(() => _draft = v),
            onChangeEnd: (v) => widget.onChangeEnd(v.round()),
          ),
        ),
        SizedBox(
            width: 40,
            child: Text('${_draft.round()}件',
                style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}


