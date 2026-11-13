import 'dart:ui' show Locale;

import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// 複製した作品の名前。複製先のフォルダに同じ名前の複製が既にあれば番号を
/// 付ける（「作品1 (コピー)」「作品1 (コピー 2)」…）。番号が無いと、同じ
/// 作品を2回貼り付けたとき同じ名前の作品が並び、見分けられなかった。
/// 「共有」から取り込んだ作品はホームのフォルダに並ばないので数えない。
String duplicateProjectName(
  AppLocalizations l10n,
  String name, {
  required String? folderId,
  required Iterable<Project> projects,
}) {
  return numberedCopyName(l10n, name, {
    for (final p in projects)
      if (p.folderId == folderId && !p.isSharedImport) p.name,
  });
}

/// 複製したフォルダの名前。複製先に同じ名前のフォルダが既にあれば番号を
/// 付ける（作品の複製と同じ「(コピー)」「(コピー 2)」…）。
String duplicateFolderName(
  AppLocalizations l10n,
  String name, {
  required String? parentId,
  required Iterable<ProjectFolder> folders,
}) {
  return numberedCopyName(l10n, name, {
    for (final f in folders)
      if (f.parentFolderId == parentId) f.name,
  });
}

/// 複製の名前（「名前 (コピー)」）。[taken]に同じ名前があれば
/// 「名前 (コピー 2)」…と番号を付ける。
///
/// 複製の複製も元の名前の複製にする：[name]が複製の名前（どの言語の形でも、
/// 以前の版の形でも。[copySourceName]）なら、印を1つ外した元の名前に、
/// [taken]の中で空いている一番小さい番号を付ける（「Gペン (コピー)」の複製は
/// 「Gペン (コピー 2)」。「Gペン (コピー) (コピー)」と重ねない）。作品・
/// フォルダ・ブラシ・トーン・スタンプ・テーマ・サイズ・自動塗りの複製も、
/// 設定の引き継ぎで足す複製も、この決まりで名前を付ける。
/// - 外す印は1つだけ。以前の版で重なった「Gペン (コピー) (コピー)」は
///   「Gペン (コピー)」の複製として「Gペン (コピー) (コピー 2)」にする
///   （引き継ぎが同じ物の名前と見なす範囲と同じ）。
/// - 印だけの名前（「(コピー)」）は、元の名前が無いので複製の名前と見なさない
///   （複製は「(コピー) (コピー)」）。
/// - ほかの言語の印（日本語の画面の「Pen (copy)」）も複製の印として外す
///   （表示の言語を変える前に作った複製と見分けられないため。複製は
///   「Pen (コピー 2)」）。
/// - 番号の付いた印の形の名前（「Sketch (copy 2019)」）も複製の名前として
///   印を外す。利用者がそう名付けたのか複製で付いた番号なのかは名前から
///   見分けられず、元の名前を消した後の複製（「Gペン (コピー 3)」だけが
///   残っている）と同じに扱うため。複製は「Sketch (copy)」で、名前の中の
///   番号は残らない（引き継ぎで足す複製も同じ）。
///
/// [taken]の中の、どの言語の形・以前の版の形の元の名前の複製も、その番号を
/// 使っているものとして数える（以前の版で英語の「Pen (Copy)」を作った人が
/// 複製すると、見分けにくい「Pen (copy)」ではなく「Pen (copy 2)」になる）。
String numberedCopyName(AppLocalizations l10n, String name, Set<String> taken) {
  final source = copySourceName(name) ?? name;
  final used = {
    for (final other in taken)
      for (final reading in _copyReadings(other))
        if (reading.name == source) reading.number,
  };
  for (var number = 1; ; number++) {
    if (used.contains(number)) continue;
    final copy = number == 1
        ? l10n.projectDuplicateName(source)
        : l10n.projectDuplicateNameNumbered(source, number);
    if (!taken.contains(copy)) return copy;
  }
}

/// 画面の言語を受け取らない所（サービスの既定の名前）で付ける複製の名前。
/// 決まりは[numberedCopyName]と同じで、日本語の形（「名前 (コピー)」）。
String fallbackCopyName(String name, Iterable<String> taken) =>
    numberedCopyName(_japanese, name, taken.toSet());

final AppLocalizations _japanese = lookupAppLocalizations(const Locale('ja'));

/// [candidate]が複製の名前なら、複製元の名前（どの言語の形でも、以前の版の
/// 形でも）。
String? copySourceName(String candidate) =>
    _copyReadings(candidate).firstOrNull?.name;

