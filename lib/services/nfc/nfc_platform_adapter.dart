import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

/// App-owned availability state that keeps plugin types out of business logic.
enum NfcAvailabilityState { available, disabled, unsupported }

/// NFC metadata needed by Groovefolio after a foreground poll.
class NfcPlatformTag {
  const NfcPlatformTag({
    required this.identifier,
    required this.ndefAvailable,
    required this.ndefWritable,
  });

  final String identifier;
  final bool ndefAvailable;
  final bool ndefWritable;
}

/// Narrow platform boundary used by [NfcService] and replaced by fakes in
/// tests. The app currently supports NFC on Android only.
abstract interface class INfcPlatformAdapter {
  Future<NfcAvailabilityState> availability();

  Future<NfcPlatformTag> poll({required Duration timeout});

  Future<void> writeUri(Uri uri);

  Future<void> finish();
}

/// Optional Android boundary that prevents a foreground read/write tap from
/// also being delivered to the app as an automatic-play NDEF intent.
abstract interface class INfcForegroundIntentGate {
  Future<void> setForegroundNfcOperationActive(bool active);
}

class FlutterNfcPlatformAdapter
    implements INfcPlatformAdapter, INfcForegroundIntentGate {
  const FlutterNfcPlatformAdapter();

  static const _foregroundIntentChannel = MethodChannel(
    'com.huntergoller.vinyl_app/nfc_foreground_intents',
  );

  @override
  Future<void> setForegroundNfcOperationActive(bool active) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value();
    }
    return _foregroundIntentChannel.invokeMethod<void>(
      'setForegroundNfcOperationActive',
      <String, bool>{'active': active},
    );
  }

  @override
  Future<NfcAvailabilityState> availability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return NfcAvailabilityState.unsupported;
    }

    final availability = await FlutterNfcKit.nfcAvailability;
    return switch (availability) {
      NFCAvailability.available => NfcAvailabilityState.available,
      NFCAvailability.disabled => NfcAvailabilityState.disabled,
      NFCAvailability.not_supported => NfcAvailabilityState.unsupported,
    };
  }

  @override
  Future<NfcPlatformTag> poll({required Duration timeout}) async {
    final tag = await FlutterNfcKit.poll(timeout: timeout);
    return NfcPlatformTag(
      identifier: tag.id,
      ndefAvailable: tag.ndefAvailable == true,
      ndefWritable: tag.ndefWritable == true,
    );
  }

  @override
  Future<void> writeUri(Uri uri) {
    return FlutterNfcKit.writeNDEFRecords([
      ndef.UriRecord.fromString(uri.toString()),
    ]);
  }

  @override
  Future<void> finish() => FlutterNfcKit.finish();
}
