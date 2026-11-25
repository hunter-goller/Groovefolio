import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/notifications/nfc_play_notification_service.dart';

enum NfcWriteOutcome { written, skipped }

Future<NfcWriteOutcome> showNfcWriteDialog(
  BuildContext context, {
  required String albumId,
  bool replaceExisting = false,
}) async {
  final service = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(nfcServiceProvider);
  try {
    final outcome = await service.withForegroundInteraction(() async {
      if (!context.mounted) return NfcWriteOutcome.skipped;
      return await showDialog<NfcWriteOutcome>(
            context: context,
            barrierDismissible: false,
            builder: (context) => NfcWriteDialog(
              albumId: albumId,
              replaceExisting: replaceExisting,
            ),
          ) ??
          NfcWriteOutcome.skipped;
    });
    if (outcome == NfcWriteOutcome.written) {
      // Ask while Groovefolio is visibly open, never from an external tag tap.
      unawaited(requestNfcPlayNotificationPermission());
    }
    return outcome;
  } on NfcException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t start NFC. Your record is saved.'),
        ),
      );
    }
    return NfcWriteOutcome.skipped;
  }
}

/// Blocking, retryable prompt used after an album has already been saved.
/// Skipping NFC never rolls back the record that was just created.
class NfcWriteDialog extends ConsumerStatefulWidget {
  const NfcWriteDialog({
    required this.albumId,
    this.replaceExisting = false,
    super.key,
  });

  final String albumId;
  final bool replaceExisting;

  @override
  ConsumerState<NfcWriteDialog> createState() => _NfcWriteDialogState();
}

class _NfcWriteDialogState extends ConsumerState<NfcWriteDialog> {
  NfcException? _failure;

  /// Title of the record the presented tag belongs to, when it's linked to
  /// another record and could be moved here.
  String? _otherTitle;
  var _attempt = 0;
  var _isWriting = true;
  var _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _write();
    });
  }

  Future<void> _write({String? moveFromAlbumId}) async {
    final attempt = ++_attempt;
    setState(() {
      _failure = null;
      _otherTitle = null;
      _isWriting = true;
    });

    final service = ref.read(nfcServiceProvider);
    try {
      await service.writeTag(
        widget.albumId,
        replaceExisting: widget.replaceExisting,
        moveFromAlbumId: moveFromAlbumId,
      );
      if (!mounted || attempt != _attempt) return;
      if (moveFromAlbumId != null) {
        ref.invalidate(albumNfcTagProvider(moveFromAlbumId));
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      // The dialog closes first; the app-wide container outlives it.
      final container = ProviderScope.containerOf(context, listen: false);
      Navigator.of(context).pop(NfcWriteOutcome.written);
      await _removeAccidentalTap(container, service.albumOnLastTag, messenger);
    } on NfcException catch (failure) {
      if (!mounted || attempt != _attempt) return;
      await _removeAccidentalTap(
        ProviderScope.containerOf(context, listen: false),
        failure.otherAlbumId ?? service.albumOnLastTag,
        ScaffoldMessenger.maybeOf(context),
      );
      if (!mounted || attempt != _attempt) return;
      String? otherTitle;
      final otherId = failure.otherAlbumId;
      if (failure.failure == NfcFailure.linkedToOtherRecord &&
          otherId != null) {
        try {
          otherTitle =
              (await ref.read(albumRepositoryProvider).findById(otherId))
                  ?.title;
        } on Object {
          // The plain message still explains what happened.
        }
        if (!mounted || attempt != _attempt) return;
      }
      setState(() {
        _failure = failure;
        _otherTitle = otherTitle ?? (otherId == null ? null : 'another record');
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

  /// Getting a tag ready often touches it to the phone a moment before this
  /// dialog opens, and Android logs that as a tap. Writing that same tag
  /// shows it wasn't meant as a play, so the play is removed.
  static Future<void> _removeAccidentalTap(
    ProviderContainer container,
    String? albumId,
    ScaffoldMessengerState? messenger,
  ) async {
    if (albumId == null) return;
    try {
      final removed = await container
          .read(nfcPlayLoggingServiceProvider)
          .removeRecentTap(albumId);
      if (!removed) return;
      container
        ..invalidate(albumsProvider)
        ..invalidate(recentlyPlayedProvider)
        ..invalidate(playCountProvider(albumId))
        ..invalidate(albumDetailProvider(albumId));
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Removed the play logged when the tag touched your phone '
              'before writing.',
            ),
          ),
        );
    } on Object {
      // The play stays in the history; the tag write is what matters here.
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
    final activeTitle = widget.replaceExisting
        ? 'Rewrite or replace NFC tag'
        : 'Write NFC tag';

    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('nfc-write-dialog'),
        icon: Icon(
          failure == null ? Icons.nfc_rounded : Icons.error_outline_rounded,
          color: failure == null ? colors.primary : colors.error,
          size: 38,
        ),
        title: Text(
          failure == null
              ? activeTitle
              : _otherTitle != null
              ? 'Tag already in use'
              : 'Couldn’t write tag',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isWriting) ...[
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                widget.replaceExisting
                    ? 'Hold the top of your phone close to the tag you want '
                          'linked to this record. It can be the current tag or '
                          'a new one.'
                    : 'Hold the top of your phone close to the NFC tag and '
                          'keep it still until writing finishes.',
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                _otherTitle != null
                    ? 'This tag is linked to “$_otherTitle”. Move it to this '
                          'record? “$_otherTitle” won’t have a tag any more.'
                    : failure?.message ??
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
          if (!_isWriting && !_isClosing) const NfcHelpButton(),
          TextButton(
            key: const Key('nfc-write-skip'),
            onPressed: _isClosing ? null : _skip,
            child: const Text('Skip for now'),
          ),
          if (!_isWriting && _otherTitle != null) ...[
            TextButton(
              key: const Key('nfc-write-retry'),
              onPressed: _isClosing ? null : _write,
              child: const Text('Use another tag'),
            ),
            FilledButton.icon(
              key: const Key('nfc-write-move'),
              onPressed: _isClosing
                  ? null
                  : () => _write(moveFromAlbumId: failure?.otherAlbumId),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Move tag here'),
            ),
          ] else if (!_isWriting)
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
