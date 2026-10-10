import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../services/theme_service.dart';
import '../utils/app_locale.dart';

/// 起動処理が失敗したときに、アプリ本体の代わりに出す画面。
///
/// 起動に失敗した時点ではServiceが1つも無いため、Providerには一切
/// 依存しない。配色・フォントは既定テーマ、表示言語は失敗前に読めていた
/// 言語設定（読めていなければ端末の言語）に合わせる。
///
/// 「もう一度試す」は[onRetry]で起動処理を最初からやり直す。やり直しにも
/// 失敗した場合は、呼び出し側が新しいキーでこの画面を出し直す。
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.details,
    required this.onRetry,
    this.languageCode,
  });

  /// 開発元へ伝えるための詳細（失敗した処理の名前・例外・呼び出し元）。
  final String details;

  final Future<void> Function() onRetry;

  /// 失敗前に読めていた表示言語の設定。nullなら端末の言語。
  final String? languageCode;

  @override
  Widget build(BuildContext context) {
    final code = languageCode;
    return MaterialApp(
      title: 'NIARIM',
      debugShowCheckedModeBanner: false,
      theme: _defaultTheme(),
      locale: code == null ? null : localeFromLanguageCode(code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StartupFailureScreen(details: details, onRetry: onRetry),
    );
  }

  static ThemeData _defaultTheme() {
    final themes = ThemeService();
    try {
      return themes.themeData;
    } finally {
      themes.dispose();
    }
  }
}

class StartupFailureScreen extends StatefulWidget {
  const StartupFailureScreen({
    super.key,
    required this.details,
    required this.onRetry,
  });

  final String details;
  final Future<void> Function() onRetry;

  @override
  State<StartupFailureScreen> createState() => _StartupFailureScreenState();
}

class _StartupFailureScreenState extends State<StartupFailureScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _copyDetails(AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: widget.details));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.startupFailedDetailsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: colors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.startupFailedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.startupFailedBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _retrying
                          ? l10n.startupFailedRetrying
                          : l10n.startupFailedRetry,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _copyDetails(l10n),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l10n.startupFailedCopyDetails),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: Text(l10n.startupFailedDetails),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          widget.details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const ['monospace'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
