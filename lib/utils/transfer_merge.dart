import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/shortcut_binding.dart';
import 'app_error_reporter.dart';
import 'duplicate_name.dart';
import 'tolerant_preferences.dart';

/// お気に入り・タグ・フォルダ（項目の中身ではなく、利用者の整理）。
typedef TransferOrganization = ({
  bool favorite,
  List<String> tags,
  String? folderId,
});

/// 引き継ぎの読み込みで知らせること（読み込みの後に知らせる）。
class TransferImportReport {
  /// この端末の項目を残して別の名前で足した項目の名前。
  final List<String> addedCopies = [];

  /// もう1台のショートカットのうち、この端末で同じキーの組み合わせを別の
  /// 操作に使っているので足さなかったもの（1つのキーに2つの操作を付けない）。
  final List<ShortcutBinding> notAddedShortcuts = [];
}

/// 受け取った早替えツール・ショートカット・ワークスペースが使うブラシの
/// ID。ブラシを合わせたとき、そのブラシの中身を持つことになったこの端末の
/// ブラシ（[brushIds]は[mergeTransferredItems]の`placed`。同じ中身が既に
/// あって足さなかったならそのブラシ、この端末の版を残して足した複製なら
/// 複製）を指すようにする。
String? transferredBrushId(String? id, Map<String, String> brushIds) =>
    transferredItemId(id, brushIds);

/// 受け取った物が指している項目（ブラシ・トーン・自動塗りのプリセットと
/// パーツ・透かし・自動操作）のID。合わせた後でその項目の中身を持つこの
/// 端末の項目（[placed]は[mergeTransferredItems]の`placed`）を指すように
/// する。[placed]に無い（ファイルに無かった・足さなかった）IDはそのまま。
String? transferredItemId(String? id, Map<String, String> placed) =>
    id == null ? null : placed[id] ?? id;

/// 引き継ぎで足す複製の名前（「名前 (コピー)」「名前 (コピー 2)」…）。
///
/// 名前は画面の言語で付けるが、複製かどうかはどの言語の形でも見分ける
/// （日本語の画面で足した複製を英語の画面で読み直しても、同じ複製と分かる。
/// 端末保存データで言語が変わることもある）。以前の版のアプリの「複製」が
/// 付けた形（テーマ・自動塗り・ブラシの「(Copy)」「（사본）」と番号）も
/// 複製として見分ける（[copySourceName]）。
class TransferCopyNames {
  TransferCopyNames(this.l10n, {this.report});

  final AppLocalizations l10n;

  /// 足した複製の名前を書き留める先。
  final TransferImportReport? report;

  /// [taken]と重ならない[name]の複製の名前（足す複製に付ける。[report]へ
  /// 書き留める）。[name]が既に複製の名前なら、元の名前の次の番号にする
  /// （「Gペン (コピー)」の複製は「Gペン (コピー 2)」。「(コピー) (コピー)」と
  /// 重ねない。一覧の「複製」と同じ決まり：[numberedCopyName]）。
  String next(String name, Set<String> taken) {
    final copy = numberedCopyName(l10n, name, taken);
    report?.addedCopies.add(copy);
    return copy;
  }

  /// [candidate]が複製の名前なら、複製元の名前（どの言語の形でも）。
  static String? copiedFrom(String candidate) => copySourceName(candidate);

  /// 2つの名前が同じ物の名前か（同じ名前、片方がもう片方の複製、または
  /// どちらも同じ名前の複製）。
  static bool related(String a, String b) {
    if (a == b) return true;
    final fromA = copiedFrom(a);
    final fromB = copiedFrom(b);
    return fromA == b || fromB == a || (fromA != null && fromA == fromB);
  }
}

