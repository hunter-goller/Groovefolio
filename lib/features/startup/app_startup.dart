import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

/// Opens required local storage before showing the app. Each retry invokes
/// [initialize] once; that callback owns disposal of failed dependencies.
/// No failure path clears data or skips database migrations.
class AppStartup extends StatefulWidget {
  const AppStartup({required this.initialize, super.key});

  final Future<Widget> Function() initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Widget? _app;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = await widget.initialize();
      if (!mounted) return;
      setState(() => _app = app);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : AppErrorState(
                  title: 'Couldn’t open your collection',
                  message:
                      'Try opening it again. If this keeps happening, contact '
                      'support before clearing app storage or reinstalling, which '
                      'would remove your local collection.',
                  error: _error!,
                  stackTrace: _stackTrace!,
                  operation: 'open local database',
                  onRetry: _start,
                  retryButtonKey: const Key('startup-retry'),
                ),
        ),
      ),
    );
  }
}
