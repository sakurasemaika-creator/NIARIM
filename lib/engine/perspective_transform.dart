import 'dart:math' as math;
import 'dart:typed_data';

/// A 4×4 matrix (column-major, as `Canvas.transform` takes it) that turns
/// a layer about the centre ([cx], [cy]) of a [width]×[height] canvas: moved
/// by ([dx], [dy]), scaled by [scale], and rotated about the X axis
/// (tipping the top away), the Y axis (turning the right side away) and the
/// Z axis (in the plane), all in degrees, seen in perspective so the X and
/// Y turns look like depth rather than squashing.
Float64List perspectiveLayerMatrix({
  required double width,
  required double height,
  double dx = 0,
  double dy = 0,
  double scale = 1,
  double rotationX = 0,
  double rotationY = 0,
  double rotationZ = 0,
}) {
  final cx = width / 2;
  final cy = height / 2;
  // How far away the eye is: about one and a half canvases, so a quarter
  // turn shows depth without the near edge flying off.
  final eye = math.max(width, height) * 1.5;
  var m = _translate(cx + dx, cy + dy);
  m = _multiply(m, _perspective(eye));
  m = _multiply(m, _rotateX(rotationX * math.pi / 180));
  m = _multiply(m, _rotateY(rotationY * math.pi / 180));
  m = _multiply(m, _rotateZ(rotationZ * math.pi / 180));
  m = _multiply(m, _scale(scale == 0 ? 1 : scale));
  m = _multiply(m, _translate(-cx, -cy));
  return m;
}

/// Where the point ([x], [y]) on the layer lands after [m].
(double, double) transformPoint(Float64List m, double x, double y) {
  final px = m[0] * x + m[4] * y + m[12];
  final py = m[1] * x + m[5] * y + m[13];
  final pw = m[3] * x + m[7] * y + m[15];
  final w = pw.abs() < 1e-9 ? 1e-9 : pw;
  return (px / w, py / w);
}

Float64List _identity() => Float64List(16)
  ..[0] = 1
  ..[5] = 1
  ..[10] = 1
  ..[15] = 1;

Float64List _translate(double x, double y) => _identity()
  ..[12] = x
  ..[13] = y;

Float64List _scale(double s) => _identity()
  ..[0] = s
  ..[5] = s;

Float64List _perspective(double eye) => _identity()..[11] = -1 / eye;

Float64List _rotateX(double a) {
  final c = math.cos(a), s = math.sin(a);
  return _identity()
    ..[5] = c
    ..[6] = s
    ..[9] = -s
    ..[10] = c;
}

Float64List _rotateY(double a) {
  final c = math.cos(a), s = math.sin(a);
  return _identity()
    ..[0] = c
    ..[2] = -s
    ..[8] = s
    ..[10] = c;
}

Float64List _rotateZ(double a) {
  final c = math.cos(a), s = math.sin(a);
  return _identity()
    ..[0] = c
    ..[1] = s
    ..[4] = -s
    ..[5] = c;
}

/// [a]·[b] (apply [b] first).
Float64List _multiply(Float64List a, Float64List b) {
  final out = Float64List(16);
  for (var col = 0; col < 4; col++) {
    for (var row = 0; row < 4; row++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[k * 4 + row] * b[col * 4 + k];
      }
      out[col * 4 + row] = sum;
    }
  }
  return out;
}
