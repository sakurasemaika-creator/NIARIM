import 'dart:typed_data';

/// Whether [a] and [b] hold the same bytes, compared 8 bytes at a time.
bool sameBytes(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  final length = a.length;
  if (length != b.length) return false;
  final wide = length & ~7;
  final da = ByteData.sublistView(a);
  final db = ByteData.sublistView(b);
  for (var i = 0; i < wide; i += 8) {
    if (da.getUint64(i, Endian.host) != db.getUint64(i, Endian.host)) {
      return false;
    }
  }
  for (var i = wide; i < length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
