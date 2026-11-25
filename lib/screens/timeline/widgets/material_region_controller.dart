import 'package:flutter/foundation.dart';

import '../../../models/layer_region_edit.dart';

/// What the material panel's 範囲選択 section and the preview's handles
/// share while a timeline image or video is edited: whether the section is
/// shown, the shape a new outline is drawn in, the part selected (not part
/// of the material until an edit is chosen), and the moved or copied part
/// being changed. The edits themselves are kept on the material's layer.
class MaterialRegionController extends ChangeNotifier {
  bool _editing = false;
  RegionShape _shape = RegionShape.rectangle;
  RegionSelection? _selection;
  String? _activeEditId;

  /// Whether the 範囲選択 section is shown (the preview then shows these
  /// handles instead of the material's own).
  bool get editing => _editing;
  set editing(bool value) {
    if (_editing == value) return;
    _editing = value;
    notifyListeners();
  }

  RegionShape get shape => _shape;
  set shape(RegionShape value) {
    if (_shape == value) return;
    _shape = value;
    notifyListeners();
  }

  RegionSelection? get selection => _selection;
  set selection(RegionSelection? value) {
    if (_selection == value) return;
    _selection = value;
    notifyListeners();
  }

  /// The id of the moved or copied part being changed, if any.
  String? get activeEditId => _activeEditId;
  set activeEditId(String? value) {
    if (_activeEditId == value) return;
    _activeEditId = value;
    notifyListeners();
  }

  /// The part being changed among [edits] (null when none is, or when it
  /// was removed, for example by Undo).
  LayerRegionEdit? activeIn(List<LayerRegionEdit> edits) {
    final id = _activeEditId;
    if (id == null) return null;
    for (final edit in edits) {
      if (edit.id == id) return edit.drawsPiece ? edit : null;
    }
    return null;
  }

  /// Forgets the selection and the part being changed (another material is
  /// edited, or the panel closes). The shape chosen is kept.
  void reset() {
    if (_selection == null && _activeEditId == null && !_editing) return;
    _selection = null;
    _activeEditId = null;
    _editing = false;
    notifyListeners();
  }
}
