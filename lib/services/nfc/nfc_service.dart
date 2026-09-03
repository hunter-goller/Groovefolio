import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';

const _defaultNfcTimeout = Duration(seconds: 20);
const _nfcUriScheme = 'groovefolio';
const _nfcAlbumHost = 'album';

enum NfcFailure {
  unavailable,
  disabled,
  busy,
  timedOut,
  cancelled,
  invalidTag,
  notNdef,
  notWritable,
  unregisteredTag,
  alreadyRegistered,
  readFailed,
  writeFailed,
  persistenceFailed,
}

/// Typed NFC failure with a safe message for UI and an optional diagnostic
/// cause that must never be rendered directly.
class NfcException implements Exception {
  const NfcException(this.failure, this.message, {this.cause});

  factory NfcException.forFailure(NfcFailure failure, {Object? cause}) {
    return NfcException(failure, _messageForFailure(failure), cause: cause);
  }

  final NfcFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => 'NfcException(${failure.name}): $message';
}

/// Builds the stable URI written to a Groovefolio NFC tag.
Uri nfcAlbumUri(String albumId) {
  final normalizedAlbumId = albumId.trim();
  if (normalizedAlbumId.isEmpty) {
    throw ArgumentError.value(albumId, 'albumId', 'Album ID cannot be empty.');
  }

  return Uri(
    scheme: _nfcUriScheme,
    host: _nfcAlbumHost,
    pathSegments: [normalizedAlbumId],
  );
}

/// Extracts an album ID only from Groovefolio album-tag URIs.
String? albumIdFromNfcUri(Uri uri) {
  if (uri.scheme != _nfcUriScheme ||
      uri.host != _nfcAlbumHost ||
      uri.pathSegments.length != 1) {
    return null;
  }

  final albumId = uri.pathSegments.single.trim();
  return albumId.isEmpty ? null : albumId;
}

/// Canonicalizes the hexadecimal identifier returned by Android NFC APIs.
String normalizeNfcTagIdentifier(String identifier) {
  final compact = identifier.trim().replaceAll(RegExp(r'[:\s-]'), '');
  if (compact.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
    return '';
  }
  return compact.toUpperCase();
}

/// Coordinates foreground NFC polling, NDEF writing, and local tag-to-album
/// resolution. NFC UI remains hidden until VinylApp-065/066 wire these methods
/// into the record and Log Play flows.
class NfcService {
  NfcService({
    required INfcPlatformAdapter platform,
    required INfcTagRepository repository,
  }) : _platform = platform,
       _repository = repository;

  final INfcPlatformAdapter _platform;
  final INfcTagRepository _repository;

  bool _operationActive = false;
  bool _nativeSessionMayBeOpen = false;
  bool _sessionFinished = false;
  bool _stopRequested = false;

  /// Returns a non-throwing state suitable for the app-launch capability check.
  Future<NfcAvailabilityState> availability() async {
    try {
      return await _platform.availability();
    } on Object {
      return NfcAvailabilityState.unsupported;
    }
  }