/// 引き継ぎ（.niatra）で受け取った一覧を、この端末の一覧へ合わせる決まり。
///
/// この端末の内容を黙って失わず、同じファイルを何度読んでも増えない：
/// - IDがこの端末に無い：足す。ただし同じ中身（[duplicateContentOf]）で、
///   名前が同じか複製どうし（どちらかがもう片方の複製、または同じ名前の
///   複製）の項目が読み込む前からこの端末にあれば足さない（もう1台へ渡した
///   複製が戻ってきた・この端末で複製を残して元を消した、など）。足さない
///   ときは、受け取った項目の整理をその項目へ合わせる。同じファイルの別の
///   項目とは比べない（もう1台で別々に持っていた物）。読み込む前からこの
///   端末にあった別の中身の項目と名前が同じなら、名前に番号を付けて足す
///   （同じ名前が並ばないように。IDはもう1台のままで、もう1台の版を足した
///   複製として`copies`に書き留める）。同じファイルの項目どうしの名前が同じ
///   だけなら、もう1台と同じ名前のまま足す（もう1台でも同じ名前で並んで
///   いた。空の端末へ移しただけで名前が変わらないように）。
/// - 同じIDで中身が同じで、名前が同じか複製どうし：中身と名前は変えず、
///   整理だけを合わせる（お気に入りはどちらかが付けていれば付ける、タグは
///   両方、フォルダはこの端末で入れていればそのまま・無ければ受け取った方）。
///   名前が違うのは、前の読み込みで名前に番号を付けて足した項目。
/// - 同じIDで中身か名前が違う：この端末の項目はそのまま、受け取った項目を
///   新しいIDの複製として足す。同じ中身で、名前が同じか複製どうしの項目が
///   読み込む前からこの端末にあれば足さず、整理をその項目へ合わせる（前に
///   足した複製）。探すときは、前の読み込みでこのIDの版を足した複製
///   （`copies`に書き留めたもの）が[contentOf]で同じならそれを選ぶ（足した
///   後でこの端末で名前・太さを変えた複製も。この端末で作った、太さだけが
///   違う自分の複製は選ばない）。次に、前の読み込みでこのIDの中身を持った
///   項目（同じ中身だったのでつないだ項目、[TransferCopyRecord.holdersOf]）が
///   [contentOf]で同じで、名前が同じか複製どうしならそれを選ぶ（この端末で
///   一覧の並び・太さを変えていても）。無ければ[duplicateContentOf]まで同じ
///   項目を一覧の順に選ぶ。記録した項目を先に見るのは、同じファイルを読み
///   直しても同じ項目を選ぶため（前の読み込みが同じファイルから足した、
///   同じ中身の別の項目は、読み直しでは読み込む前からある項目になる。
///   この端末で一覧の並びを変えると、同じ中身の別の項目が前に来る。そちらを
///   選ぶと、整理がどちらの端末でも付けていない項目に付く）。IDがこの端末に
///   無い項目も、その版を足した複製・その中身を持った項目が同じ中身であれば
///   足さない（この端末の版を消して、複製の方を残した）。
/// - [keepsLocalOnConflict]のIDは、同じIDで中身が違っても複製を足さず、
///   この端末の中身のまま整理だけを合わせる（使うたびに変わる値しか
///   持たない項目）。
/// - どの端末にもあるID（[shippedOf]が出荷時の項目を返す）は、この端末で
///   出荷時のままなら受け取った項目で置き換える（[canReplaceShipped]が
///   許すときだけ）。
/// - 受け取った項目がもう1台で出荷時のまま（[leftAsShipped]）なら、もう1台の
///   内容を持たない：この端末に無ければ足さず（この端末で消した）、あれば
///   整理だけを合わせる（複製は足さない）。
/// - [organizationOnly]のID（組み込みのブラシ・トーン・スタンプ）は中身を
///   受け取らず、整理だけを合わせる（この端末で出荷時のままなら受け取った
///   整理にし、向こうが出荷時のままならこの端末の整理のまま）。
class TransferMergeRules<T> {
  const TransferMergeRules({
    required this.idOf,
    required this.nameOf,
    required this.contentOf,
    required this.organizationOf,
    required this.withOrganization,
    required this.asCopy,
    required this.newId,
    required this.copyNames,
    this.duplicateContentOf,
    this.shippedOf,
    this.organizationOnly,
    this.canReplaceShipped,
    this.leftAsShipped,
    this.keepsLocalOnConflict,
  });

