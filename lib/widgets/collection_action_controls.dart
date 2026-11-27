import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/accent_text_theme.dart';
import '../screens/canvas/widgets/canvas_icon_button.dart';

/// Identical tap areas and toolbar-style outline across project, folder,
/// received-share and local-file collection actions.
///
/// The circle is drawn [extent] across and takes that much room in the
/// layout, but taps and screen readers get a [targetExtent] square around it
/// (Android's minimum, 48×48): the frame answers taps up to 4px beyond the
/// circle on every side, and a tap there (or on the circle's square corners)
/// goes to the circle's centre, as Material's padded tap targets do. Nothing
/// drawn moves. The parent must leave that room inside its own bounds (a
/// [Positioned] 4px from a card's corner does); two frames side by side go in
/// a [CollectionActionRow], which shares the gap between them.
class CollectionActionFrame extends StatelessWidget {
  const CollectionActionFrame({super.key, required this.child});

  static const double extent = 40;

  /// The tap target around the drawn circle ([kMinInteractiveDimension]).
  static const double targetExtent = kMinInteractiveDimension;

  /// Whether [pointer] went down on one of these circles and has not been
  /// lifted yet. The circle sees the pointer-down before the widgets around
  /// it (it is deeper in the hit test), so a card around it can ask this when
  /// the same pointer reaches it ([CollectionCardDoubleTapRecognizer]).
  static bool isPressing(int pointer) =>
      _RenderActionTarget._pressing.contains(pointer);
  static const double glyphSize = 16;

  final Widget child;

  /// The opacity of the outer ring (see [haloColor]).
  static const double haloOpacity = 0.8;

  /// The width of the outer ring, drawn just outside the circle.
  static const double haloWidth = 1;

  /// The outer ring around the circle's own outline: the theme's other
  /// extreme (its text colour where the outline is the surface colour, and
  /// the other way round), at [haloOpacity]. The circle sits on whatever is
  /// under it (a card, or a project's cover: its own paper colour or
  /// picture, not a theme colour), so its card-coloured fill and outline
  /// alone vanished on a white paper in light themes (|Lc| 0). With a light
  /// and a dark ring one of them always separates the circle from the
  /// cover. The theme colours themselves are not changed.
  static Color haloColor(ColorScheme scheme) {
    final outline = CanvasIconButton.outlineColor(
      scheme.onSurfaceVariant,
      scheme,
    );
    final other = outline == scheme.surface ? scheme.onSurface : scheme.surface;
    return other.withValues(alpha: other.a * haloOpacity);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slot = _CollectionActionSlot.maybeOf(context);
    return _ActionTarget(
      reach: slot?.reach ?? const EdgeInsets.all((targetExtent - extent) / 2),
      child: SizedBox.square(
        dimension: slot?.buttonExtent ?? extent,
        child: DecoratedBox(
          // Drawn outside the circle, so the layout and the tap target stay.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: haloColor(scheme),
              width: haloWidth,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: CanvasIconButton.outlineColor(
                  scheme.onSurfaceVariant,
                  scheme,
                ),
                width: 1.25,
              ),
            ),
            child: ClipOval(child: child),
          ),
        ),
      ),
    );
  }
}

/// Collection actions side by side (the star and the "⋮" of a list row),
/// [gap] apart as drawn before. Each gets a 48×48 tap target that does not
/// overlap its neighbour's: the gap is split in the middle and the rest of
/// each target reaches outwards. Replaces a [Row] of frames, which would
/// refuse taps outside its own bounds.
///
/// With [direction] [Axis.vertical] the circles are stacked instead (the
/// "⋮" above the bookmark of a ranking row), with the same rules up and down.
class CollectionActionRow extends StatelessWidget {
  const CollectionActionRow({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.buttonExtent = CollectionActionFrame.extent,
    this.targetWidth = CollectionActionFrame.targetExtent,
  });

  /// The drawn space between two circles.
  static const double gap = 4;

