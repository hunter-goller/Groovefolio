import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';

enum NfcWriteOutcome { written, skipped }

Future<NfcWriteOutcome> showNfcWriteDialog(
  BuildContext context, {
  required String albumId,
}) async {
  return await showDialog<NfcWriteOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (context) => NfcWriteDialog(albumId: albumId),
      ) ??
      NfcWriteOutcome.skipped;
}

/// Blocking, retryable prompt used after an album has already been saved.
/// Skipping NFC never rolls back the record that was just created.
class NfcWriteDialog extends ConsumerStatefulWidget {
  const NfcWriteDialog({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<NfcWriteDialog> createState() => _NfcWriteDialogState();
}

class _NfcWriteDialogState extends ConsumerState<NfcWriteDialog> {
  NfcException? _failure;
  var _attempt = 0;
  var _isWriting = true;
  var _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _write());
  }

  Future<void> _write() async {
    final attempt = ++_attempt;
    setState(() {
      _failure = null;
      _isWriting = true;
    });

    try {
      await ref.read(nfcServiceProvider).writeTag(widget.albumId);
      if (!mounted || attempt != _attempt) return;
      Navigator.of(context).pop(NfcWriteOutcome.written);
    } on NfcException catch (failure) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _failure = failure;
        _isWriting = false;
      });
    } on Object {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _failure = NfcException.forFailure(NfcFailure.writeFailed);
        _isWriting = false;
      });
    }
  }

  Future<void> _skip() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    _attempt += 1;
    try {
      await ref.read(nfcServiceProvider).stopScan();
    } on Object {
      // The record is already safely stored. A cleanup failure must not trap
      // the user in the optional NFC step.
    }
    if (!mounted) return;
    Navigator.of(context).pop(NfcWriteOutcome.skipped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failure = _failure;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('nfc-write-dialog'),
        icon: Icon(
          failure == null ? Icons.nfc_rounded : Icons.error_outline_rounded,
          color: failure == null ? colors.primary : colors.error,
          size: 38,
        ),
        title: Text(failure == null ? 'Write NFC tag' : 'Couldn’t write tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isWriting) ...[
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hold the top of your phone close to the NFC tag and keep it '
                'still until writing finishes.',
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                failure?.message ??
                    'Groovefolio couldn’t write to that NFC tag.',
                key: const Key('nfc-write-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your record is already saved.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('nfc-write-skip'),
            onPressed: _isClosing ? null : _skip,
            child: const Text('Skip for now'),
          ),
          if (!_isWriting)
            FilledButton.icon(
              key: const Key('nfc-write-retry'),
              onPressed: _isClosing ? null : _write,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}
