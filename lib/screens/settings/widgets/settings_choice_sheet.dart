import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/scrollable_sheet_body.dart';

/// 設定の値を選択肢から1つ選ぶシート。上に何を選んでいるかの題を出す
/// （題が無いと、どの操作の割り当てを変えているのかシートの中から分からな
/// かった）。選ぶとその値を返して閉じ、外を押す・戻るとnullを返す。
Future<T?> showSettingsChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T current,
  required String Function(BuildContext context, T option) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => ScrollableSheetBody(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: messageText(
                  title,
                  keepLineStarts: true,
                  style: settingsSheetTitleStyle(ctx),
                ),
              ),
            ),
            // 選択状態と変更通知はRadioGroupがまとめて持つ
            // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
            RadioGroup<T>(
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    RadioListTile<T>(
                      title: Text(labelOf(ctx, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 設定のシートの題の書式（基本設定・選択肢のシートで同じ）。
TextStyle settingsSheetTitleStyle(BuildContext context) =>
    localizedHeadingStyle(
      context,
      const TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.bold),
    );