  /// Writes an album URI to one NFC tag and saves the physical tag mapping.
  Future<NfcTag> writeTag(
    String albumId, {
    Duration timeout = _defaultNfcTimeout,
  }) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    _beginOperation();
    try {
      await _ensureAvailable();
      final tag = await _poll(timeout, fallback: NfcFailure.writeFailed);
      final tagIdentifier = _requireTagIdentifier(tag.identifier);

      if (!tag.ndefAvailable) {
        throw NfcException.forFailure(NfcFailure.notNdef);
      }
      if (!tag.ndefWritable) {
        throw NfcException.forFailure(NfcFailure.notWritable);
      }

      final existingForTag = await _findByTagId(tagIdentifier);
      final existingForAlbum = await _findByAlbum(normalizedAlbumId);
      if ((existingForTag != null &&
              existingForTag.albumId != normalizedAlbumId) ||
          (existingForAlbum != null &&
              existingForAlbum.nfcTagId != tagIdentifier)) {
        throw NfcException.forFailure(NfcFailure.alreadyRegistered);
      }

      try {
        await _platform.writeUri(nfcAlbumUri(normalizedAlbumId));
      } on Object catch (error, stackTrace) {
        _throwMapped(error, stackTrace, fallback: NfcFailure.writeFailed);
      }

      if (existingForTag != null) {
        return existingForTag;
      }

      try {
        return await _repository.create(
          albumId: normalizedAlbumId,
          nfcTagId: tagIdentifier,
        );
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          NfcException.forFailure(NfcFailure.persistenceFailed, cause: error),
          stackTrace,
        );
      }
    } finally {
      await _finishSession();
      _endOperation();
    }
  }

  /// Starts one foreground scan and emits the locally registered album ID.
  /// The physical tag identifier is deliberately never exposed to UI callers.
  Stream<String> startScan({Duration timeout = _defaultNfcTimeout}) async* {
    _beginOperation();
    try {
      await _ensureAvailable();
      final tag = await _poll(timeout, fallback: NfcFailure.readFailed);
      final tagIdentifier = _requireTagIdentifier(tag.identifier);
      final association = await _findByTagId(tagIdentifier);

      if (association == null) {
        throw NfcException.forFailure(NfcFailure.unregisteredTag);
      }
      yield association.albumId;
    } finally {
      await _finishSession();
      _endOperation();
    }
  }

  /// Cancels an active poll. It is safe to call when no scan is active.
  Future<void> stopScan() async {
    if (!_operationActive) return;

    _stopRequested = true;
    await _finishSession(surfaceFailure: true);
  }

  void _beginOperation() {
    if (_operationActive) {
      throw NfcException.forFailure(NfcFailure.busy);
    }
    _operationActive = true;
    _nativeSessionMayBeOpen = false;
    _sessionFinished = false;
    _stopRequested = false;
  }

  void _endOperation() {
    _operationActive = false;
    _nativeSessionMayBeOpen = false;
    _sessionFinished = false;
    _stopRequested = false;
  }

  Future<void> _ensureAvailable() async {
    late final NfcAvailabilityState state;
    try {
      state = await _platform.availability();
    } on Object catch (error, stackTrace) {
      _throwMapped(error, stackTrace, fallback: NfcFailure.unavailable);
    }

    switch (state) {
      case NfcAvailabilityState.available:
        return;
      case NfcAvailabilityState.disabled:
        throw NfcException.forFailure(NfcFailure.disabled);
      case NfcAvailabilityState.unsupported:
        throw NfcException.forFailure(NfcFailure.unavailable);
    }
  }

  Future<NfcPlatformTag> _poll(
    Duration timeout, {
    required NfcFailure fallback,
  }) async {
    _nativeSessionMayBeOpen = true;
    try {
      final tag = await _platform.poll(timeout: timeout);
      if (_stopRequested) {
        throw NfcException.forFailure(NfcFailure.cancelled);
      }
      return tag;
    } on Object catch (error, stackTrace) {
      if (_stopRequested) {
        Error.throwWithStackTrace(
          NfcException.forFailure(NfcFailure.cancelled, cause: error),
          stackTrace,
        );
      }
      _throwMapped(error, stackTrace, fallback: fallback);
    }
  }

  String _requireTagIdentifier(String identifier) {
    final normalized = normalizeNfcTagIdentifier(identifier);
    if (normalized.isEmpty) {
      throw NfcException.forFailure(NfcFailure.invalidTag);
    }
    return normalized;
  }

  Future<NfcTag?> _findByTagId(String tagIdentifier) async {
    try {
      return await _repository.findByTagId(tagIdentifier);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NfcException.forFailure(NfcFailure.persistenceFailed, cause: error),
        stackTrace,
      );
    }
  }

  Future<NfcTag?> _findByAlbum(String albumId) async {
    try {
      return await _repository.findByAlbum(albumId);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NfcException.forFailure(NfcFailure.persistenceFailed, cause: error),
        stackTrace,
      );
    }
  }

  Future<void> _finishSession({bool surfaceFailure = false}) async {
    if (!_nativeSessionMayBeOpen || _sessionFinished) return;

    _sessionFinished = true;
    try {
      await _platform.finish();
    } on Object catch (error, stackTrace) {
      if (surfaceFailure) {
        _throwMapped(error, stackTrace, fallback: NfcFailure.readFailed);
      }
      if (kDebugMode) {
        debugPrint('[Groovefolio] NFC session cleanup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _nativeSessionMayBeOpen = false;
    }
  }

  Never _throwMapped(
    Object error,
    StackTrace stackTrace, {
    required NfcFailure fallback,
  }) {
    if (error is NfcException) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    final signal = error is PlatformException
        ? '${error.code} ${error.message ?? ''}'.toLowerCase()
        : error.toString().toLowerCase();
    final failure = switch (signal) {
      final value when value.contains('cancel') || value.contains('499') =>
        NfcFailure.cancelled,
      final value when value.contains('timeout') || value.contains('408') =>
        NfcFailure.timedOut,
      final value when value.contains('disabled') => NfcFailure.disabled,
      final value
          when value.contains('not supported') ||
              value.contains('not_supported') ||
              value.contains('unavailable') =>
        NfcFailure.unavailable,
      _ => fallback,
    };

    Error.throwWithStackTrace(
      NfcException.forFailure(failure, cause: error),
      stackTrace,
    );
  }
}

String _messageForFailure(NfcFailure failure) => switch (failure) {
  NfcFailure.unavailable => 'NFC isn’t available on this device.',
  NfcFailure.disabled => 'Turn on NFC in device settings, then try again.',
  NfcFailure.busy => 'Another NFC operation is already running.',
  NfcFailure.timedOut =>
    'No NFC tag was detected. Hold the phone closer and try again.',
  NfcFailure.cancelled => 'The NFC scan was cancelled.',
  NfcFailure.invalidTag => 'Groovefolio couldn’t identify that NFC tag.',
  NfcFailure.notNdef => 'That tag does not support the required NDEF format.',
  NfcFailure.notWritable => 'That NFC tag is read-only or not writable.',
  NfcFailure.unregisteredTag => 'That NFC tag is not linked to a record yet.',
  NfcFailure.alreadyRegistered =>
    'That tag or record is already linked somewhere else.',
  NfcFailure.readFailed => 'Groovefolio couldn’t read that NFC tag.',
  NfcFailure.writeFailed => 'Groovefolio couldn’t write to that NFC tag.',
  NfcFailure.persistenceFailed =>
    'Groovefolio couldn’t save the NFC tag connection.',
};

final nfcPlatformAdapterProvider = Provider<INfcPlatformAdapter>((ref) {
  return const FlutterNfcPlatformAdapter();
});

final nfcServiceProvider = Provider<NfcService>((ref) {
  return NfcService(
    platform: ref.watch(nfcPlatformAdapterProvider),
    repository: ref.watch(nfcTagRepositoryProvider),
  );
});

final nfcAvailabilityProvider = FutureProvider<NfcAvailabilityState>((ref) {
  return ref.watch(nfcServiceProvider).availability();
});
