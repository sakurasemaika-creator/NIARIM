import 'package:flutter/foundation.dart';

import 'filter_selection.dart';

/// How a touch on the canvas edits the glasses filter's lens area.
enum FilterLensMaskTool { pen, eraser, bucket }

/// The area the glasses filter bends, painted on the canvas while the filter
/// is adjusted: one coverage byte per canvas pixel (see
/// [selectionCoverage]). The canvas screen owns it and hands it to the
/// canvas (which shows it and paints into it) and the filter panel (which
/// previews and applies the filter with it).
class FilterLensMask extends ChangeNotifier {
  /// The tool a touch on the canvas uses; null leaves the canvas to the
  /// filter's handles.
  FilterLensMaskTool? get tool => _tool;
  FilterLensMaskTool? _tool;

  /// The pen and eraser's radius, in screen pixels (a finger's size does
  /// not depend on the zoom).
  double get brushRadius => _brushRadius;
  double _brushRadius = 16;

  /// The lens area: [width]×[height] coverage, or null before any is set.
  /// Each change is a new list, so identity says whether it changed.
  Uint8List? get coverage => _coverage;
  Uint8List? _coverage;
  int get width => _width;
  int get height => _height;
  int _width = 0;
  int _height = 0;

  /// Whether the area holds anything to bend.
  bool get isEmpty => !selectsAnything(_coverage);

  void setTool(FilterLensMaskTool? tool) {
    if (tool == _tool) return;
    _tool = tool;
    notifyListeners();
  }

  void setBrushRadius(double radius) {
    if (radius == _brushRadius) return;
    _brushRadius = radius;
    notifyListeners();
  }

  /// Replaces the area (a stroke or fill just finished, its Undo or Redo,
  /// or the starting area taken from a selection).
  void replace(Uint8List? coverage, int width, int height) {
    _coverage = coverage;
    _width = width;
    _height = height;
    notifyListeners();
  }

  /// Replaces the area as one step of the filter's Undo history: [record]
  /// receives how to take it back and to do it again.
  void edit(
    Uint8List? next,
    int width,
    int height,
    void Function({required VoidCallback undo, required VoidCallback redo})
    record,
  ) {
    final before = _coverage;
    final beforeWidth = _width, beforeHeight = _height;
    replace(next, width, height);
    record(
      undo: () => replace(before, beforeWidth, beforeHeight),
      redo: () => replace(next, width, height),
    );
  }

  /// Forgets the area and the tool (the filter panel closed, or another
  /// filter was chosen).
  void reset() {
    if (_coverage == null && _tool == null) return;
    _coverage = null;
    _tool = null;
    notifyListeners();
  }
}
