import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 起動時のスプラッシュ画面。ロゴを約2秒間表示してからプロジェクト一覧
/// （ホーム画面）へ自動遷移する。
///
/// ロゴ画像は未完成のため、現時点では単色のプレースホルダー画像
/// （assets/logo/splash_logo.png）を表示している。本番ロゴが用意でき
/// 次第、同じファイル名・パスへ差し替えるだけでよい（コード変更不要）。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _displayDuration = Duration(seconds: 2);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_displayDuration, () {
      if (!mounted) return;
      // 履歴に残さず置き換える（戻るボタンでスプラッシュへ戻らないようにする）
      context.go('/home');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Image.asset(
          'assets/logo/splash_logo.png',
          width: 160,
          height: 160,
        ),
      ),
    );
  }
}
