import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// 画面下の知らせ（トースト＝SnackBar）が、初めて描かれてから消え切るまでの
/// 上限（出てくる途中で描画が止まっていた間は数えない）。
const Duration kToastMaxLifetime = Duration(seconds: 5);

/// 出てくるのにかかる時間（SnackBarの既定のまま）。
const Duration kToastEntrance = Duration(milliseconds: 250);

/// 消えるときに少しずつ薄くなる時間。
///
/// 60Hzで24フレーム、1フレームに約4%ずつ薄くなる。Flutterの既定は
/// 250msのうち約50msで消えるので「突然消える」と見え、これより長いと
/// 5秒の中で読める時間を削り、次の知らせも待たせる。
const Duration kToastFadeOut = Duration(milliseconds: 400);

/// 次の知らせが待っているときに薄くなる時間（待たせる時間を既定の250msに
/// 近づける）。
const Duration kToastFadeOutWhenReplaced = Duration(milliseconds: 300);

/// 出切ったまま見せておく時間の上限。出てくる250ms＋この時間＋薄くなる
/// 400msに、タイマーと描画のずれの分を足して[kToastMaxLifetime]に収まる。
const Duration kToastLongestShown = Duration(milliseconds: 4250);

/// アプリの知らせ（SnackBar）を1か所で受ける[ScaffoldMessenger]。
///
/// `MaterialApp.builder`の中で、画面（Navigator）を包む位置に置く。画面・
/// ダイアログ・シートの`ScaffoldMessenger.of(context)`も、[key]に渡した
/// グローバルキーも、awaitの前に取っておいたメッセンジャーも、すべてこれを
/// 指すので、呼び出し側が何も書かなくても次の決まりで動く。
///
/// * 初めて描かれてから[kToastMaxLifetime]以内に自分で消える。操作ボタンが
///   あっても（[SnackBar.persist]の既定は「操作ボタンがあれば消えない」）、
///   長い[SnackBar.duration]・`persist: true`を渡しても同じ。短い指定は
///   そのまま。時間は出切ったときから数えるので、出てくる前・出てくる
///   途中にアプリが裏へ回ったり描画が止まったりしても、見ないうちには
///   消えない（戻って出切ってから数える）。
/// * 消えるときは[kToastFadeOut]かけて少しずつ薄くなる（時間切れ・操作
///   ボタン・`hideCurrentSnackBar`・`removeCurrentSnackBar`・
///   `clearSnackBars`・次の知らせへの入れ替え）。スワイプで払ったときは、
///   指の動きで画面の外へ出ているのでその場で消える。
/// * 「隠して出す」「すぐ消して出す」（`hideCurrentSnackBar`・
///   `removeCurrentSnackBar`の直後に`showSnackBar`）を、前の知らせが薄く
///   なっている途中でもう一度行うと、その途中で入れ替えとして並んだだけで
///   まだ出ていない知らせは出さずに下げる（押した数だけ順に出し直さず、
///   最後のものだけが出る。素の`removeCurrentSnackBar`がその場で入れ替える
///   のと同じ結果）。隠す・すぐ消すだけで後に何も出さないとき、入れ替え
///   ではなく後ろに並んだ知らせ（失敗の知らせ等）、薄くなる前から並んで
///   いた知らせは下げない。
/// * 「動きを減らす」設定ではアニメーションなしで消える。読み上げ・
///   スイッチ操作（accessibleNavigation）でもアニメーションなしで、Flutterが
///   残す知らせ（操作ボタン付きで`persist`を指定していないもの）だけは、
///   押す・閉じる・次の知らせが来るまで残す（ボタンへたどり着くのに時間が
///   かかるため。5秒を超えるのはこのときだけ）。`persist: false`を付けた
///   知らせは、素のメッセンジャーと同じく時間で消える。
///
/// 文・書体・色・位置・操作ボタン・読み上げ・1つずつ順に出す並びは、
/// 素の[ScaffoldMessenger]のまま。
class AppToastMessenger extends ScaffoldMessenger {
  const AppToastMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => AppToastMessengerState();
}

class AppToastMessengerState extends ScaffoldMessengerState {
  /// 消えるときの不透明度（1.0＝出ている、0.0＝消え切った）。消えるとき
  /// だけ動かす。
  late final AnimationController _exit;

  /// 基底クラスが出すときに使うアニメーション（[SnackBar.withAnimation]で
  /// 受け取る）。値が0で止まっている＝画面に知らせが無い。
  Animation<double>? _entrance;

  /// 基底クラスの待ち行列と同じ並び（先頭が出ている知らせ）。
  final Queue<_Queued> _toasts = Queue<_Queued>();

