import 'package:flutter/material.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

enum NfcFailureKind { unavailable, disabled, readFailed, writeFailed, unknown }

/// Visual NFC prompt used by the Log Play flow.
///
/// The animation is intentionally UI-only for VinylApp-020. Hardware tag
/// detection is wired later by VinylApp-066 and can drive [isScanning].
class NFCPrompt extends StatefulWidget {
  const NFCPrompt({
    required this.isScanning,
    this.onStart,
    this.onCancel,
    this.error,
    this.stackTrace,
    this.failureKind = NfcFailureKind.unknown,
    this.onRetry,
    super.key,
  });

  final bool isScanning;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;
  final Object? error;
  final StackTrace? stackTrace;
  final NfcFailureKind failureKind;
  final VoidCallback? onRetry;

  @override
  State<NFCPrompt> createState() => _NFCPromptState();
}

class _NFCPromptState extends State<NFCPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant NFCPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isScanning != widget.isScanning ||
        oldWidget.error != widget.error) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isScanning && widget.error == null) {
      _pulseController.repeat();
    } else {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    if (error != null) {
      return AppErrorState.inline(
        key: const Key('nfc-error-state'),
        title: _failureTitle(widget.failureKind),
        message: _failureMessage(widget.failureKind),
        error: error,
        stackTrace: widget.stackTrace ?? StackTrace.empty,
        operation: 'use NFC',
        onRetry: widget.onRetry,
        icon: Icons.nfc_rounded,
        retryButtonKey: const Key('nfc-error-retry'),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      container: true,
      label: widget.isScanning ? 'Scanning for NFC tag' : 'NFC scanner ready',
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _NfcPulsePainter(
                    progress: _pulseController.value,
                    color: colors.primary,
                    enabled: widget.isScanning,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isScanning
                        ? colors.primary.withValues(alpha: 0.14)
                        : colors.surfaceContainerHighest,
                    border: Border.all(
                      color: widget.isScanning
                          ? colors.primary.withValues(alpha: 0.42)
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    Icons.nfc_rounded,
                    size: 32,
                    color: widget.isScanning
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              widget.isScanning ? 'Scanning for NFC…' : 'Scan an NFC tag',
              key: ValueKey(widget.isScanning),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isScanning
                ? 'Hold your phone near the record tag'
                : 'Or search your collection manually below',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (widget.isScanning && widget.onCancel != null)
            TextButton(
              key: const Key('nfc-cancel'),
              onPressed: widget.onCancel,
              child: const Text('Cancel scan'),
            )
          else if (!widget.isScanning && widget.onStart != null)
            TextButton.icon(
              key: const Key('nfc-start'),
              onPressed: widget.onStart,
              icon: const Icon(Icons.nfc_rounded, size: 18),
              label: const Text('Scan NFC'),
            ),
        ],
      ),
    );
  }
}

String _failureTitle(NfcFailureKind kind) => switch (kind) {
  NfcFailureKind.unavailable => 'NFC isn’t available on this device',
  NfcFailureKind.disabled => 'NFC is turned off',
  NfcFailureKind.readFailed => 'Couldn’t read that NFC tag',
  NfcFailureKind.writeFailed => 'Couldn’t write to that NFC tag',
  NfcFailureKind.unknown => 'Couldn’t use NFC',
};

String _failureMessage(NfcFailureKind kind) => switch (kind) {
  NfcFailureKind.unavailable =>
    'Choose a record manually to continue without NFC.',
  NfcFailureKind.disabled =>
    'Turn on NFC in your device settings, then try again.',
  NfcFailureKind.readFailed =>
    'Hold your phone near the tag and keep it still, then try again.',
  NfcFailureKind.writeFailed =>
    'Make sure the tag is writable and hold your phone steady, then try again.',
  NfcFailureKind.unknown =>
    'Move your phone away from the tag, then try again.',
};

class _NfcPulsePainter extends CustomPainter {
  const _NfcPulsePainter({
    required this.progress,
    required this.color,
    required this.enabled,
  });

  final double progress;
  final Color color;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;

    _paintRing(canvas, size, progress);
    _paintRing(canvas, size, (progress + 0.5) % 1.0);
  }

  void _paintRing(Canvas canvas, Size size, double value) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 33 + (15 * value);
    final opacity = (1 - value) * 0.38;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 - (value * 0.8)
      ..color = color.withValues(alpha: opacity);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _NfcPulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.enabled != enabled;
  }
}
