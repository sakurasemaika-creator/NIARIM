import 'package:shared_preferences/shared_preferences.dart';

/// A rejected folder operation. Some earlier contents may already be at root.
class FolderSaveException implements Exception {
  const FolderSaveException({required this.partiallySaved, this.cause});

  final bool partiallySaved;
  final Object? cause;

  @override
  String toString() => 'FolderSaveException(partiallySaved: $partiallySaved)';
}

/// Commit one preference before publishing its corresponding model snapshot.
/// SharedPreferences mutates its cache even when the platform rejects a write.
Future<void> saveFolderPreference(String key, String value) async {
  late final SharedPreferences prefs;
  Object? before;
  Future<bool> restore() => switch (before) {
    null => prefs.remove(key),
    String v => prefs.setString(key, v),
    bool v => prefs.setBool(key, v),
    int v => prefs.setInt(key, v),
    double v => prefs.setDouble(key, v),
    List<Object?> v when v.every((item) => item is String) =>
      prefs.setStringList(key, v.cast<String>()),
    _ => throw StateError('Unsupported folder preference value'),
  };
  try {
    prefs = await SharedPreferences.getInstance();
    before = prefs.get(key);
    if (before == value) return;
    try {
      if (!await prefs.setString(key, value)) {
        throw StateError('Folder preference write rejected');
      }
    } catch (_) {
      try {
        await restore();
      } catch (_) {
        // Its cache is restored before awaiting even a rejected restoration.
      }
      rethrow;
    }
  } catch (error) {
    throw FolderSaveException(partiallySaved: false, cause: error);
  }
}