  /// 消えている途中の知らせの、消える理由。
  SnackBarClosedReason? _leaving;

  /// いま薄くなっている知らせの番号（薄くなり始めるたびに増やす）。その
  /// 途中で入れ替えとして並んだ知らせに付ける。
  int _fade = 0;

  /// いま走っている処理の中で、アプリのコードが知らせを隠した・すぐ消した
  /// （この後に出す知らせは、その入れ替え）。次のマイクロタスクで戻す。
  bool _replacing = false;

  /// 読み上げの利用者のために、時間が来ても残しているか。
  bool _heldForAssistiveUse = false;

  /// 出ている知らせの期限。出切ったフレーム（出てくるアニメーションが
  /// 終わったとき）から数える。基底クラスのタイマーは出切った後のビルドで
  /// 始まり、描画が飛ぶとその分だけ遅れる。初めて描かれたフレームから
  /// 数えると、出てくる途中でアプリが裏へ回った・描画が止まったとき、
  /// 見ないうちに期限が来て消えていた。
  Timer? _deadline;

  bool _assistiveUse = false;
  bool _noMotion = false;

  bool get _onScreen => _entrance != null && !_entrance!.isDismissed;

  @override
  void initState() {
    super.initState();
    _exit = AnimationController(vsync: this, value: 1.0)
      ..addStatusListener(_onExitStatus);
  }

