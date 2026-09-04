import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';

/// 筆圧カーブの「試し書きコーナー」：適用前に
/// 実際にこの設定で描いてみて、太さの変化を確認できる小さな描画エリア。
/// スタイラス使用時は実際の筆圧を反映し、タッチ・マウスは筆圧情報を
/// 持たないため一定の太さで描画される。
class PressureCurveTryDraw extends StatefulWidget {
  const PressureCurveTryDraw({super.key});

  @override
  State<PressureCurveTryDraw> createState() => _PressureCurveTryDrawState();
}

class _PressureCurveTryDrawState extends State<PressureCurveTryDraw> {
  // nullは「ここでストロークが途切れる」区切りを表す。
  final List<Offset?> _points = [];
  final List<double> _pressures = [];

  void _addPoint(PointerEvent event) {
    setState(() {
      _points.add(event.localPosition);
      _pressures.add(
        event.kind == PointerDeviceKind.stylus
            ? event.pressure.clamp(0.0, 1.0)
            : 1.0,
      );
    });
  }

  void _endStroke() {
    setState(() {
      _points.add(null);
      _pressures.add(0);
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
      _pressures.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.pressureTryDrawHint,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: _points.isEmpty ? null : _clear,
              child: Text(l10n.pressureTryDrawClear),
            ),
          ],
        ),
        Listener(
          onPointerDown: _addPoint,
          onPointerMove: _addPoint,
          onPointerUp: (_) => _endStroke(),
          onPointerCancel: (_) => _endStroke(),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _TryDrawPainter(
                  points: _points,
                  pressures: _pressures,
                  curve: settings.applyPressureCurve,
                  color: scheme.primary,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TryDrawPainter extends CustomPainter {
  final List<Offset?> points;
  final List<double> pressures;
  final double Function(double) curve;
  final Color color;

  _TryDrawPainter({
    required this.points,
    required this.pressures,
    required this.curve,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      if (p0 == null || p1 == null) continue;
      final pressure = curve(pressures[i + 1]).clamp(0.05, 1.0);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2 + pressure * 14
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p0, p1, paint);
    }
  }

  @override
  // ここは`true`で正しい。[points]・[pressures]は呼び出し側が同じListの
  // インスタンスを`add`/`clear`で直接書き換えて渡してくるため、
  // `old.points != points`のような比較にすると**常にfalse**になり、
  // 描いても線が出なくなる。「常にtrueは無駄」という一般則に引きずられて
  // 比較へ変えないこと（変えるなら、呼び出し側を毎回新しいListを作る形に
  // 直すのが先）。この図はペン入力設定の小さな試し描き欄で、親が再ビルド
  // されるのは操作中だけなので、毎回描き直しても実害は無い。
  bool shouldRepaint(covariant _TryDrawPainter old) => true;
}