  /// [CollectionActionFrame]s, directly or inside widgets that add no box of
  /// their own (a [StatelessWidget] that returns the frame). A box around a
  /// frame ([Semantics], [SizedBox]…) would refuse the taps beyond the circle:
  /// put such a widget inside the frame instead.
  final List<Widget> children;

  /// Which way the circles are lined up.
  final Axis direction;
  final double buttonExtent;
  final double targetWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final vertical = direction == Axis.vertical;
    final spare =
        (vertical ? CollectionActionFrame.targetExtent : targetWidth) -
        buttonExtent;
    const inner = gap / 2;
    final across =
        ((vertical ? targetWidth : CollectionActionFrame.targetExtent) -
            buttonExtent) /
        2;
    final count = children.length;
    final outer = count == 1 ? spare / 2 : spare - inner;
    final rtl = !vertical && Directionality.of(context) == TextDirection.rtl;
    EdgeInsets reachAt(int visual) {
      final before = visual == 0 ? outer : inner;
      final after = visual == count - 1 ? outer : inner;
      return vertical
          ? EdgeInsets.fromLTRB(across, before, across, after)
          : EdgeInsets.fromLTRB(before, across, after, across);
    }

    return _ActionRow(
      reach: vertical
          ? EdgeInsets.fromLTRB(across, outer, across, outer)
          : EdgeInsets.fromLTRB(outer, across, outer, across),
      direction: direction,
      registry: _ReachScope.of(context),
      children: [
        for (var i = 0; i < count; i++)
          _CollectionActionSlot(
            buttonExtent: buttonExtent,
            reach: reachAt(rtl ? count - 1 - i : i),
            child: children[i],
          ),
      ],
    );
  }
}

/// A [ListTile] lays its trailing widget out inside its content padding and
/// refuses taps outside that widget's box, so a [CollectionActionRow] used as
/// [ListTile.trailing] would lose the strip of its "⋮" target that reaches
/// towards the tile's end. Wrapping the tile (see
/// [CollectionActionReachExtension.withCollectionActionReach]) lets the rows
/// inside take taps in their whole targets: a tap there goes straight to the
/// row, ahead of the tile's own tap.
class CollectionActionReach extends StatefulWidget {
  const CollectionActionReach({super.key, required this.child});

  final Widget child;

  @override
  State<CollectionActionReach> createState() => _CollectionActionReachState();
}

class _CollectionActionReachState extends State<CollectionActionReach> {
  final _rows = <_RenderActionRow>{};

  @override
  Widget build(BuildContext context) => _ReachHost(
    rows: _rows,
    child: _ReachScope(rows: _rows, child: widget.child),
  );
}

extension CollectionActionReachExtension on Widget {
  /// This widget inside a [CollectionActionReach].
  Widget withCollectionActionReach() => CollectionActionReach(child: this);
}

/// The [CollectionActionRow]s inside a [CollectionActionReach].
class _ReachScope extends InheritedWidget {
  const _ReachScope({required this.rows, required super.child});

  final Set<_RenderActionRow> rows;

  static Set<_RenderActionRow>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReachScope>()?.rows;

  @override
  bool updateShouldNotify(_ReachScope oldWidget) =>
      !identical(rows, oldWidget.rows);
}

class _ReachHost extends SingleChildRenderObjectWidget {
  const _ReachHost({required this.rows, required super.child});

  final Set<_RenderActionRow> rows;

  @override
  _RenderReachHost createRenderObject(BuildContext context) =>
      _RenderReachHost(rows);

  @override
  void updateRenderObject(BuildContext context, _RenderReachHost renderObject) {
    renderObject.rows = rows;
  }
}

class _RenderReachHost extends RenderProxyBox {
  _RenderReachHost(this.rows);

  Set<_RenderActionRow> rows;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      for (final row in rows) {
        if (!row.attached || !row.hasSize) continue;
        final transform = row.getTransformTo(this);
        final inverse = Matrix4.tryInvert(transform);
        if (inverse == null) continue;
        final local = MatrixUtils.transformPoint(inverse, position);
        // Inside the row's box the usual hit test reaches it.
        if (row.size.contains(local) || !row.reaches(local)) continue;
        final hit = result.addWithPaintTransform(
          transform: transform,
          position: position,
          hitTest: (result, local) => row.hitTest(result, position: local),
        );
        if (hit) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      }
    }
    return super.hitTest(result, position: position);
  }
}