  @override
  Widget build(BuildContext context) {
    _assistiveUse = MediaQuery.accessibleNavigationOf(context);
    _noMotion = _assistiveUse || MediaQuery.disableAnimationsOf(context);
    if (_heldForAssistiveUse && !_assistiveUse) {
      // 読み上げをやめたら、残していた知らせも時間切れとして消す。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _heldForAssistiveUse && !_assistiveUse) {
          _heldForAssistiveUse = false;
          hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
        }
      });
    }
    return super.build(context);
  }

  /// [snackBarAnimationStyle]は使わない（基底クラスは、指定が前と違うと
  /// 出ている知らせのアニメーションごと作り直し、その知らせが消えなくなる）。
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final queued = _toasts.length;
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    try {
      controller = super.showSnackBar(_Toast.from(snackBar, this));
    } catch (_) {
      // 組み立ての最中に呼ばれた等で基底クラスが入れなかった知らせを、
      // こちらの並びからも外す。
      while (_toasts.length > queued) {
        _toasts.removeLast();
      }
      rethrow;
    }
    if (_toasts.last.replacesIn != null) {
      // いま薄くなっている知らせの入れ替えとして先に並んだ知らせを
      // 追い越した。それらは出る前に下げる（[_removeNow]）。
      for (final waiting in _toasts.take(queued).skip(1)) {
        if (waiting.replacesIn == _fade) waiting.overtaken = true;
      }
    }
    // 先頭に出す知らせなら、期限は出切ってから数える（[_onEntranceStatus]）。
    if (_toasts.length > 1) {
      if (_heldForAssistiveUse) {
        // 残していた知らせの後ろで、次の知らせを待たせ続けない。
        hideCurrentSnackBar();
      } else if (_exit.isAnimating) {
        // 薄くなっている途中の知らせを急がせる。
        _startExit();
      }
    }
    return controller;
  }

  @override
  void hideCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.hide,
  }) {
    if (reason == SnackBarClosedReason.hide ||
        reason == SnackBarClosedReason.remove) {
      // 時間切れ・操作ボタン・閉じるボタンは入れ替えではない。
      _noteReplacing();
    }
    if (!_onScreen) return;
    // もう薄くなっている。待っている知らせはそのまま出す（後に出す知らせが
    // 入れ替えなら、[showSnackBar]が追い越した分だけを下げる）。
    if (_leaving != null) return;
    if (reason == SnackBarClosedReason.timeout &&
        _assistiveUse &&
        _toasts.length == 1 &&
        _toasts.first.toast.keptForAssistiveUse) {
      _heldForAssistiveUse = true;
      return;
    }
    if (_noMotion) {
      _removeNow(reason);
      return;
    }
    final entrance = _entrance!;
    final shown = _ToastAnimation.drawnOpacity.transform(entrance.value);
    if (shown <= 0.0) {
      // まだ見えていない。
      _removeNow(reason);
      return;
    }
    _leaving = reason;
    _fade++;
    if (shown < 1.0) {
      // 出てくる途中。いま見えている濃さから薄くする（出切るのを待つと、
      // すぐ消すはずの知らせが一度はっきり見える）。
      _exit.value = shown;
      _startExit();
    } else if (entrance.isCompleted) {
      _startExit();
    }
    // 濃さは出切っていて高さだけ伸びている途中（100ms以内）は、伸び切って
    // から薄くする（[_onEntranceStatus]）。途中で薄くし始めると高さが跳ぶ。
  }

  /// アプリのコードからの「すぐ消す」も、薄くして消す。スワイプと読み上げの
  /// 「閉じる」は、その場で消す。
  @override
  void removeCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.remove,
  }) {
    if (reason == SnackBarClosedReason.remove) {
      hideCurrentSnackBar(reason: reason);
    } else if (_onScreen) {
      _removeNow(reason);
    }
  }

  @override
  void clearSnackBars() {
    if (!_onScreen) return;
    while (_toasts.length > 1) {
      _toasts.removeLast();
    }
    super.clearSnackBars();
  }

  void _noteReplacing() {
    if (_replacing) return;
    _replacing = true;
    scheduleMicrotask(() => _replacing = false);
  }

  void _startExit() {
    final whole = _toasts.length > 1
        ? kToastFadeOutWhenReplaced
        : kToastFadeOut;
    _exit.animateBack(0.0, duration: whole * _exit.value);
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (!status.isCompleted) return;
    if (_leaving != null) {
      if (!_exit.isAnimating) _startExit();
      return;
    }
    _armDeadline();
  }

  void _onExitStatus(AnimationStatus status) {
    final reason = _leaving;
    if (status.isDismissed && reason != null) _removeNow(reason);
  }

  void _removeNow(SnackBarClosedReason reason) {
    _leaving = null;
    _heldForAssistiveUse = false;
    _exit.value = 1.0;
    // 消した知らせは、画面の切り替え（Hero）の途中で残っている絵も含めて、
    // 次の知らせの出てくる動きに引きずられて濃くならないようにする。
    if (_toasts.isNotEmpty) _toasts.removeFirst().animation.retire();
    // 基底クラスは、ここで待っていた次の知らせを出し始める。
    super.removeCurrentSnackBar(reason: reason);
    // 追い越された入れ替えは、見える前にその場で下げる（素の
    // removeCurrentSnackBarで入れ替えたときと同じく、閉じた理由はremove）。
    while (_toasts.isNotEmpty && _toasts.first.overtaken) {
      _toasts.removeFirst().animation.retire();
      super.removeCurrentSnackBar();
    }
    // 次の知らせの期限は、それが出切ってから数える（[_onEntranceStatus]）。
    _deadline?.cancel();
    _deadline = null;
  }

  /// 出切った先頭の知らせの期限を数え始める。
  void _armDeadline() {
    _deadline?.cancel();
    _deadline = null;
    if (_toasts.isEmpty) return;
    final toast = _toasts.first;
    _deadline = Timer(toast.toast.duration, () {
      if (!mounted || _toasts.isEmpty || !identical(_toasts.first, toast)) {
        return;
      }
      hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    });
  }

  /// 基底クラスが[toast]を待ち行列へ入れる直前に呼ばれる。
  Animation<double> _enqueue(_Toast toast, Animation<double> entrance) {
    if (!identical(entrance, _entrance)) {
      _entrance?.removeStatusListener(_onEntranceStatus);
      _entrance = entrance..addStatusListener(_onEntranceStatus);
    }
    final animation = _ToastAnimation(entrance, _exit);
    _toasts.addLast(
      _Queued(
        toast,
        animation,
        replacesIn: _replacing && _leaving != null ? _fade : null,
      ),
    );
    return animation;
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _entrance?.removeStatusListener(_onEntranceStatus);
    _exit.dispose();
    super.dispose();
  }
}

/// 決まり（時間で消える・出ている時間の上限）に合わせた[SnackBar]。
///
/// [SnackBar]の引数をすべて写す。Flutterが引数を足したら、ここにも足す
/// （`test/app_toast_messenger_test.dart`が引数の一覧を見張る）。
class _Toast extends SnackBar {
  const _Toast._(
    this._messenger, {
    super.key,
    required super.content,
    super.backgroundColor,
    super.elevation,
    super.margin,
    super.padding,
    super.width,
    super.shape,
    super.hitTestBehavior,
    super.behavior,
    super.action,
    super.actionOverflowThreshold,
    super.showCloseIcon,
    super.closeIconColor,
    required super.duration,
    super.onVisible,
    super.dismissDirection,
    required super.clipBehavior,
    required this.keptForAssistiveUse,
  }) : super(persist: false);