  final String Function(T item) idOf;
  final String Function(T item) nameOf;

  /// ID・名前・整理を除いた中身（JSONにできる形）。同じIDの項目どうしと、
  /// 前に足した複製を見分けるときに比べる。
  final Object? Function(T item) contentOf;

  /// この端末に無いIDの項目が、既にこの端末にあるかを見るときに比べる
  /// 中身。省略すると[contentOf]（[contentOf]が利用者の変えた値を比べない
  /// とき、その値だけが違う複製をもう1台で作っていれば、別の物として足す
  /// ために渡す）。
  final Object? Function(T item)? duplicateContentOf;
  final TransferOrganization Function(T item) organizationOf;
  final T Function(T item, TransferOrganization organization) withOrganization;
  final T Function(T incoming, String id, String name) asCopy;

  /// 新しいID（[attempt]は同じ呼び出しの中で何個目か）。
  final String Function(int attempt) newId;
  final TransferCopyNames copyNames;
  final T? Function(String id)? shippedOf;
  final bool Function(String id)? organizationOnly;
  final bool Function(T local, T incoming)? canReplaceShipped;

  /// 受け取った項目が、もう1台で出荷時のまま（利用者が触っていない）か。
  /// 省略すると、[shippedOf]のこの端末の出荷時の項目と同じ中身・名前か
  /// （版で出荷時の中身が変わる項目は、自分で見分け方を渡す）。
  final bool Function(T incoming)? leftAsShipped;

  /// 同じIDで中身が違っても複製を足さず、この端末の中身のままにするID
  /// （中身が使うたびに変わる最後に使った値で、行き来するたびに複製が
  /// 増える項目。組み込みの描画フィルター）。この端末で出荷時のままなら、
  /// 受け取った項目で置き換える（[shippedOf]・[canReplaceShipped]）。
  final bool Function(String id)? keepsLocalOnConflict;
}

