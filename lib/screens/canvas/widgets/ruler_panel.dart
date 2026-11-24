import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/ruler.dart';
import '../../../widgets/docked_panel_scope.dart';
import '../../../widgets/list_ink_clip.dart';
import 'neutral_list_icons.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../config/accent_text_theme.dart';

class RulerPanel extends StatelessWidget {
  final Ruler? activeRuler;
  final ValueChanged<Ruler?> onRulerChanged;
  final VoidCallback onClose;
  final int canvasWidth;
  final int canvasHeight;

  const RulerPanel({
    super.key,
    required this.activeRuler,
    required this.onRulerChanged,
    required this.onClose,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 文字を大きくしたときは幅も広げる（200pxのままでは文字2倍で
    // 「One-Point Pe / rspectiv / e」と語の途中で折れた）。画面の幅は超えない。
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(
      math.max(200.0, MediaQuery.textScalerOf(context).scale(200)),
      math.max(200.0, screenWidth - 32),
    );
    // 下地・角は他の浮かぶパネル（ペン・オニオンスキン・早替えツール）と
    // 同じカード（以前はこのパネルだけ灰色の面・角8で、別の部品に見えた）。
    return PanelSurface(
      width: width,
      // On a short screen (or with large text) the list scrolls instead of
      // running off the bottom.
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeaderRow(
            onClose: onClose,
            title: Text(
              l10n.rulerPanelTitle,
              style: localizedHeadingStyle(
                context,
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            actions: [
              if (activeRuler != null)
                TextButton(
                  onPressed: () => onRulerChanged(null),
                  // 上下の余白が0なので、行の外へ出る字（「Supprimer」の
                  // p等）が面の縁にかかる。テーマのラベルの余白の仕組みで
                  // 既定になる面の切り抜きをしない。
                  clipBehavior: Clip.none,
                  // 押せる所は48×48（以前は字11pxの約36×20pxで、押し損ねや
                  // 押し間違いで確かめずに定規が消えた）。
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(
                    l10n.commonDelete,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          if (activeRuler != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.rulerSnap,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('ruler-snap-switch'),
                    value: activeRuler!.snapEnabled,
                    onChanged: (value) => onRulerChanged(
                      activeRuler!.copyWith(snapEnabled: value),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          // 選んだ行の背景を一覧の外（上のスイッチ・見出し）へはみ出させない
          // （末尾のclipListInk）。
          Flexible(
            child: SingleChildScrollView(
              child: NeutralListIcons(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _rulerTile(
                      context,
                      RulerType.line,
                      Icons.straighten,
                      l10n.rulerTypeLine,
                    ),
                    _rulerTile(
                      context,
                      RulerType.ellipse,
                      Icons.circle_outlined,
                      l10n.rulerTypeEllipse,
                    ),
                    _rulerTile(
                      context,
                      RulerType.radial,
                      Icons.hub_outlined,
                      l10n.rulerTypeRadial,
                    ),
                    const Divider(height: 1),
                    _rulerTile(
                      context,
                      RulerType.onePointPerspective,
                      Icons.filter_center_focus,
                      l10n.rulerTypeOnePoint,
                    ),
                    _rulerTile(
                      context,
                      RulerType.twoPointPerspective,
                      Icons.compare_arrows,
                      l10n.rulerTypeTwoPoint,
                    ),
                    _rulerTile(
                      context,
                      RulerType.threePointPerspective,
                      Icons.grid_3x3,
                      l10n.rulerTypeThreePoint,
                    ),
                    _rulerTile(
                      context,
                      RulerType.fisheyePerspective,
                      Icons.language,
                      l10n.rulerTypeFisheye,
                    ),
                    if (activeRuler?.type == RulerType.radial) ...[
                      const Divider(height: 1),
                      _divisionsRow(context),
                    ],
                  ],
                ),
              ),
            ).clipListInk(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _divisionsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final r = activeRuler!;
    final divisions = r.settings.divisions ?? 12;
    void update(int newDivisions) {
      final clamped = newDivisions.clamp(2, 360);
      onRulerChanged(
        r.copyWith(settings: r.settings.copyWith(divisions: clamped)),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.rulerDivisions,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // 押せる所は40×40（以前は印の大きさ16pxだけで、押し損ねた）。
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            tooltip: l10n.commonDecrease,
            onPressed: divisions > 2 ? () => update(divisions - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$divisions',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            tooltip: l10n.commonIncrease,
            onPressed: divisions < 360 ? () => update(divisions + 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _rulerTile(
    BuildContext context,
    RulerType type,
    IconData icon,
    String label,
  ) {
    final isActive = activeRuler?.type == type;
    final primary = Theme.of(context).colorScheme.primary;
    final accentText = AccentTextTheme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: isActive ? accentText : null),
      title: Text(
        label,
        style: localizedHeadingStyle(
          context,
          TextStyle(fontSize: 12, color: isActive ? accentText : null),
        ),
      ),
      selected: isActive,
      selectedTileColor: primary.withValues(alpha: 0.1),
      onTap: () {
        if (isActive) {
          onRulerChanged(null);
        } else {
          // Snap is a user mode, not a ruler-type default. Carry it across type
          // changes so line -> perspective etc. never silently turns snapping on.
          onRulerChanged(
            _defaultRuler(type, snapEnabled: activeRuler?.snapEnabled ?? true),
          );
        }
        onClose();
      },
    );
  }

  Ruler _defaultRuler(RulerType type, {required bool snapEnabled}) {
    final sx = canvasWidth / 1920.0;
    final sy = canvasHeight / 1080.0;
    final center = Offset(canvasWidth / 2, canvasHeight / 2);
    Ruler make(RulerSettings settings) => Ruler(
      type: type,
      position: center,
      snapEnabled: snapEnabled,
      settings: settings,
    );
    return switch (type) {
      RulerType.line => make(const RulerSettings()),
      RulerType.ellipse => make(
        RulerSettings(radiusX: 200 * sx, radiusY: 120 * sy),
      ),
      RulerType.radial => make(const RulerSettings(divisions: 12)),
      RulerType.onePointPerspective => make(
        RulerSettings(vanishingPoint1: center),
      ),
      RulerType.twoPointPerspective => make(
        RulerSettings(
          vanishingPoint1: Offset(200 * sx, 540 * sy),
          vanishingPoint2: Offset(1720 * sx, 540 * sy),
        ),
      ),
      RulerType.threePointPerspective => make(
        RulerSettings(
          vanishingPoint1: Offset(200 * sx, 540 * sy),
          vanishingPoint2: Offset(1720 * sx, 540 * sy),
          vanishingPoint3: Offset(960 * sx, 100 * sy),
        ),
      ),
      // The lens fills most of the canvas's shorter side.
      RulerType.fisheyePerspective => make(
        RulerSettings(radiusX: math.min(canvasWidth, canvasHeight) * 0.45),
      ),
      _ => make(const RulerSettings()),
    };
  }
}
