import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// アプリ内で発生した「画面が壊れる種類のエラー」を握りつぶさず、
/// ユーザーの目に見える形にするための仕組み。
///
/// 【なぜ必要か】
/// Flutterはウィジェットの`build()`が例外を投げると`ErrorWidget`へ差し替える。
/// デバッグビルドでは赤いエラー画面だが、**リリースビルドの既定の
/// ErrorWidgetは「文字が何も出ない灰色（実質まっさら）のボックス」**である。
/// 画面の上位で例外が出ると画面全体がそれになるため、ユーザーからは
/// 「画面が真っ白になった」としか見えず、しかも既定では
/// `FlutterError.onError`も何も記録しないので、原因の手がかりが
/// アプリ側にもユーザー側にも一切残らない。
///
/// 実際に「セーブツリーから保存するボタンをタップすると画面が真っ白に
/// なる」という報告があった際、開発環境（実機なし）では再現できず、
/// ユーザーの画面にも何の情報も出ていないため原因を特定できなかった。
/// そこで、白紙になる代わりに「何が起きたか」を画面に出し、
/// ユーザーがそのまま報告できる状態にする。
class AppErrorReporter {
  AppErrorReporter._();

  /// 直近に捕捉したエラー（新しい順）。エラー画面と、必要なら
  /// 設定画面等からの参照に使う。無制限に貯めない。
  static final List<String> recentErrors = <String>[];
  static const int _maxRecent = 20;

  static void record(Object error, StackTrace? stack) {
    final head =
        stack
            ?.toString()
            .split('\n')
            .where((l) => l.contains('package:niarim/'))
            .take(3)
            .join('\n') ??
        '';
    final entry = '$error${head.isEmpty ? '' : '\n$head'}';
    recentErrors.insert(0, entry);
    if (recentErrors.length > _maxRecent) {
      recentErrors.removeRange(_maxRecent, recentErrors.length);
    }
  }

  /// アプリ起動時に一度だけ呼ぶ。
  static void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack);
      // デバッグ時は従来どおりコンソールへも出す。
      previousOnError?.call(details);
    };

    // build/layout/paint中の例外で画面が白紙になる代わりに、
    // 何が起きたかを表示する。
    ErrorWidget.builder = (details) {
      record(details.exception, details.stack);
      return _AppErrorView(details: details);
    };

    // 非同期処理（Future）内の未捕捉エラーも記録する。ここでfalseを返すと
    // 既定の処理（コンソール出力）も続行される。
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return false;
    };
  }
}

/// [ErrorWidget]の置き換え。壊れた状態で描画されるため、Theme・
/// Localizations・Provider等の祖先に依存せず、素のウィジェットだけで
/// 組み立てる（それらを参照すると、このエラー表示自体がさらに例外を
/// 投げて本当に何も出なくなる）。
class _AppErrorView extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorView({required this.details});

  @override
  Widget build(BuildContext context) {
    final message = details.exceptionAsString();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF2B2B2B),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'この部分の表示でエラーが発生しました',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '作業中のデータは保持されています。前の画面へ戻ってから'
                'もう一度お試しください。以下の内容を開発元へお知らせ'
                'いただけると原因の特定に役立ちます。',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF1A1A1A),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFB4A9),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
