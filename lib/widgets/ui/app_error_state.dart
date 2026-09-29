import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/utils/error_reporting.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';

enum AppErrorStateLayout { page, inline }

/// Consistent, retryable error UI that keeps raw exception details out of the
/// interface while reporting them to the debug console.
class AppErrorState extends StatefulWidget {
  const AppErrorState({
    required this.title,
    required this.message,
    required this.error,
    required this.stackTrace,
    required this.operation,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
    this.layout = AppErrorStateLayout.page,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.retryButtonKey,
    this.secondaryButtonKey,
    super.key,
  }) : assert(
         (secondaryActionLabel == null) == (onSecondaryAction == null),
         'secondaryActionLabel and onSecondaryAction must both be provided or both be null.',
       );

  const AppErrorState.inline({
    required this.title,
    required this.message,
    required this.error,
    required this.stackTrace,
    required this.operation,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.retryButtonKey,
    this.secondaryButtonKey,
    super.key,
  }) : layout = AppErrorStateLayout.inline,
       assert(
         (secondaryActionLabel == null) == (onSecondaryAction == null),
         'secondaryActionLabel and onSecondaryAction must both be provided or both be null.',
       );

  final String title;
  final String message;
  final Object error;
  final StackTrace stackTrace;
  final String operation;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final AppErrorStateLayout layout;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Key? retryButtonKey;
  final Key? secondaryButtonKey;

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant AppErrorState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error) ||
        oldWidget.operation != widget.operation) {
      _report();
    }
  }

  void _report() {
    logAppError(widget.operation, widget.error, widget.stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.layout) {
      AppErrorStateLayout.page => Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: widget.icon,
            title: widget.title,
            subtitle: widget.message,
            ctaLabel: widget.onRetry == null ? null : widget.retryLabel,
            onCtaTap: widget.onRetry,
            ctaKey: widget.retryButtonKey,
          ),
        ),
      ),
      AppErrorStateLayout.inline => _InlineErrorState(widget: widget),
    };
  }
}

class _InlineErrorState extends StatelessWidget {
  const _InlineErrorState({required this.widget});

  final AppErrorState widget;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(
          color: context.theme.colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, color: context.theme.colorScheme.error),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: context.theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.space4),
                      Text(
                        widget.message,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.onRetry != null ||
                widget.secondaryActionLabel != null) ...[
              SizedBox(height: tokens.space8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: tokens.space8,
                runSpacing: tokens.space4,
                children: [
                  if (widget.secondaryActionLabel != null)
                    OutlinedButton(
                      key: widget.secondaryButtonKey,
                      onPressed: widget.onSecondaryAction,
                      child: Text(widget.secondaryActionLabel!),
                    ),
                  if (widget.onRetry != null)
                    FilledButton.icon(
                      key: widget.retryButtonKey,
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(widget.retryLabel),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
