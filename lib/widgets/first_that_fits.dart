import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shows the first of [children] whose natural width fits the width it is
/// given. The last child is the fallback and is shown whenever none of the
/// earlier ones fit. The natural width is measured with a dry layout under an
/// unbounded width (intrinsic widths are not exact for every widget: a chip's
/// leaves out its avatar), so a child must not have flexible children at its
/// top level; use [MainAxisAlignment] to spread a [Row] instead of a [Spacer].
///
/// This is how a row follows the rule for narrow widths: text is never
/// shrunk. Give the labelled form first and an icon-only form (with the name
/// in its tooltip and screen-reader label) after it; the choice is made from
/// the measured width, not from the kind of device.
///
/// Only the chosen child is painted, hit-tested, announced to screen readers,
/// reachable with the keyboard and visible to widget-test finders; the others
/// stay built (keeping their state) and laid out, but inert. Children must
/// support dry layout (no [LayoutBuilder]).
///
/// Give every child the same controls in the same order (a labelled button in
/// one form and the same action as an icon in the next): when the chosen form
/// changes while one of its controls has keyboard focus, focus moves to the
/// control at the same position in the new form, so the next Space or Enter
/// still runs the same action.
class FirstThatFits extends StatefulWidget {
  const FirstThatFits({super.key, required this.children})
    : assert(children.length > 0);

  final List<Widget> children;

  @override
  State<FirstThatFits> createState() => _FirstThatFitsState();
}

class _FirstThatFitsState extends State<FirstThatFits> {
  int _chosen = 0;

  /// One focus node around each form: the hidden forms' controls cannot take
  /// focus, and the chosen form's tell where keyboard focus is.
  final List<FocusNode> _forms = [];

  @override
  void dispose() {
    for (final node in _forms) {
      node.dispose();
    }
    super.dispose();
  }

  /// The form's controls that can take keyboard focus. All the forms are
  /// built from the same state at the same time, so their controls are in
  /// the same order.
  List<FocusNode> _controls(int form) => [
    for (final node in _forms[form].descendants)
      if (node.canRequestFocus && !node.skipTraversal) node,
  ];

  /// The position of the control in [form] that has keyboard focus, or null
  /// when focus is outside the form.
  int? _focusedPosition(int form) {
    if (form >= _forms.length || !_forms[form].hasFocus) return null;
    final primary = FocusManager.instance.primaryFocus;
    final controls = _controls(form);
    for (var i = 0; i < controls.length; i++) {
      final control = controls[i];
      if (identical(control, primary) ||
          (primary?.ancestors.contains(control) ?? false)) {
        return i;
      }
    }
    return 0;
  }

  void _onChosen(int index) {
    if (index == _chosen) return;
    // Layout decides; keyboard focus follows on the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index == _chosen) return;
      final position = _focusedPosition(_chosen);
      setState(() => _chosen = index);
      if (position == null) return;
      // Hiding the old form drops its focus, and Flutter would hand it to
      // the control that had it before, outside this row. Once the new form
      // can take focus, give it to the control at the same position (the
      // last request in a frame wins, so the row never visibly loses it).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _chosen != index || index >= _forms.length) return;
        final controls = _controls(index);
        if (controls.isEmpty) return;
        controls[math.min(position, controls.length - 1)].requestFocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    while (_forms.length < widget.children.length) {
      _forms.add(
        FocusNode(
          debugLabel: 'FirstThatFits form ${_forms.length}',
          canRequestFocus: false,
          skipTraversal: true,
        ),
      );
    }
    return _FirstThatFitsLayout(
      onChosen: _onChosen,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Focus(
            focusNode: _forms[i],
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            descendantsAreFocusable: i == _chosen,
            descendantsAreTraversable: i == _chosen,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _FirstThatFitsLayout extends MultiChildRenderObjectWidget {
  const _FirstThatFitsLayout({required this.onChosen, required super.children});

  final ValueChanged<int> onChosen;

  @override
  MultiChildRenderObjectElement createElement() => _FirstThatFitsElement(this);

  @override
  RenderFirstThatFits createRenderObject(BuildContext context) =>
      RenderFirstThatFits(onChosen: onChosen);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFirstThatFits renderObject,
  ) {
    renderObject.onChosen = onChosen;
  }
}

class _FirstThatFitsElement extends MultiChildRenderObjectElement {
  _FirstThatFitsElement(_FirstThatFitsLayout super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final chosen = (renderObject as RenderFirstThatFits).chosenIndex;
    var index = 0;
    for (final child in children) {
      if (index == chosen) visitor(child);
      index++;
    }
  }
}

class _FirstThatFitsParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [FirstThatFits].
class RenderFirstThatFits extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FirstThatFitsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FirstThatFitsParentData> {
  RenderFirstThatFits({required this.onChosen});

  ValueChanged<int> onChosen;

  /// The index of the child that was laid out and is shown.
  int get chosenIndex => _chosenIndex;
  int _chosenIndex = 0;
  RenderBox? _chosen;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FirstThatFitsParentData) {
      child.parentData = _FirstThatFitsParentData();
    }
  }

  (int, RenderBox) _pick(BoxConstraints constraints) {
    final natural = BoxConstraints(
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
    var index = 0;
    var child = firstChild!;
    while (true) {
      final next = childAfter(child);
      if (next == null ||
          child.getDryLayout(natural).width <= constraints.maxWidth + 0.01) {
        return (index, child);
      }
      child = next;
      index++;
    }
  }

  @override
  void performLayout() {
    final (index, child) = _pick(constraints);
    // The hidden forms are laid out too, each as its own relayout boundary
    // (their size is not used). A form that was shown before and is hidden
    // now must not be left needing layout under a clean parent: the next
    // change inside it would break the layout rules (debug assertions, then
    // a damaged render tree). Hidden forms are never painted, so a form that
    // is too wide reports no overflow.
    for (var other = firstChild; other != null; other = childAfter(other)) {
      if (!identical(other, child)) other.layout(constraints.loosen());
    }
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as _FirstThatFitsParentData).offset = Offset.zero;
    size = constraints.constrain(child.size);
    _chosen = child;
    _chosenIndex = index;
    onChosen(index);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final (_, child) = _pick(constraints);
    return constraints.constrain(child.getDryLayout(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      lastChild?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) {
    final (_, child) = _pick(BoxConstraints(maxWidth: width));
    return child.getMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final (_, child) = _pick(BoxConstraints(maxWidth: width));
    return child.getMaxIntrinsicHeight(width);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _chosen?.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = _chosen;
    if (child != null) context.paintChild(child, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _chosen;
    if (child == null) return false;
    return child.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final child = _chosen;
    if (child != null) visitor(child);
  }
}
