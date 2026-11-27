import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/project_service.dart';

/// 別の画面に覆われて見えていない間は、作品の変更の知らせを中の部品へ
/// 届けず、見えるようになったときに1回だけ届ける。
///
/// 画面を積んで開く（ホーム→キャンバス）と、下の画面は見えないまま木に
/// 残る。作品の変更（レイヤー・コマ・取り消し）を知らせるたびに、見えない
/// ホームの一覧まで組み立て直していた（キャンバスで1回変えるごとに約2400の
/// 部品）。見えるようになるのは戻る動きが始まる時で、そのフレームの組み立て
/// の中で届けるので、表示されるのはいつも最新の内容。
///
/// 覆われているかは、覆われた画面の部品が止められる[TickerMode]で見る
/// （上の画面が不透明になってから。開く・戻る動きの間は見えている）。
/// 中の部品は今までどおり`context.watch<ProjectService>()`等で読む。
class HiddenRouteProjectGate extends StatefulWidget {
  const HiddenRouteProjectGate({super.key, required this.child});

  final Widget child;

  @override
  State<HiddenRouteProjectGate> createState() => _HiddenRouteProjectGateState();
}

class _HiddenRouteProjectGateState extends State<HiddenRouteProjectGate> {
  ValueListenable<TickerModeData>? _ticker;
  InheritedContext<ProjectService?>? _provider;
  bool _changedWhileHidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticker = TickerMode.getValuesNotifier(context);
    if (!identical(ticker, _ticker)) {
      _ticker?.removeListener(_visibilityChanged);
      _ticker = ticker..addListener(_visibilityChanged);
      _visibilityChanged();
    }
  }

  bool get _visible => _ticker?.value.enabled ?? true;

  void _visibilityChanged() {
    if (!_changedWhileHidden || !_visible) return;
    _changedWhileHidden = false;
    _provider?.markNeedsNotifyDependents();
  }

  VoidCallback _startListening(
    InheritedContext<ProjectService?> element,
    ProjectService service,
  ) {
    _provider = element;
    void changed() {
      if (_visible) {
        element.markNeedsNotifyDependents();
      } else {
        _changedWhileHidden = true;
      }
    }

    service.addListener(changed);
    return () {
      service.removeListener(changed);
      if (identical(_provider, element)) _provider = null;
    };
  }

  @override
  void dispose() {
    _ticker?.removeListener(_visibilityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 作品のサービスそのものが替わったとき（出荷時の状態に戻す等）だけ
    // 組み立て直す。中身の変更は下の[_startListening]が届ける。
    final service = context.select<ProjectService, ProjectService>(
      (service) => service,
    );
    return InheritedProvider<ProjectService>.value(
      value: service,
      startListening: _startListening,
      child: widget.child,
    );
  }
}
