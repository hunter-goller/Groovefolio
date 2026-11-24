import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/utils/error_reporting.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

/// Saves a rescue copy of the local data. Returns false if the user cancelled.
typedef SaveRescueCopy = Future<bool> Function();

enum _RescueStatus { idle, saving, saved, failed }

/// Opens required local storage before showing the app. Each retry invokes
/// [initialize] once; that callback owns disposal of failed dependencies.
/// No failure path clears data or skips database migrations.
///
/// When opening fails, [saveRescueCopy] (if provided) lets the user copy their
/// data off the phone before trying anything else.
class AppStartup extends StatefulWidget {
  const AppStartup({required this.initialize, this.saveRescueCopy, super.key});

  final Future<Widget> Function() initialize;
  final SaveRescueCopy? saveRescueCopy;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Widget? _app;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = false;
  _RescueStatus _rescue = _RescueStatus.idle;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Don't reopen the database while its files are being copied.
    if (_loading || _rescue == _RescueStatus.saving) return;
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

  Future<void> _saveRescueCopy() async {
    final save = widget.saveRescueCopy;
    if (save == null || _rescue == _RescueStatus.saving) return;
    final previous = _rescue;
    setState(() => _rescue = _RescueStatus.saving);
    try {
      final saved = await save();
      if (!mounted) return;
      setState(() => _rescue = saved ? _RescueStatus.saved : previous);
    } catch (error, stackTrace) {
      logAppError('save rescue copy', error, stackTrace);
      if (mounted) setState(() => _rescue = _RescueStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    final canRescue = widget.saveRescueCopy != null;
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
                  message: canRescue
                      ? 'Your records are still on this phone. Try again. If '
                            'this keeps happening, save a copy of your data and '
                            'contact support. Don’t clear app storage or '
                            'reinstall: that would remove your collection.'
                      : 'Try opening it again. If this keeps happening, '
                            'contact support before clearing app storage or '
                            'reinstalling, which would remove your local '
                            'collection.',
                  error: _error!,
                  stackTrace: _stackTrace!,
                  operation: 'open local database',
                  onRetry: _start,
                  retryButtonKey: const Key('startup-retry'),
                  secondaryActionLabel: canRescue
                      ? 'Save a copy of my data'
                      : null,
                  onSecondaryAction: canRescue ? _saveRescueCopy : null,
                  secondaryButtonKey: const Key('startup-save-copy'),
                  secondaryActionIcon: Icons.save_alt_outlined,
                  secondaryActionLoading: _rescue == _RescueStatus.saving,
                  footer: switch (_rescue) {
                    _RescueStatus.saved => const _RescueMessage(
                      key: Key('startup-copy-saved'),
                      icon: Icons.check_circle_outline_rounded,
                      text:
                          'Copy saved. Keep it somewhere safe until '
                          'Groovefolio is fixed. Support may ask for it.',
                    ),
                    _RescueStatus.failed => const _RescueMessage(
                      key: Key('startup-copy-failed'),
                      icon: Icons.error_outline_rounded,
                      isError: true,
                      text:
                          'Couldn’t save a copy. Your data is still on this '
                          'phone. Try again, or choose another place to save.',
                    ),
                    _ => null,
                  },
                ),
        ),
      ),
    );
  }
}

class _RescueMessage extends StatelessWidget {
  const _RescueMessage({
    required this.icon,
    required this.text,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = isError
        ? context.theme.colorScheme.error
        : context.theme.colorScheme.primary;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: tokens.space8),
              Expanded(
                child: Text(
                  text,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.text,
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
