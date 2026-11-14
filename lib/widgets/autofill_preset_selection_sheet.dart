import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/autofill_preset.dart';
import '../config/font_fallback.dart';
import 'action_beside_or_below.dart';
import 'first_that_fits.dart';
import 'list_ink_clip.dart';

/// パーツ割り当てUIに表示するプリセットを、プロジェクトの選択状態で絞り込む。
/// nullは「現在および今後の全プリセット」を意味する。
List<AutofillPreset> enabledAutofillPresets(
  List<AutofillPreset> allPresets,
  List<String>? enabledIds,
) {
  if (enabledIds == null) return allPresets;
  final ids = enabledIds.toSet();
  return allPresets.where((preset) => ids.contains(preset.id)).toList();
}

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
    initiallyEnabledIds ?? allPresets.map((p) => p.id),
  );
  final result = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        void selectAll() =>
            setS(() => selected.addAll(allPresets.map((p) => p.id)));
        void deselectAll() => setS(selected.clear);
        return SafeArea(
          child: SizedBox(
            // 文字が大きければ広げ、画面の9割まで（OKの上の残りの高さで、
            // 見出し・説明・一覧をスクロールする）。
            height: math.min(
              MediaQuery.sizeOf(ctx).height * 0.9,
              MediaQuery.textScalerOf(ctx).scale(480),
            ),
            child: Column(
              children: [
                // 見出し・説明・一覧を1つにスクロールする（横向きのスマホ・大きな
                // 文字で見出しと説明だけで高さを使い切っても、一覧へ届く）。
                // OKは下に残す。
                // 行を押したときの色はスクロールの中に限る（シートの面へ描くと、
                // 半分隠れた行の色がシートの上の縁・下のOKボタンへはみ出す）。
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            16,
                            8,
                            4,
                          ),
                          // 題は1行を使い、入らなければ「すべて選択」「すべて解除」を
                          // 題の下へ回す。2つのボタンは文字が入らなければアイコン
                          // （名前は吹き出しと読み上げ）。
                          child: ActionBesideOrBelow(
                            text: Text(
                              l10n.autofillPresetSelectionTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                              ),
                            ),
                            action: FirstThatFits(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: selectAll,
                                      child: Text(l10n.homeSelectionAllSelect),
                                    ),
                                    TextButton(
                                      onPressed: deselectAll,
                                      child: Text(
                                        l10n.homeSelectionAllDeselect,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: selectAll,
                                      icon: const Icon(Icons.select_all),
                                      tooltip: l10n.homeSelectionAllSelect,
                                    ),
                                    IconButton(
                                      onPressed: deselectAll,
                                      icon: const Icon(Icons.deselect),
                                      tooltip: l10n.homeSelectionAllDeselect,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.autofillPresetSelectionHint,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      if (allPresets.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text(l10n.autofillPresetEmpty)),
                        )
                      else
                        // チェックを1つ付け外しするたびに全プリセットぶんの
                        // CheckboxListTileを作り直さないよう、行はbuilderで
                        // 遅延生成する。
                        SliverList.builder(
                          itemCount: allPresets.length,
                          itemBuilder: (context, i) {
                            final preset = allPresets[i];
                            return CheckboxListTile(
                              value: selected.contains(preset.id),
                              title: Text(preset.name),
                              subtitle: Text(
                                l10n.autofillPresetSelectionPartCount(
                                  preset.parts.length,
                                ),
                              ),
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
                    ],
                  ).clipListInk(),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(l10n.commonOk),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (result == null) {
    return const AutofillPresetSelectionResult(cancelled: true, ids: null);
  }
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
  const AutofillPresetSelectionResult({
    required this.cancelled,
    required this.ids,
  });
}