/// [incoming]を[local]へ合わせる（[local]をその場で変える）。何か変えたか
/// を返す。
///
/// [placed]には、受け取った項目のIDごとに、合わせた後でその中身を持つ
/// この端末の項目のIDを書く（同じ項目ならそのID、複製として足したなら新しい
/// ID、同じ中身が既にあって足さなかったならその項目のID。足さなかった
/// 出荷時のままの項目は書かない）。項目の外にある整理（お気に入りの一覧など）
/// を、もう1台と同じ中身の項目にだけ付けるために使う。
///
/// [copies]は、受け取った項目のIDごとに、前の読み込みでその版を足した
/// 複製のID（呼び出し側が保存する）。同じIDで中身の違う項目を複製として
/// 足したときと、名前に番号を付けて足したとき（IDはそのまま）に書き足す
/// （足した後でこの端末で名前や、[contentOf]が比べない値〔ブラシの太さ〕
/// だけを変えた複製を、読み直したときに見つけるため）。同じ中身の項目が
/// 別のIDで既にあって足さなかったときは、その2つを同じ項目として書き留める
/// （[TransferCopyRecord.link]。この端末でその項目を変えた後も、作品・
/// 早替えツールなどが指す項目としては同じ項目とみなし、読み直しでは一覧の
/// 並びによらずその項目を選ぶため。足した複製には数えない）。前に足して
/// この端末で消した複製が、もう1台の項目として同じIDで届いて一覧に入った
/// ときも、それからは足した複製に数えない
/// （[TransferCopyRecord.arrivedAsItem]）。
bool mergeTransferredItems<T>(
  List<T> local,
  Iterable<T> incoming,
  TransferMergeRules<T> rules, {
  Map<String, String>? placed,
  TransferCopyRecord? copies,
}) {
  // 中身の比べ方（JSON）は項目ごとに1回だけ作る（読み込むたびに、受け取った
  // 項目ごとにこの端末の全項目と比べるため）。
  final contents = Map<T, String>.identity();
  String content(T item) =>
      contents.putIfAbsent(item, () => jsonEncode(rules.contentOf(item)));
  final duplicateOf = rules.duplicateContentOf;
  final fullContents = Map<T, String>.identity();
  String fullContent(T item) => duplicateOf == null
      ? content(item)
      : fullContents.putIfAbsent(item, () => jsonEncode(duplicateOf(item)));
  bool sameItem(T a, T b) =>
      content(a) == content(b) && rules.nameOf(a) == rules.nameOf(b);

  // 読み込む前からこの端末にあった項目（同じファイルの別の項目は、もう1台で
  // 別々に持っていた物なので、同じ中身でも1つにまとめない）。
  final before = {for (final e in local) rules.idOf(e)};
  // 読み込む前からこの端末にあった項目の名前（この名前と重なるときだけ、
  // 足す項目の名前に番号を付ける）。
  final namesBefore = {for (final e in local) rules.nameOf(e)};

  // 同じ中身で、名前が同じか複製どうしの項目が読み込む前からある。中身を
  // 受け取らない組み込みの項目とは比べない（組み込みのブラシを複製して
  // 太さだけ変えた自作のブラシは、組み込みと同じ中身でも別の物として足す）。
  T? alreadyThere(T item, String Function(T item) contentOf) {
    final incomingContent = contentOf(item);
    final incomingName = rules.nameOf(item);
    for (final e in local) {
      final id = rules.idOf(e);
      if (before.contains(id) &&
          !(rules.organizationOnly?.call(id) ?? false) &&
          contentOf(e) == incomingContent &&
          TransferCopyNames.related(rules.nameOf(e), incomingName)) {
        return e;
      }
    }
    return null;
  }

  // 前の読み込みで[item]のIDの版を足した複製（名前・太さなど、この端末で
  // 変えた値を除いて同じなら。新しく足した複製から）。
  T? addedBefore(T item) {
    final added = copies?.copiesOf(rules.idOf(item)) ?? const <String>[];
    for (final copyId in added.toList().reversed) {
      if (!before.contains(copyId)) continue;
      for (final e in local) {
        if (rules.idOf(e) == copyId && content(e) == content(item)) return e;
      }
    }
    return null;
  }

  // 前の読み込みで[item]の中身を持った（同じ中身だったので足さなかった）
  // この端末の項目（[TransferCopyRecord.link]）。中身（[contentOf]。太さなど
  // 比べない値はこの端末で変えていても）と、名前が同じか複製どうしなら選ぶ
  // （一覧の並びを変えた・太さを変えた後の読み直しで、同じ中身の別の項目へ
  // 替えない。後でつないだ項目から）。
  T? linkedBefore(T item) {
    final holders = copies?.holdersOf(rules.idOf(item)) ?? const <String>[];
    for (final holderId in holders.reversed) {
      if (!before.contains(holderId) ||
          (rules.organizationOnly?.call(holderId) ?? false)) {
        continue;
      }
      for (final e in local) {
        if (rules.idOf(e) == holderId &&
            content(e) == content(item) &&
            TransferCopyNames.related(rules.nameOf(e), rules.nameOf(item))) {
          return e;
        }
      }
    }
    return null;
  }

  var changed = false;

  // 足さなかった項目の整理（お気に入り・タグ・フォルダ）を、同じ中身の
  // この端末の項目へ合わせる（黙って捨てない）。
  void adoptOrganization(T existing, T item) {
    final index = local.indexWhere((e) => identical(e, existing));
    if (index < 0) return;
    final mine = rules.organizationOf(existing);
    final merged = _mergeOrganization(mine, rules.organizationOf(item));
    if (_sameOrganization(merged, mine)) return;
    local[index] = rules.withOrganization(existing, merged);
    changed = true;
  }

  // 受け取った[id]の項目の中身を、この端末の[existing]が持つ（足さない）。
  // 別のIDの項目なら、2つを同じ項目として書き留める（この端末でその項目を
  // 変えた後も、作品・早替えツールなどが指す項目としては同じ項目とみなす。
  // [TransferCopyRecord.origin]）。記録からではなく一覧から見つけた
  // （[found]）なら、記録で既に同じ項目でも[existing]が持ったことを書き
  // 留める（読み直しで、一覧の並びによらず同じ項目を選ぶ）。
  void heldBy(String id, T existing, {required bool found}) {
    final existingId = rules.idOf(existing);
    placed?[id] = existingId;
    copies?.link(id, existingId, asHolder: found);
  }

  var attempt = 0;
  String freshId() {
    final ids = {for (final e in local) rules.idOf(e)};
    var id = rules.newId(attempt++);
    while (ids.contains(id)) {
      id = rules.newId(attempt++);
    }
    return id;
  }

  for (final item in incoming) {
    final id = rules.idOf(item);
    final organizationOnly = rules.organizationOnly?.call(id) ?? false;
    final index = local.indexWhere((e) => rules.idOf(e) == id);
    final shipped = rules.shippedOf?.call(id);
    // もう1台で出荷時のまま（もう1台の利用者の内容を持たない）。
    final untouched =
        rules.leftAsShipped?.call(item) ??
        (shipped != null && sameItem(shipped, item));
    if (index < 0) {
      if (organizationOnly || untouched) continue;
      final recorded = addedBefore(item) ?? linkedBefore(item);
      final existing = recorded ?? alreadyThere(item, fullContent);
      if (existing != null) {
        heldBy(id, existing, found: recorded == null);
        adoptOrganization(existing, item);
        continue;
      }
      final name = rules.nameOf(item);
      final clashes = namesBefore.contains(name);
      local.add(
        clashes
            ? rules.asCopy(
                item,
                id,
                rules.copyNames.next(name, {
                  for (final e in local) rules.nameOf(e),
                }),
              )
            : item,
      );
      placed?[id] = id;
      // 前にほかの項目の版として足してこの端末で消した複製が、もう1台の
      // 項目として同じIDで届いた：これからはもう1台のその項目で、ほかの
      // 項目の版を足した複製としては選ばない（読み直しで、その項目の中身を
      // 持つ項目がこの項目へ替わらないように）。
      copies?.arrivedAsItem(id);
      // 名前に番号を付けて足した項目も、もう1台の版を足した複製（IDは
      // もう1台のまま）。この端末で名前を変えても、読み直しで見つける。
      if (clashes) copies?.add(id, id);
      changed = true;
      continue;
    }
    final mine = local[index];
    placed?[id] = id;
    final mineOrganization = rules.organizationOf(mine);
    final theirs = rules.organizationOf(item);

    if (organizationOnly) {
      final shippedOrganization = shipped == null
          ? null
          : rules.organizationOf(shipped);
      // 向こうで整理していない（出荷時のまま）なら、この端末の整理のまま。
      if (shippedOrganization != null &&
          _sameOrganization(theirs, shippedOrganization)) {
        continue;
      }
      final untouched =
          shippedOrganization != null &&
          _sameOrganization(mineOrganization, shippedOrganization);
      final next = untouched
          ? theirs
          : _mergeOrganization(mineOrganization, theirs);
      if (!_sameOrganization(next, mineOrganization)) {
        local[index] = rules.withOrganization(mine, next);
        changed = true;
      }
      continue;
    }

    // 中身が同じで名前が同じか複製どうし（前の読み込みで名前に番号を付けて
    // 足した同じ項目）、または受け取った項目が出荷時のまま（向こうの利用者の
    // 内容は整理だけ）：この端末の中身と名前はそのまま、整理だけを合わせる。
    if ((content(mine) == content(item) &&
            TransferCopyNames.related(
              rules.nameOf(mine),
              rules.nameOf(item),
            )) ||
        untouched) {
      final merged = _mergeOrganization(mineOrganization, theirs);
      if (!_sameOrganization(merged, mineOrganization)) {
        local[index] = rules.withOrganization(mine, merged);
        changed = true;
      }
      continue;
    }
    if (shipped != null &&
        sameItem(mine, shipped) &&
        (rules.canReplaceShipped?.call(mine, item) ?? true)) {
      local[index] = rules.withOrganization(
        item,
        _mergeOrganization(mineOrganization, theirs),
      );
      changed = true;
      continue;
    }

    // 使うたびに変わる値しか持たない項目は、この端末の値のまま、整理だけを
    // 合わせる（行き来するたびに複製を増やさない）。
    if (rules.keepsLocalOnConflict?.call(id) ?? false) {
      final merged = _mergeOrganization(mineOrganization, theirs);
      if (!_sameOrganization(merged, mineOrganization)) {
        local[index] = rules.withOrganization(mine, merged);
        changed = true;
      }
      continue;
    }

    // 前に足した複製。前の読み込みでこのIDの版を足した複製（名前に番号を
    // 付けて足したこの項目自身も）、次に前の読み込みでこのIDの中身を持った
    // 項目、無ければ利用者の変えた値（ブラシの太さ）まで同じ項目（この端末で
    // 別に作った、太さだけが違う同じ名前の複製は選ばない）。記録した項目を
    // 先に見る：前の読み込みが同じファイルから足した同じ中身の別の項目や、
    // 一覧で前にある同じ中身の別の項目へ、読み直しで替えない。
    final recorded = addedBefore(item) ?? linkedBefore(item);
    final existing = recorded ?? alreadyThere(item, fullContent);
    if (existing != null) {
      heldBy(id, existing, found: recorded == null);
      adoptOrganization(existing, item);
      continue;
    }
    final copyId = freshId();
    local.add(
      rules.asCopy(
        item,
        copyId,
        rules.copyNames.next(rules.nameOf(item), {
          for (final e in local) rules.nameOf(e),
        }),
      ),
    );
    placed?[id] = copyId;
    copies?.add(id, copyId);
    changed = true;
  }
  return changed;
}

