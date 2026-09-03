/// `ReorderableListView`の並び替えコールバックの添字規約を変換する。
///
/// 非推奨になった`onReorder`は、newIndexを「移動元をまだ取り除いていない
/// リスト上の挿入位置」で渡してくる。後継の`onReorderItem`は「移動元を
/// 取り除いた後のリスト上の最終位置」で渡してくる。両者は下方向へ動かした
/// ときだけ1ずれる。
///
/// このアプリの各サービスの並び替えメソッド（`BrushService.reorderBrush`・
/// `ProjectService.reorderLayer`等）は、内部に
/// `if (newIndex > oldIndex) newIndex--;` を持つ「取り除く前」の規約で
/// 書かれている。しかもドラッグ操作以外の呼び出し元がある
/// （自動塗りが作ったレイヤーを線画の上へ差し込む
/// `AutofillBatchRunner`、縁取りフィルターの`FilterPanel`、
/// いくつかのサービス単体テスト）。これらは`indexWhere(...) + 1`のように
/// 「取り除く前」の位置を自分で計算しており、サービス側の規約を変えると
/// 一緒に壊れる。
///
/// そこでサービスには手を触れず、UI側で`onReorderItem`の添字を
/// 元の規約へ戻してから渡す。変換とサービス内部の`-1`は必ず打ち消し合い、
/// 最終的な挿入位置は`onReorderItem`が意図した位置と厳密に一致する
/// （newIndex >= oldIndex なら +1 されてから -1 され、
/// newIndex < oldIndex ならどちらの補正も走らない）。
///
/// なお newIndex == oldIndex の境界は、+1しても・しなくても「自分の位置へ
/// 戻す」＝並びが変わらない操作になるため、比較を`>=`にしても`>`にしても
/// 結果は同じ。`test/reorder_index_test.dart`が全組み合わせを総当たりで
/// 検証している。
int preRemovalIndex(int oldIndex, int newIndex) =>
    newIndex >= oldIndex ? newIndex + 1 : newIndex;
