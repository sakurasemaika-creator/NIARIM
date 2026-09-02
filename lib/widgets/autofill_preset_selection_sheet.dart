import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/autofill_preset.dart';
import '../config/font_fallback.dart';

/// プロジェクトごとに使用する自動塗りプリセットをチェックボックスで選べる
/// シート。自動塗りプリセットは使えば使うほど増えていくため、
/// プロジェクト内で使うものだけを選べるようにし、レイヤーへのパーツ割り当て
/// 時に大量スクロールしなくて済むようにする。新規プロジェクト作成時・
/// 既存プロジェクトの設定の両方から使う共通部品。
///
/// [allPresets]は選択肢となる全プリセット、[initiallyEnabledIds]は
/// 初期状態でチェック済みにするIDの集合（nullを渡すとすべてチェック済み
/// 扱いにする＝「すべて使用する」の初期状態）。
/// 戻り値はユーザーが確定したID一覧。全選択のまま確定した場合は
/// 「すべて使用する（今後追加されるプリセットも自動的に含む）」を表す
/// nullを返す。キャンセル時もnullを返すため、呼び出し側は
/// [wasCancelled]で判定する（キャンセルかどうかを区別したい場合に使用）。
Future<AutofillPresetSelectionResult> showAutofillPresetSelectionSheet(
  BuildContext context, {
  required List<AutofillPreset> allPresets,
  required Set<String>? initiallyEnabledIds,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final selected = Set<String>.from(
      initiallyEnabledIds ?? allPresets.map((p) => p.id));
  final result = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: SizedBox(
          height: 480,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.autofillPresetSelectionTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
                    ),
                    TextButton(
                      onPressed: () => setS(() => selected.addAll(allPresets.map((p) => p.id))),
                      child: Text(l10n.homeSelectionAllSelect),
                    ),
                    TextButton(
                      onPressed: () => setS(() => selected.clear()),
                      child: Text(l10n.homeSelectionAllDeselect),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.autofillPresetSelectionHint,
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: allPresets.isEmpty
                    ? Center(child: Text(l10n.autofillPresetEmpty))
                    // チェックを1つ付け外しするたびに全プリセットぶんの
                    // CheckboxListTileを作り直さないよう、行はbuilderで
                    // 遅延生成する。
                    : ListView.builder(
                        itemCount: allPresets.length,
                        itemBuilder: (context, i) {
                          final preset = allPresets[i];
                          return CheckboxListTile(
                              value: selected.contains(preset.id),
                              title: Text(preset.name),
                              subtitle: Text(l10n.autofillPresetSelectionPartCount(preset.parts.length)),
                              onChanged: (v) => setS(() {
                                if (v ?? false) {
                                  selected.add(preset.id);
                                } else {
                                  selected.remove(preset.id);
                                }
                              }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: Text(l10n.commonOk),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (result == null) return const AutofillPresetSelectionResult(cancelled: true, ids: null);
  final allIds = allPresets.map((p) => p.id).toSet();
  // 全選択のままなら「すべて使用する」を意味するnullとして保存する
  // （今後プリセットが増えた場合も自動的に対象へ含まれるようにするため）。
  if (result.length == allIds.length && result.containsAll(allIds)) {
    return const AutofillPresetSelectionResult(cancelled: false, ids: null);
  }
  return AutofillPresetSelectionResult(cancelled: false, ids: result.toList());
}

class AutofillPresetSelectionResult {
  final bool cancelled;
  final List<String>? ids;
  const AutofillPresetSelectionResult({required this.cancelled, required this.ids});
}