/// 引き継ぎで、この端末の版を残してもう1台の版を複製として足した記録
/// （この端末の記録で、引き継ぎでは移さない）：受け取った項目のIDごとに、
/// その版を足した複製のID（足した順）。名前に番号を付けて足した項目は
/// 受け取ったID自身。一覧の種類（[brushes]等）ごとに保存する。同じ中身の
/// 項目が別のIDで既にあって足さなかったときは、その2つのつながりも書き留める
/// （[link]。足した複製〔[copiesOf]〕とは分けて持つ）。
///
/// 読み直したときに、足した後でこの端末で名前・太さを変えた複製を見つける
/// （[mergeTransferredItems]の`copies`）。また、もう1台の項目とその版を持つ
/// この端末の複製を、作品・早替えツールなどが指す項目としては同じ項目と
/// みなす（[origin]）。複製を消しても記録は残す（消した複製を指したままの
/// 作品を、同じファイルの同じ作品と見分けるため）。
class TransferCopyRecord {
  TransferCopyRecord._(this._key, this._copies, this._links);

  /// 何も書き留めていない、保存しない記録。
  TransferCopyRecord.none() : _key = null, _copies = {}, _links = {};

  static const brushes = 'brushes';
  static const tones = 'tones';
  static const stamps = 'stamps';
  static const autofillPresets = 'autofill_presets';

