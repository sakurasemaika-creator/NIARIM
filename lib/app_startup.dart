import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_bootstrap.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'utils/app_error_reporter.dart';

/// Displays startup failures even when no application provider is available.
/// One attempt owns its services; retry starts only after it has finished.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.initialize, required this.child});

  final Future<AppServices> Function() initialize;
  final Widget child;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  final _recoveryTheme = ThemeService().themeData;
  AppServices? _services;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_loading || _services != null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final services = await widget.initialize();
      if (!mounted) {
        services.dispose();
        return;
      }
      setState(() => _services = services);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services != null) {
      return MultiProvider(providers: services.providers, child: widget.child);
    }
    // Saved settings may themselves be the reason startup failed.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _recoveryTheme,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NIARIM',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        if (_failed) ...[
                          Text(
                            l10n.startupErrorTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.startupErrorBody,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            key: const Key('startup-retry'),
                            onPressed: _loading ? null : _start,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.startupRetry),
                          ),
                        ] else ...[
                          CircularProgressIndicator(
                            semanticsLabel: l10n.startupLoading,
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.startupLoading),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
