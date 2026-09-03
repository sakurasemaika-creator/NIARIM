import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/ruler.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';

class RulerPanel extends StatelessWidget {
  final Ruler? activeRuler;
  final ValueChanged<Ruler?> onRulerChanged;
  final VoidCallback onClose;
  // 新規定規の初期位置（中心・消失点等）を実際のキャンバスサイズに
  // 合わせて配置するために必要（従来は1920×1080固定を前提にした座標を
  // 直接埋め込んでいたため、それ以外のキャンバスサイズのプロジェクトでは
  // 定規が画面外に配置され「タップしても何も表示されない」状態になって
  // いた）。
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
                  Text(
                    l10n.rulerPanelTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  Spacer(),
                  if (activeRuler != null)
                    TextButton(
                      onPressed: () => onRulerChanged(null),
                      style: TextButton.styleFrom(
                        foregroundColor: ThemeService.activeColorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.commonDelete,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
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
            // 集中線定規の分割数設定（2〜360分割を自由指定）
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
      onRulerChanged(
        r.copyWith(settings: r.settings.copyWith(divisions: clamped)),
      );
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
            onPressed: () => update(divisions + 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: isActive ? primary : null),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          color: isActive ? primary : null,
        ),
      ),
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

  /// 新規定規の初期配置。元々は1920×1080キャンバスを基準に設計された
  /// 絶対座標（中心(960,540)・消失点(200,540)等）だったため、実際の
  /// キャンバスサイズ（`canvasWidth`・`canvasHeight`。プロジェクトの
  /// キャンバスサイズ設定や描画領域倍率により1920×1080以外にもなり得る）
  /// に対する比率でスケーリングし、どのキャンバスサイズでも定規が
  /// キャンバス内に収まる位置に配置されるようにする。
  Ruler _defaultRuler(RulerType type) {
    final sx = canvasWidth / 1920.0;
    final sy = canvasHeight / 1080.0;
    final center = Offset(canvasWidth / 2, canvasHeight / 2);
    return switch (type) {
      RulerType.line => Ruler(
        type: type,
        position: center,
        settings: const RulerSettings(),
      ),
      RulerType.ellipse => Ruler(
        type: type,
        position: center,
        settings: RulerSettings(radiusX: 200 * sx, radiusY: 120 * sy),
      ),
      RulerType.radial => Ruler(
        type: type,
        position: center,
        settings: const RulerSettings(divisions: 12),
      ),
      RulerType.onePointPerspective => Ruler(
        type: type,
        position: center,
        settings: RulerSettings(vanishingPoint1: center),
      ),
      RulerType.twoPointPerspective => Ruler(
        type: type,
        position: center,
        settings: RulerSettings(
          vanishingPoint1: Offset(200 * sx, 540 * sy),
          vanishingPoint2: Offset(1720 * sx, 540 * sy),
        ),
      ),
      RulerType.threePointPerspective => Ruler(
        type: type,
        position: center,
        settings: RulerSettings(
          vanishingPoint1: Offset(200 * sx, 540 * sy),
          vanishingPoint2: Offset(1720 * sx, 540 * sy),
          vanishingPoint3: Offset(960 * sx, 100 * sy),
        ),
      ),
      _ => Ruler(type: type, position: center, settings: const RulerSettings()),
    };
  }
}