  /// 自動塗りのプリセットの複製のパーツ（受け取ったパーツのID → 複製の
  /// 同じ位置のパーツのID）。
  static const autofillParts = 'autofill_parts';
  static const themes = 'themes';
  static const palettes = 'palettes';
  static const pixelArtPalettes = 'pixel_art_palettes';
  static const workspaces = 'workspaces';
  static const automations = 'automations';
  static const quickTools = 'quick_tools';
  static const canvasSizes = 'canvas_sizes';
  static const drawFilters = 'draw_filters';
  static const watermarks = 'watermarks';

  /// 保存のキーの頭（後ろに一覧の種類が付く）。
  static const keyPrefix = 'transfer_copies.';

  static String _keyOf(String kind) => 'transfer_copies.$kind';

  final String? _key;
  final Map<String, List<String>> _copies;

  /// [link]で書き留めたつながり：この端末の項目のIDごとに、その項目が中身を
  /// 持っていた、受け取った項目のID。保存では、そのIDの複製の並びの中に
  /// もう1段の並びとして入れる（`{"a": ["aの複製", ["aが持っていた項目"]]}`）。
  final Map<String, List<String>> _links;
  Map<String, String>? _sources;
  var _changed = false;

  /// [kind]の一覧の記録を保存から読む。読めない記録は使わない（保存は
  /// 書き換えず、次に複製を足したときに書き直す）。
  static Future<TransferCopyRecord> read(String kind) async =>
      readFrom(await SharedPreferences.getInstance(), kind);