  factory _Toast.from(SnackBar source, AppToastMessengerState messenger) {
    return _Toast._(
      messenger,
      keptForAssistiveUse: source.persist && source.action != null,
      key: source.key,
      content: source.content,
      backgroundColor: source.backgroundColor,
      elevation: source.elevation,
      margin: source.margin,
      padding: source.padding,
      width: source.width,
      shape: source.shape,
      hitTestBehavior: source.hitTestBehavior,
      behavior: source.behavior,
      action: source.action,
      actionOverflowThreshold: source.actionOverflowThreshold,
      showCloseIcon: source.showCloseIcon,
      closeIconColor: source.closeIconColor,
      duration: source.duration > kToastLongestShown
          ? kToastLongestShown
          : source.duration,
      onVisible: source.onVisible,
      dismissDirection: source.dismissDirection,
      clipBehavior: source.clipBehavior,
    );
  }

  final AppToastMessengerState _messenger;

  /// 読み上げ・スイッチ操作の利用者には、時間が来ても残す知らせか。
  /// Flutterが残すもの（操作ボタン付きで`persist`を指定していない、または
  /// `persist: true`）だけ。`persist: false`を付けた知らせは時間で消える。
  final bool keptForAssistiveUse;

  // 基底クラスが、出す前に自分のアニメーションを渡してくる。ツリーに入る
  // のは、ここで返る素のSnackBar。
  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    return super.withAnimation(
      _messenger._enqueue(this, newAnimation),
      fallbackKey: fallbackKey,
    );
  }
}

/// SnackBarへ渡すアニメーション。出るときは基底クラスのアニメーションの
/// まま、消えるときは[_exit]の値どおりの不透明度で描かれる値を返す。
///
/// Material 3の浮かぶSnackBarは、アニメーションの値を
/// `Interval(0.4, 0.6, curve: Curves.easeInCirc)`へ通した不透明度で描かれ
/// （消えるときも同じ曲線を逆にたどるので、250msのうち約50msで消え、
/// その後100msは見えないまま残る）、状態が`reverse`の間は高さを変えない。
/// 消える間は、出したい不透明度になる値をその曲線から逆算して渡す。
/// 不透明度を描くのはSnackBar自身なので、画面の切り替えの途中（Hero）でも
/// 同じ濃さで描かれる。
class _ToastAnimation extends Animation<double>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  _ToastAnimation(this._entrance, this._exit);

  final Animation<double> _entrance;
  final Animation<double> _exit;
  AnimationStatus? _reported;

  /// 知らせが消し終わった（以後は見えないまま）。
  bool _retired = false;

  void retire() {
    if (_retired) return;
    _retired = true;
    _changed();
  }

  /// FlutterのSnackBar（Material 3・浮かぶ）が不透明度に使う曲線の写し。
  static const Curve drawnOpacity = Interval(
    0.4,
    0.6,
    curve: Curves.easeInCirc,
  );

  bool get _leaving => _exit.value < 1.0 && !_entrance.isDismissed;

  @override
  AnimationStatus get status {
    if (_retired) return AnimationStatus.dismissed;
    return _leaving ? AnimationStatus.reverse : _entrance.status;
  }

  @override
  double get value {
    if (_retired) return 0.0;
    if (!_leaving) return _entrance.value;
    final opacity = _exit.value;
    // 単調に増える曲線なので、二分法で逆算する。
    var low = 0.4;
    var high = 0.6;
    for (var i = 0; i < 24; i++) {
      final middle = (low + high) / 2;
      if (drawnOpacity.transform(middle) < opacity) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return high;
  }

  void _changed() {
    _statusChanged(status);
    notifyListeners();
  }

  void _statusChanged(AnimationStatus _) {
    final now = status;
    if (now == _reported) return;
    _reported = now;
    notifyStatusListeners(now);
  }

  @override
  void didStartListening() {
    _reported = status;
    _entrance
      ..addListener(_changed)
      ..addStatusListener(_statusChanged);
    _exit.addListener(_changed);
  }

  @override
  void didStopListening() {
    _entrance
      ..removeListener(_changed)
      ..removeStatusListener(_statusChanged);
    _exit.removeListener(_changed);
  }
}

/// 待ち行列の1件：知らせと、それを描くアニメーション。
class _Queued {
  _Queued(this.toast, this.animation, {required this.replacesIn});

  final _Toast toast;
  final _ToastAnimation animation;

  /// 薄くなっている知らせの入れ替え（隠す・すぐ消すの直後に出した）として
  /// 並んだなら、その薄くなる番号（[AppToastMessengerState._fade]）。
  final int? replacesIn;

  /// 同じ薄くなる途中の、後の入れ替えに追い越された（出さずに下げる）。
  bool overtaken = false;
}
