import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import 'app_locale.dart';

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

  /// 直近に捕捉したエラー（新しい順、先頭に起きた時刻）。エラー画面と、
  /// 設定の「エラーの記録」から見る・コピーする。アプリを閉じるまでの分だけで、
  /// 保存はしない。無制限に貯めない。
  static final List<String> recentErrors = <String>[];
  static const int maxRecent = 20;
  static bool _installed = false;

  static void record(Object error, StackTrace? stack) {
    final head =
        stack
            ?.toString()
            .split('\n')
            .where((l) => l.contains('package:niarim/'))
            .take(3)
            .join('\n') ??
        '';
    final body = displayMessage('$error');
    final entry =
        '[${_timestamp(DateTime.now())}] $body'
        '${head.isEmpty ? '' : '\n${maskPersonalDetails(head)}'}';
    recentErrors.insert(0, entry);
    if (recentErrors.length > maxRecent) {
      recentErrors.removeRange(maxRecent, recentErrors.length);
    }
  }

  static const int _maxLength = 2000;

  static String displayMessage(String text) {
    final masked = maskPersonalDetails(text);
    return masked.length > _maxLength
        ? '${masked.substring(0, _maxLength)}…'
        : masked;
  }

  static String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static final _urlUserInfo = RegExp(
    r'(\b[a-z][a-z0-9+.-]*://)[^/\s@]+@',
    caseSensitive: false,
  );
  static final _email = RegExp(
    r'[\w.+-]+(?:@|%40)[\w-]+(?:\.[\w-]+)+',
    caseSensitive: false,
  );
  static final _authorization = RegExp(
    r'\b(Bearer|Basic)\s+[\w\-.~+/=]+',
    caseSensitive: false,
  );
  static final _credentials = RegExp(
    r'''(\b(?:(?:access|id|refresh|auth|session|device|firebase|fcm)[_-]?)?token\b|\b(?:api[_-]?key|key|authorization|code|client[_-]?secret|secret|password|auth|cookie|set-cookie|email(?:[_-]?address)?|phone(?:[_-]?number)?|user[_-]?id|uid|display[_-]?name|project[_-]?name|filename)\b)(["']?\s*[:=]\s*)(?:(?:"(?:\\.|[^"\\])*")|(?:'(?:\\.|[^'\\])*')|[^\s,&;\]}]+)''',
    caseSensitive: false,
  );
  static final _cookieHeader = RegExp(
    r'^([ \t]*(?:Cookie|Set-Cookie))([ \t]*:[ \t]*)[^\r\n]+',
    multiLine: true,
    caseSensitive: false,
  );
  static final _phone = RegExp(
    r'(?<![\w.])(?:\+\d{1,3}[- .]?)?(?:\(\d{2,4}\)|0\d{1,3})[- .]?\d{2,4}[- .]\d{4}(?!\d)|(?<!\w)\+\d{8,15}(?!\d)',
  );
  static final _labeledPath = RegExp(
    r'''(\bpath\s*[:=]\s*)(?:'[^'\r\n]*'|"[^"\r\n]*")''',
    caseSensitive: false,
  );
  static final _quotedPath = RegExp(
    r'''(['"])(?:file:/+|[a-z]:[\\/]|\\\\|/)[^\r\n]*?\1''',
    caseSensitive: false,
  );
  static final _localPath = RegExp(
    r'''(?<![\w:/])(?:file:/+|[a-z]:[\\/]|\\\\|/(?!/))[^\s"'<>|,)\]}]+''',
    caseSensitive: false,
  );

  /// エラーの表示やコピーに含まれる認証情報、連絡先、端末上のパスを伏せる。
  static String maskPersonalDetails(String text) => text
      .replaceAllMapped(_urlUserInfo, (m) => '${m[1]}[hidden]@')
      .replaceAll(_email, '[email]')
      .replaceAll(RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+'), '[token]')
      .replaceAllMapped(_authorization, (m) => '${m[1]} [token]')
      .replaceAllMapped(_credentials, (m) {
        final key = m[1]!.toLowerCase();
        final prefix = '${m[1]}${m[2]}';
        final value = m[0]!.substring(prefix.length);
        if (key == 'authorization' &&
            (value.toLowerCase() == 'bearer' ||
                value.toLowerCase() == 'basic')) {
          return m[0]!;
        }
        return '$prefix[hidden]';
      })
      .replaceAllMapped(_cookieHeader, (m) => '${m[1]}${m[2]}[hidden]')
      .replaceAll(_phone, '[phone]')
      .replaceAllMapped(_labeledPath, (m) => '${m[1]}[path]')
      .replaceAll(_quotedPath, '[path]')
      .replaceAll(_localPath, '[path]');

  /// アプリ起動時に一度だけ呼ぶ。再試行経路から重複して呼ばれても、
  /// Flutter/Platformのglobal handlerを多重ラップしない。
  static void install() {
    if (_installed) return;
    _installed = true;

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
/// 投げて本当に何も出なくなる）。文言は、祖先にロケールがあればその
/// 言語、無ければ端末の言語で、生成済みの訳を直接引く（例外を投げない
/// `Localizations.maybeLocaleOf`だけを使う）。
class _AppErrorView extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorView({required this.details});

  @override
  Widget build(BuildContext context) {
    final message = AppErrorReporter.displayMessage(
      details.exceptionAsString(),
    );
    final l10n = appLocalizationsFor(
      Localizations.maybeLocaleOf(context) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
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
              Text(
                l10n.errorViewTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.errorViewBody,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF1A1A1A),
                child: Text(
                  message,
                  style: TextStyle(
                    color: const Color(0xFFFFB4A9),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontFamilyFallback: fallbackUnderOtherFamily(
                      DefaultTextStyle.of(context).style.fontFamilyFallback,
                    ),
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