  /// [read]と同じく、[prefs]から読む（読み込みの合わせ方を待たずに行う
  /// 一覧が、起動のときに読んでおく）。
  static TransferCopyRecord readFrom(SharedPreferences prefs, String kind) {
    final key = _keyOf(kind);
    final copies = <String, List<String>>{};
    final links = <String, List<String>>{};
    try {
      final raw = prefs.readString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException('not a map');
        for (final entry in decoded.entries) {
          final id = entry.key;
          if (id is! String) continue;
          final value = entry.value;
          final ids = <String>[
            if (value is String) value,
            if (value is List)
              for (final copy in value)
                if (copy is String) copy,
          ];
          final linked = <String>[
            if (value is List)
              for (final held in value)
                if (held is List)
                  for (final other in held)
                    if (other is String) other,
          ];
          if (ids.isNotEmpty) copies[id] = ids;
          if (linked.isNotEmpty) links[id] = linked;
        }
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      copies.clear();
      links.clear();
    }
    return TransferCopyRecord._(key, copies, links);
  }

  /// [id]の項目の版を足した複製のID（足した順）。[link]でつなげただけの
  /// 項目は入らない。
  List<String> copiesOf(String id) => List.unmodifiable(_copies[id] ?? []);

  /// [link]で[id]とつないだ、[id]の中身を持っていたこの端末の項目のID
  /// （書き留めた順）。足した複製（[copiesOf]）は入らない。
  List<String> holdersOf(String id) => [
    for (final entry in _links.entries)
      if (entry.value.contains(id)) entry.key,
  ];

  /// [copyId]を[id]の版を足した複製として書き留める。
  void add(String id, String copyId) {
    final added = _copies.putIfAbsent(id, () => []);
    if (added.contains(copyId)) return;
    added.add(copyId);
    _sources = null;
    _changed = true;
  }

  /// 受け取った項目[id]と、その中身を別のIDで持っていたこの端末の項目
  /// [heldById]を、指す側（作品・早替えツールなど）から見て同じ項目として
  /// 書き留める（[origin]）。既につながっていれば何も書かない。[asHolder]
  /// なら、ほかの項目を通して既につながっていても、[heldById]が[id]の中身を
  /// 持ったことを書き留める（[holdersOf]。既に書き留めていれば何も書かない）。
  ///
  /// この端末の項目は引き継ぎで足した複製ではないので、どちらの項目の複製
  /// （[copiesOf]）にも入れない（受け取った項目が後でこの端末の一覧に
  /// 入っても、つなげた項目の版を足した複製としては選ばない）。読み直しでは、
  /// 中身と名前が同じか複製どうしのうちは、つないだこの端末の項目
  /// （[holdersOf]）が受け取った項目の中身を持つ（一覧の並びや、比べない値
  /// 〔ブラシの太さ〕をこの端末で変えていても。中身や名前を変えた後の
  /// 読み直しは、これまでどおりもう1台の項目を足すか、同じ中身の別の項目が
  /// 持つ）。
  void link(String id, String heldById, {bool asHolder = false}) {
    if (asHolder
        ? id == heldById || holdersOf(id).contains(heldById)
        : origin(id) == origin(heldById)) {
      return;
    }
    _links.putIfAbsent(heldById, () => []).add(id);
    _sources = null;
    _changed = true;
  }

