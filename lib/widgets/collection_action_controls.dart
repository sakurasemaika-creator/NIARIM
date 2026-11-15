import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  static const double glyphSize = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ActionTarget(
      reach:
          _CollectionActionSlot.reachOf(context) ??
          const EdgeInsets.all((targetExtent - extent) / 2),
      child: SizedBox.square(
        dimension: extent,
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
    );
  }
}

/// Collection actions side by side (the star and the "⋮" of a list row),
/// [gap] apart as drawn before. Each gets a 48×48 tap target that does not
/// overlap its neighbour's: the gap is split in the middle and the rest of
/// each target reaches outwards. Replaces a [Row] of frames, which would
/// refuse taps outside its own bounds.
class CollectionActionRow extends StatelessWidget {
  const CollectionActionRow({super.key, required this.children});

  /// The drawn space between two circles.
  static const double gap = 4;

  /// [CollectionActionFrame]s (directly or inside another widget).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    const spare =
        CollectionActionFrame.targetExtent - CollectionActionFrame.extent;
    const inner = gap / 2;
    final count = children.length;
    // The two ends reach outwards so that each end target is 48 across.
    final outer = count == 1 ? spare / 2 : spare - inner;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    EdgeInsets reachAt(int visual) => EdgeInsets.fromLTRB(
      visual == 0 ? outer : inner,
      spare / 2,
      visual == count - 1 ? outer : inner,
      spare / 2,
    );
    return _ActionRow(
      reach: EdgeInsets.fromLTRB(outer, spare / 2, outer, spare / 2),
      registry: _ReachScope.of(context),
      children: [
        for (var i = 0; i < count; i++)
          _CollectionActionSlot(
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

/// How far a [CollectionActionFrame] below takes taps beyond its circle.
class _CollectionActionSlot extends InheritedWidget {
  const _CollectionActionSlot({required this.reach, required super.child});

  final EdgeInsets reach;

  static EdgeInsets? reachOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CollectionActionSlot>()
      ?.reach;

  @override
  bool updateShouldNotify(_CollectionActionSlot oldWidget) =>
      reach != oldWidget.reach;
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
    required super.children,
  }) : super(
         direction: Axis.horizontal,
         mainAxisSize: MainAxisSize.min,
         spacing: CollectionActionRow.gap,
       );

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
        icon: Icon(
          Icons.star,
          color: favorite ? scheme.primary : ink.withValues(alpha: ink.a * 0.7),
          size: CollectionActionFrame.glyphSize,
        ),
      ),
    );
  }
}
