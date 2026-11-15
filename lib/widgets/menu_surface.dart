import 'package:flutter/material.dart';

/// メニューの面（メニューの背景色で塗るダイアログ・ボトムシート）の中身に
/// 使うテーマ。
///
/// テーマ・外観では本文の文字色とメニューの文字色を別々に選べる。ダイアログ・
/// シートの下地はメニューの背景色なので、中身の文字・アイコン・入力欄・一覧の
/// 行もメニューの文字色で書く（本文の文字色のままだと、メニューを暗く・本文の
/// 文字を暗くしたテーマで、暗い下地に暗い字で書かれて読めなかった）。
///
/// [data]は、本文の文字色をメニューの文字色に、用紙をメニューの背景色にした
/// テーマ（`ThemeService`が作る）。面の色（`surfaceContainer`等）・線・明暗も
/// メニューの背景色から作るので、シートの中の入れ物も暗い面の上で読める。
/// 本文とメニューの文字色が同じテーマ（組み込みのテーマ）では null で、
/// ダイアログ・シートは画面と同じテーマのまま（見た目は変わらない）。
@immutable
class MenuSurfaceTheme extends ThemeExtension<MenuSurfaceTheme> {
  const MenuSurfaceTheme(this.data);

  final ThemeData? data;

  @override
  MenuSurfaceTheme copyWith({ThemeData? data}) =>
      MenuSurfaceTheme(data ?? this.data);

  @override
  MenuSurfaceTheme lerp(MenuSurfaceTheme? other, double t) {
    if (other == null) return this;
    final a = data;
    final b = other.data;
    if (a == null || b == null) return t < 0.5 ? this : other;
    return MenuSurfaceTheme(ThemeData.lerp(a, b, t));
  }
}

/// [child]をメニューの面のテーマ（[MenuSurfaceTheme]）で描く。テーマに
/// 無ければ（組み込みのテーマ・テストの素のテーマ）何もしない。
class MenuSurface extends StatelessWidget {
  const MenuSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final menu = Theme.of(context).extension<MenuSurfaceTheme>()?.data;
    if (menu == null) return child;
    return Theme(
      data: menu,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: menu.colorScheme.onSurface),
        child: child,
      ),
    );
  }
}

/// 画面（ページ）の移り変わりを Flutter の既定のまま行い、画面の中身の
/// いちばん外側に [_MenuSurfaceRouteScope] を置く。
///
/// ダイアログ（`showDialog`）・ボトムシート（`showModalBottomSheet`）は、
/// 開いた所から画面までの [InheritedTheme] を写して中身を包む
/// （[InheritedTheme.capture]）。画面ごとに置いたこの印も写り、開いた
/// ダイアログ・シートの中身をメニューの面のテーマで描く。呼び出し側
/// （lib配下に約250か所）は何も変えずに、今後足すダイアログ・シートにも効く。
class MenuSurfacePageTransitionsBuilder extends PageTransitionsBuilder {
  const MenuSurfacePageTransitionsBuilder(this.delegate);

  /// 実際の動き（Androidの予測型「戻る」・ズーム・iOSの横すべり）。
  final PageTransitionsBuilder delegate;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegate.delegatedTransition;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => delegate.buildTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    _MenuSurfaceRouteScope(child: child),
  );
}

/// Flutter の既定の移り変わり（端末ごと）を [MenuSurfacePageTransitionsBuilder]
/// で包んだもの。テーマが変わっても同じものを使う（画面の木の形を変えない）。
final PageTransitionsTheme menuSurfacePageTransitionsTheme =
    PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: MenuSurfacePageTransitionsBuilder(
            const PageTransitionsTheme().builders[platform] ??
                const ZoomPageTransitionsBuilder(),
          ),
      },
    );

/// 画面に置く印。画面そのものの見た目は変えず、そこから開いたダイアログ・
/// ボトムシートへ写ったときだけ中身をメニューの面のテーマで包む。
///
/// ポップアップメニュー・ドロップダウンの一覧も同じように写るが、包まない：
/// ポップアップメニューの項目名はテーマ（`popupMenuTheme.labelTextStyle`）で
/// メニューの文字色になっていて、ドロップダウンの一覧は画面の書式で並べて
/// 用紙の色の上に出す（下地だけメニューの面にすると読めなくなる）。
class _MenuSurfaceRouteScope extends InheritedTheme {
  const _MenuSurfaceRouteScope({required super.child});

  @override
  Widget wrap(BuildContext context, Widget child) =>
      _RouteMenuSurface(child: child);

  @override
  bool updateShouldNotify(_MenuSurfaceRouteScope oldWidget) => false;
}

class _RouteMenuSurface extends StatelessWidget {
  const _RouteMenuSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is RawDialogRoute || route is ModalBottomSheetRoute) {
      return MenuSurface(child: child);
    }
    return child;
  }
}
