import 'package:flutter/widgets.dart';

/// Materialのダイアログの最小の幅。
const double _minDialogWidth = 280;

/// ダイアログの左右の空きの既定（Material 3の`AlertDialog`）と、狭い画面で
/// 縮めるときの下限。
const double _usualHorizontalInset = 40;
const double _narrowestHorizontalInset = 16;

/// ダイアログの上下の空きの既定（Material 3の`AlertDialog`）。
const double _usualVerticalInset = 24;

/// 幅[width]の画面で、ダイアログがMaterialの最小の幅を取れるところまで
/// 縮めた左右の空き（16pxより狭くはしない。広い画面では既定の40px）。
double _horizontalInset(double width) => ((width - _minDialogWidth) / 2).clamp(
  _narrowestHorizontalInset,
  _usualHorizontalInset,
);

/// 打つ欄のあるダイアログ（保存のダイアログ等）の`insetPadding`。
///
/// 狭い画面では、左右の既定の空き（40px）を取るとダイアログがMaterialの
/// 最小の幅（280px）より狭くなり、大きな文字で題・ボタンの1つの語が1行に
/// 入らず、語の途中で折れた（320px・文字2倍の仏語で、保存のボタンが
/// 「Enregistre / r」、題が「…l’emplac / ement 1」）。最小の幅が取れるところ
/// まで左右の空きを縮める（16pxより狭くはしない）。最小の幅が取れる画面
/// （360px以上）の空きは今までどおり。
///
/// キーボードが開いている間は、上下に空きを取らない（文字の大きな小さい
/// 画面では、折り返して高くなったボタンの段と合わせて、打っている欄が
/// キーボードの上に入らなかった）。どちらも既定のままなら null（テーマの
/// 既定）。
EdgeInsets? typingDialogInsetPadding(BuildContext context) {
  final horizontal = _horizontalInset(MediaQuery.sizeOf(context).width);
  final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
  if (!keyboard && horizontal >= _usualHorizontalInset) return null;
  return EdgeInsets.symmetric(
    horizontal: horizontal,
    vertical: keyboard ? 0 : _usualVerticalInset,
  );
}

/// 打つ欄の無いダイアログ（確認のダイアログ等）の`insetPadding`。
///
/// [typingDialogInsetPadding]と同じく、狭い画面では最小の幅（280px）が取れる
/// ところまで左右の空きを縮める（320px・文字2倍の仏語で、キャンバスの
/// 「プロジェクト一覧へ戻る」の確認のボタンが「Enregistre / r et revenir」と
/// 語の途中で折れた）。上下の空きは既定のまま。最小の幅が取れる画面
/// （360px以上）では null（テーマの既定）。
EdgeInsets? dialogInsetPadding(BuildContext context) {
  final horizontal = _horizontalInset(MediaQuery.sizeOf(context).width);
  if (horizontal >= _usualHorizontalInset) return null;
  return EdgeInsets.symmetric(
    horizontal: horizontal,
    vertical: _usualVerticalInset,
  );
}