/// [candidate]を複製の名前として読んだときの、複製元の名前と番号（番号の
/// 無い形は1。複製の名前でなければnull）。
({String name, int number})? copyNameParts(String candidate) =>
    _copyReadings(candidate).firstOrNull;

/// [candidate]が複製の名前なら、複製元の名前と、その後ろに付いた複製の印
/// （「 (コピー 2)」）。複製の名前でなければnull。名前を縮めて出すところで
/// 印だけは縮めずに出す（元の項目と見分けられるように）、名前の元を変えても
/// 印を残す、ために使う。
({String name, String mark})? copyNameMark(String candidate) {
  final parts = copyNameParts(candidate);
  if (parts == null || !candidate.startsWith(parts.name)) return null;
  return (name: parts.name, mark: candidate.substring(parts.name.length));
}

/// [name]の[number]番目の複製の名前を、画面の言語（[l10n]）で（1番目は
/// 番号を付けない）。保存した名前は別の言語の形でも、画面では今の言語で
/// 出すときに使う。
String copyNameIn(AppLocalizations l10n, String name, int number) => number <= 1
    ? l10n.projectDuplicateName(name)
    : l10n.projectDuplicateNameNumbered(name, number);

/// 複製の名前の形（「名前 (コピー)」「名前 (コピー 2)」）。[prefix]・名前・
/// [middle]・番号・[suffix]の順に並ぶ（番号の無い形は[middle]がnull）。
typedef _CopyForm = ({String prefix, String? middle, String suffix});

/// どの言語の、今と以前の版の複製の名前の形。
final List<_CopyForm> _copyForms = () {
  const name = '\u0000';
  const number = 7919;
  _CopyForm? plain(String text) {
    final at = text.indexOf(name);
    if (at < 0) return null;
    return (
      prefix: text.substring(0, at),
      middle: null,
      suffix: text.substring(at + name.length),
    );
  }

  _CopyForm? numbered(String text) {
    final at = text.indexOf(name);
    final digits = text.indexOf('$number');
    if (at < 0 || digits < at) return null;
    return (
      prefix: text.substring(0, at),
      middle: text.substring(at + name.length, digits),
      suffix: text.substring(digits + '$number'.length),
    );
  }

  final forms = <_CopyForm>{};
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    for (final form in [
      plain(l10n.projectDuplicateName(name)),
      numbered(l10n.projectDuplicateNameNumbered(name, number)),
      // 以前の版のテーマ・自動塗り・ブラシの「複製」が付けた名前。ブラシは
      // 「(Copy)」の閉じ括弧の前に番号を入れ、括弧で終わらない形は後ろに
      // 「 (2)」を付けていた。
      for (final old in [
        plain(l10n.themePresetDuplicateName(name)),
        plain(l10n.autofillPresetDuplicateName(name)),
      ])
        if (old != null) ...[
          old,
          old.suffix.endsWith(')')
              ? (
                  prefix: old.prefix,
                  middle: '${old.suffix.substring(0, old.suffix.length - 1)} ',
                  suffix: ')',
                )
              : (prefix: old.prefix, middle: '${old.suffix} (', suffix: ')'),
        ],
    ]) {
      if (form != null) forms.add(form);
    }
  }
  return List<_CopyForm>.unmodifiable(forms);
}();

/// [candidate]を複製の名前として読んだときの、複製元の名前と番号（番号の
/// 無い形は1）。読める形ごとに1つ。
Iterable<({String name, int number})> _copyReadings(String candidate) sync* {
  for (final form in _copyForms) {
    if (!candidate.startsWith(form.prefix) ||
        !candidate.endsWith(form.suffix)) {
      continue;
    }
    final inner = candidate.substring(
      form.prefix.length,
      candidate.length - form.suffix.length,
    );
    final middle = form.middle;
    if (middle == null) {
      if (inner.isNotEmpty) yield (name: inner, number: 1);
      continue;
    }
    var digits = inner.length;
    while (digits > 0 && _isDigit(inner.codeUnitAt(digits - 1))) {
      digits--;
    }
    if (digits == inner.length) continue;
    final head = inner.substring(0, digits);
    if (head.endsWith(middle) && head.length > middle.length) {
      yield (
        name: head.substring(0, head.length - middle.length),
        // 桁が多すぎて数にならない番号は、番号を付けるときに数えない。
        number: int.tryParse(inner.substring(digits)) ?? 0,
      );
    }
  }
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
