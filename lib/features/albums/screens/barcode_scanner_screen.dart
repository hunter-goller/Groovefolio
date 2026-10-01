import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vinyl_app/services/app_settings_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Camera flow that returns a scanned UPC/EAN barcode to the caller.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    autoZoom: true,
  );

  bool _returningResult = false;
  bool _returningFromSettings = false;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _returningFromSettings) {
      _returningFromSettings = false;
      unawaited(_retryCamera());
    }
  }

  Future<void> _retryCamera() async {
    if (_restarting || _returningResult || !mounted) return;
    setState(() => _restarting = true);
    try {
      await _controller.start();
    } on MobileScannerException {
      // The scanner's error builder displays camera and permission failures.
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _openSettings() async {
    _returningFromSettings = true;
    final opened = await AppSettingsService.open();
    if (!mounted) return;
    if (!opened) {
      _returningFromSettings = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open settings. Open your device settings, then Apps > Groovefolio > Permissions > Camera.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_returningResult) return;

    for (final barcode in capture.barcodes) {
      final value = _normalizedBarcode(barcode.rawValue);
      if (value == null) continue;

      _returningResult = true;
      await _controller.stop();
      if (!mounted) return;
      Navigator.of(context).pop(value);
      return;
    }
  }

  String? _normalizedBarcode(String? rawValue) {
    if (rawValue == null) return null;
    final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchAvailable = state.torchState != TorchState.unavailable;
              final torchOn = state.torchState == TorchState.on;
              return IconButton(
                key: const Key('barcode-torch-toggle'),
                tooltip: torchOn ? 'Turn flash off' : 'Turn flash on',
                onPressed: torchAvailable
                    ? () => _controller.toggleTorch()
                    : null,
                icon: Icon(
                  torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, _) => LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = (constraints.maxWidth - tokens.space24 * 2)
                .clamp(220.0, 340.0)
                .toDouble();
            final frameHeight = frameWidth * 0.48;

            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  key: const Key('barcode-camera'),
                  controller: _controller,
                  onDetect: _handleDetection,
                  tapToFocus: true,
                  errorBuilder: (context, error) => _ScannerError(
                    permissionDenied:
                        error.errorCode ==
                        MobileScannerErrorCode.permissionDenied,
                    onOpenSettings: _openSettings,
                    onRetry: _restarting ? null : _retryCamera,
                  ),
                ),
                if (state.error == null) ...[
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: frameWidth,
                      height: frameHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(
                          tokens.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        width: double.infinity,
                        margin: EdgeInsets.all(tokens.space16),
                        padding: EdgeInsets.all(tokens.space16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(
                            tokens.radiusMedium,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Point the camera at the barcode on the record jacket.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Groovefolio will search Discogs for matching vinyl releases.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.permissionDenied,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final bool permissionDenied;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                Text(
                  permissionDenied
                      ? 'Camera permission is needed to scan a barcode.'
                      : 'The camera could not be started.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                if (permissionDenied) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Allow camera access in your device settings, then try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open settings'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
