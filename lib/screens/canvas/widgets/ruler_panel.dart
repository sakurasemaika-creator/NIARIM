import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/ruler.dart';
import 'panel_close_bar.dart';

class RulerPanel extends StatelessWidget {
  final Ruler? activeRuler;
  final ValueChanged<Ruler?> onRulerChanged;
  final VoidCallback onClose;

  const RulerPanel({
    super.key,
    required this.activeRuler,
    required this.onRulerChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelCenterCloseBar(onClose: onClose),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(l10n.rulerPanelTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  if (activeRuler != null)
                    TextButton(
                      onPressed: () => onRulerChanged(null),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.commonDelete, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _rulerTile(context, RulerType.line,                  Icons.straighten,        l10n.rulerTypeLine),
            _rulerTile(context, RulerType.ellipse,               Icons.circle_outlined,   l10n.rulerTypeEllipse),
            _rulerTile(context, RulerType.radial,                Icons.hub_outlined,      l10n.rulerTypeRadial),
            const Divider(height: 1),
            _rulerTile(context, RulerType.onePointPerspective,   Icons.filter_center_focus, l10n.rulerTypeOnePoint),
            _rulerTile(context, RulerType.twoPointPerspective,   Icons.compare_arrows,    l10n.rulerTypeTwoPoint),
            _rulerTile(context, RulerType.threePointPerspective, Icons.grid_3x3,          l10n.rulerTypeThreePoint),
            // 集中線定規の分割数設定（仕様書14：2〜360分割を自由指定）
            if (activeRuler?.type == RulerType.radial) ...[
              const Divider(height: 1),
              _divisionsRow(context),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _divisionsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final r = activeRuler!;
    final divisions = r.settings.divisions ?? 12;
    void update(int newDivisions) {
      final clamped = newDivisions.clamp(2, 360);
      onRulerChanged(r.copyWith(settings: r.settings.copyWith(divisions: clamped)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(l10n.rulerDivisions, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            tooltip: l10n.commonDecrease,
            onPressed: () => update(divisions - 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 28, child: Text('$divisions', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            tooltip: l10n.commonIncrease,
            onPressed: () => update(divisions + 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _rulerTile(BuildContext context, RulerType type, IconData icon, String label) {
    final isActive = activeRuler?.type == type;
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: isActive ? primary : null),
      title: Text(label, style: TextStyle(fontSize: 12, color: isActive ? primary : null)),
      selected: isActive,
      selectedTileColor: primary.withValues(alpha: 0.1),
      onTap: () {
        if (isActive) {
          onRulerChanged(null);
        } else {
          onRulerChanged(_defaultRuler(type));
        }
        onClose();
      },
    );
  }

  Ruler _defaultRuler(RulerType type) {
    final center = const Offset(960, 540); // キャンバス中央
    return switch (type) {
      RulerType.line => Ruler(
          type: type, position: center,
          settings: const RulerSettings()),
      RulerType.ellipse => Ruler(
          type: type, position: center,
          settings: const RulerSettings(radiusX: 200, radiusY: 120)),
      RulerType.radial => Ruler(
          type: type, position: center,
          settings: const RulerSettings(divisions: 12)),
      RulerType.onePointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(vanishingPoint1: center)),
      RulerType.twoPointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(
            vanishingPoint1: const Offset(200, 540),
            vanishingPoint2: const Offset(1720, 540),
          )),
      RulerType.threePointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(
            vanishingPoint1: const Offset(200, 540),
            vanishingPoint2: const Offset(1720, 540),
            vanishingPoint3: const Offset(960, 100),
          )),
      _ => Ruler(type: type, position: center, settings: const RulerSettings()),
    };
  }
}