  /// 前にほかの項目の版を足した複製[id]が、もう1台の項目として同じIDで届いて
  /// この端末の一覧に入った（この端末で消した複製を、もう1台が自分の項目と
  /// して持っていた）。これからはもう1台のその項目なので、ほかの項目の版を
  /// 足した複製（[copiesOf]）としては数えない。同じ項目としてのつながり
  /// （[origin]）は残す。[id]自身の版の記録と、[id]の版を足した複製は
  /// そのまま。
  void arrivedAsItem(String id) {
    for (final holder in _copies.keys.toList()) {
      if (holder == id) continue;
      final added = _copies[holder]!;
      if (!added.remove(id)) continue;
      if (added.isEmpty) _copies.remove(holder);
      _links.putIfAbsent(holder, () => []).add(id);
      _sources = null;
      _changed = true;
    }
  }

  /// [id]が引き継ぎで足した複製なら、その版の元の項目のID（複製の複製は
  /// 元までたどる）。複製でなければ[id]のまま。
  ///
  /// 記録でつながるIDはどれも同じIDを返す：この端末の1つの項目がもう1台の
  /// 2つの項目の版を持つ（同じ中身の2つがどちらもこの端末の同じ項目だった）
  /// ときも、その3つを同じ項目とみなす（元を1つだけたどると、片方の項目とは
  /// 別の項目になり、それを指す早替えツールなどを読み直しで二重にした）。
  String origin(String id) => (_sources ??= _origins())[id] ?? id;

  /// 記録にあるIDごとの、つながるIDの組を代表するID（元が1つずつなら、
  /// いちばん元の項目のID）。
  Map<String, String> _origins() {
    final source = <String, String>{};
    String rootOf(String id) {
      var root = id;
      while (source[root] != null) {
        root = source[root]!;
      }
      return root;
    }

    for (final entry in [..._copies.entries, ..._links.entries]) {
      for (final copy in entry.value) {
        final from = rootOf(entry.key);
        final to = rootOf(copy);
        if (from != to) source[to] = from;
      }
    }
    return {for (final id in source.keys) id: rootOf(id)};
  }

  /// 書き足したときだけ保存する。
  Future<void> save() async {
    final key = _key;
    if (!_changed || key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        for (final id in {..._copies.keys, ..._links.keys})
          id: [...?_copies[id], ?_links[id]],
      }),
    );
    _changed = false;
  }
}

bool _sameOrganization(TransferOrganization a, TransferOrganization b) =>
    a.favorite == b.favorite &&
    a.folderId == b.folderId &&
    jsonEncode(a.tags) == jsonEncode(b.tags);

TransferOrganization _mergeOrganization(
  TransferOrganization mine,
  TransferOrganization theirs,
) {
  final known = {for (final tag in mine.tags) tag.toLowerCase()};
  return (
    favorite: mine.favorite || theirs.favorite,
    tags: [
      ...mine.tags,
      for (final tag in theirs.tags)
        if (known.add(tag.toLowerCase())) tag,
    ],
    folderId: mine.folderId ?? theirs.folderId,
  );
}

/// 引き継ぎで比べる画像の中身。項目を比べるときは画像を置いた場所（ファイル
/// 名）ではなく中身で比べる（受け取った画像は受け取ったIDから決まる名前で
/// 置くので、場所で比べると、同じ画像でも端末ごとに別の物に見える）。
class TransferImageDigests {
  TransferImageDigests._(this._digests);

  final Map<String, String> _digests;

  /// [paths]の画像を読んでおく（読めないファイルは場所で比べる）。
  static Future<TransferImageDigests> read(Iterable<String?> paths) async {
    final digests = <String, String>{};
    for (final path in paths) {
      if (path == null || path.isEmpty || digests.containsKey(path)) continue;
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        digests[path] =
            '${bytes.length}:${getCrc32(bytes)}:${getAdler32(bytes)}';
      } on UnsupportedError {
        // ファイルを読めない環境では場所で比べる。
      } on FileSystemException {
        // 読めない1件は場所で比べる。
      }
    }
    return TransferImageDigests._(digests);
  }

  /// [path]の画像の中身（同じ中身なら同じ値）。読めなかった画像は場所。
  String of(String? path) =>
      path == null || path.isEmpty ? '' : _digests[path] ?? 'path:$path';
}