/// A tile's bottom action band. It keeps the controls side by side, with
/// full-height touch targets and non-overlapping horizontal reach.
class CollectionTileActions extends StatelessWidget {
  /// Keeps the title and cover at their usual positions during multi-selection.
  static const selectionSpace = SizedBox(
    height: CollectionActionFrame.targetExtent,
  );

  const CollectionTileActions({
    super.key,
    required this.children,
    this.compact = false,
    this.leading,
  });

  final List<Widget> children;
  final bool compact;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && leading == null) return const SizedBox.shrink();
    return SizedBox(
      height: CollectionActionFrame.targetExtent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (children.isEmpty) return leading!;
          final count = children.length;
          final labelSpace = leading == null
              ? 0.0
              : math.min(
                  constraints.maxWidth * .38,
                  (constraints.maxWidth -
                          CollectionActionFrame.targetExtent * count)
                      .clamp(28.0, 68.0),
                );
          final width = math.min(
            CollectionActionFrame.targetExtent,
            (constraints.maxWidth - labelSpace) / count,
          );
          if (width <= CollectionActionRow.gap) return const SizedBox.shrink();
          final preferredExtent = compact ? 32.0 : CollectionActionFrame.extent;
          final extent = math.min(
            preferredExtent,
            width - CollectionActionRow.gap,
          );
          final spare = width - extent;
          final edge = count == 1
              ? spare / 2
              : spare - CollectionActionRow.gap / 2;
          final actions = CollectionActionRow(
            buttonExtent: extent,
            targetWidth: width,
            children: children,
          );
          if (leading == null) {
            return Padding(
              padding: EdgeInsetsDirectional.only(end: edge),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: actions,
              ),
            );
          }
          return Row(
            children: [
              Expanded(child: leading!),
              SizedBox(width: edge),
              actions,
              SizedBox(width: edge),
            ],
          );
        },
      ),
    ).withCollectionActionReach();
  }
}

/// How far a [CollectionActionFrame] below takes taps beyond its circle.
class _CollectionActionSlot extends InheritedWidget {
  const _CollectionActionSlot({
    required this.reach,
    required this.buttonExtent,
    required super.child,
  });

  final EdgeInsets reach;
  final double buttonExtent;

  static _CollectionActionSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CollectionActionSlot>();

  @override
  bool updateShouldNotify(_CollectionActionSlot oldWidget) =>
      reach != oldWidget.reach || buttonExtent != oldWidget.buttonExtent;
}

/// Takes taps and gives screen readers the circle's square grown by [reach]
/// (see [CollectionActionFrame]).
class _ActionTarget extends SingleChildRenderObjectWidget {
  const _ActionTarget({required this.reach, required super.child});

  final EdgeInsets reach;

  @override
  _RenderActionTarget createRenderObject(BuildContext context) =>
      _RenderActionTarget(reach);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActionTarget renderObject,
  ) {
    renderObject.reach = reach;
  }
}

class _RenderActionTarget extends RenderProxyBox {
  _RenderActionTarget(this._reach);

