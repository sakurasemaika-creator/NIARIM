/// アプリ内の初回吹き出し（`FirstUseTooltip`）のキー一覧。
///
/// 吹き出しが出ている間は画面全体に透明バリアが敷かれ、直後の操作が
/// そこへ吸われてしまう（タップしたのに何も起きない形の失敗になる）。
/// 吹き出しそのものを検証しないテストでは、
/// `SharedPreferences.setMockInitialValues({firstUseTooltipsSeenKey:
/// kAllFirstUseTooltipKeys})`で全て表示済みにしておくこと。
///
/// 実際のキーと食い違わないことは`first_use_tooltip_keys_test.dart`が
/// lib配下を走査して検証している。
const String firstUseTooltipsSeenKey = 'first_use_tooltips_seen';

const List<String> kAllFirstUseTooltipKeys = <String>[
  'autofill_mark',
  'bucket_tool',
  'pen_subtool_stamp',
  'pen_subtool_tone',
  'pen_tool',
  'quick_tool',
  'ruler_tool',
  'text_tool',
  'timeline_preview_fullscreen',
];
