import 'package:flutter/material.dart';

/// [wholeSeconds]秒を「分:秒」（1時間以上は「時:分:秒」）で、言語の数字で書く。
String clockDurationLabel(MaterialLocalizations time, int wholeSeconds) => [
  if (wholeSeconds >= 3600) time.formatDecimal(wholeSeconds ~/ 3600),
  time.formatDecimal(wholeSeconds ~/ 60 % 60).padLeft(2, '0'),
  time.formatDecimal(wholeSeconds % 60).padLeft(2, '0'),
].join(':');