  /// The pointers that went down on a circle ([CollectionActionFrame.isPressing]).
  static final Set<int> _pressing = {};

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pressing.add(event.pointer);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pressing.remove(event.pointer);
    }
  }

  EdgeInsets _reach;
  set reach(EdgeInsets value) {
    if (value == _reach) return;
    _reach = value;
    markNeedsSemanticsUpdate();
  }

  Rect get _target => _reach.inflateRect(Offset.zero & size);

  // The action's node (the button inside, merged) covers the whole target.
  @override
  Rect get semanticBounds => _target;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !_target.contains(position)) return false;
    if (size.contains(position) && child.hitTest(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    // Around the circle (and on its square's corners, outside the clipped
    // circle): the tap goes to the circle's centre.
    final centre = size.center(Offset.zero);
    final hit = result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(centre),
      position: centre,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// A [Row] of [CollectionActionFrame]s that also takes taps in their
/// targets beyond its own bounds ([reach]).
class _ActionRow extends Flex {
  const _ActionRow({
    required this.reach,
    required this.registry,
    required super.direction,
    required super.children,
  }) : super(mainAxisSize: MainAxisSize.min, spacing: CollectionActionRow.gap);

  final EdgeInsets reach;

  /// The [CollectionActionReach] around, if any.
  final Set<_RenderActionRow>? registry;

  @override
  _RenderActionRow createRenderObject(BuildContext context) => _RenderActionRow(
    reach: reach,
    registry: registry,
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: getEffectiveTextDirection(context),
    verticalDirection: verticalDirection,
    textBaseline: textBaseline,
    clipBehavior: clipBehavior,
    spacing: spacing,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderActionRow renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..reach = reach
      ..registry = registry;
  }
}

class _RenderActionRow extends RenderFlex {
  _RenderActionRow({
    required this.reach,
    this._registry,
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
  });

  /// How far beyond its bounds the row takes taps (its ends' targets).
  EdgeInsets reach;

  Set<_RenderActionRow>? _registry;
  set registry(Set<_RenderActionRow>? value) {
    if (identical(value, _registry)) return;
    if (attached) {
      _registry?.remove(this);
      value?.add(this);
    }
    _registry = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry?.add(this);
  }

  @override
  void detach() {
    _registry?.remove(this);
    super.detach();
  }

  /// Whether [position] is in one of the row's targets.
  bool reaches(Offset position) =>
      reach.inflateRect(Offset.zero & size).contains(position);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!reaches(position)) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// The double tap of a card that holds [CollectionActionFrame]s (the star and
/// the "⋮" of a project card, whose double tap opens the canvas).
///
/// A double-tap recognizer holds its pointer's gesture arena after the first
/// tap until [kDoubleTapTimeout] has passed, so a tap on a button inside the
/// card only took effect about 300 ms after it was released. This one does
/// not join the arena of a pointer that went down on one of the circles: the
/// button then wins as soon as it is released. Taps elsewhere on the card
/// (the cover, the name, the band around the circles) still wait for a
/// possible second tap, and two taps there still open the canvas.
class CollectionCardDoubleTapRecognizer extends DoubleTapGestureRecognizer {
  CollectionCardDoubleTapRecognizer({super.debugOwner});

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !CollectionActionFrame.isPressing(event.pointer) &&
      super.isPointerAllowed(event);
}

/// The empty state is a visible, neutral star (the same tone as the save/load
/// action icons), never a blank button. The whole circle is tappable.
///
/// The circle is filled with the card surface (the menu background), so the
/// empty star uses the menu text colour like the card's name and its "⋮"
/// menu, at the muted strength of [ColorScheme.onSurfaceVariant]. The body
/// text colour vanished on themes that pair a dark menu with dark body text.
class CollectionFavoriteButton extends StatelessWidget {
  const CollectionFavoriteButton({
    super.key,
    required this.favorite,
    required this.tooltip,
    required this.onPressed,
    this.itemId,
  });

  final bool favorite;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = theme.popupMenuTheme.iconColor ?? scheme.onSurface;
    return CollectionActionFrame(
      key: itemId == null ? null : Key('collectionFavorite_$itemId'),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: CollectionActionFrame.glyphSize,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: CollectionActionFrame.extent,
          height: CollectionActionFrame.extent,
        ),
        // 色だけで見分けさせない：お気に入りでなければ輪郭だけの星（作品詳細と
        // 同じ。以前はどちらも塗りの星で、違いは色だけだった）。
        icon: Icon(
          favorite ? Icons.star : Icons.star_border,
          color: favorite
              ? AccentTextTheme.of(context)
              : ink.withValues(alpha: ink.a * 0.7),
          size: CollectionActionFrame.glyphSize,
        ),
      ),
    );
  }
}
