/// Reorders the unfiled built-ins in place. Custom assets and assets that the
/// user moved to a folder keep their existing slots and organization.
bool groupUnfiledBuiltIns<T>(
  List<T> items,
  Iterable<String> builtInOrder, {
  required String Function(T) idOf,
  required String? Function(T) folderOf,
}) {
  final ranks = {for (final (index, id) in builtInOrder.indexed) id: index};
  final positions = <int>[];
  final builtIns = <T>[];
  for (final (index, item) in items.indexed) {
    if (folderOf(item) != null || !ranks.containsKey(idOf(item))) continue;
    positions.add(index);
    builtIns.add(item);
  }
  builtIns.sort((a, b) => ranks[idOf(a)]!.compareTo(ranks[idOf(b)]!));
  var changed = false;
  for (final (index, position) in positions.indexed) {
    if (identical(items[position], builtIns[index])) continue;
    items[position] = builtIns[index];
    changed = true;
  }
  return changed;
}
