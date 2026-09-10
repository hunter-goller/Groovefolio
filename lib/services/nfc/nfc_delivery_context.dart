import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NfcDeliveryMode { foreground, external }

class NfcDeliveryContext {
  const NfcDeliveryContext({required this.id, required this.mode});

  const NfcDeliveryContext.foreground()
    : id = null,
      mode = NfcDeliveryMode.foreground;

  final int? id;
  final NfcDeliveryMode mode;

  bool get isExternal => mode == NfcDeliveryMode.external;
}

abstract interface class INfcDeliveryContextService {
  Future<NfcDeliveryContext> consume();

  Future<void> completeExternal(NfcDeliveryContext delivery);

  Future<void> showExternalMessage(String message);
}

typedef NfcDeliveryMethodInvoker =
    Future<Object?> Function(String method, Map<String, Object?>? arguments);

class AndroidNfcDeliveryContextService implements INfcDeliveryContextService {
  AndroidNfcDeliveryContextService({
    NfcDeliveryMethodInvoker? invoke,
    bool? isAndroid,
  }) : _invoke = invoke ?? _invokePlatformMethod,
       _isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const _channel = MethodChannel(
    'com.huntergoller.vinyl_app/nfc_delivery',
  );

  final NfcDeliveryMethodInvoker _invoke;
  final bool _isAndroid;

  static Future<Object?> _invokePlatformMethod(
    String method,
    Map<String, Object?>? arguments,
  ) {
    return _channel.invokeMethod<Object?>(method, arguments);
  }

  @override
  Future<NfcDeliveryContext> consume() async {
    if (!_isAndroid) return const NfcDeliveryContext.foreground();

    try {
      final value = await _invoke('consumeNfcDelivery', null);
      if (value case {'id': final int id, 'external': final bool external}) {
        return NfcDeliveryContext(
          id: id,
          mode: external
              ? NfcDeliveryMode.external
              : NfcDeliveryMode.foreground,
        );
      }
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Groovefolio] NFC delivery context failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    // A missing native classification must never hide a visible confirmation.
    return const NfcDeliveryContext.foreground();
  }

  @override
  Future<void> completeExternal(NfcDeliveryContext delivery) async {
    if (!_isAndroid || !delivery.isExternal) return;
    try {
      await _invoke('completeExternalNfcDelivery', {
        if (delivery.id != null) 'id': delivery.id!,
      });
    } on Object {
      // Play persistence and feedback already completed; task cleanup is best-effort.
    }
  }

  @override
  Future<void> showExternalMessage(String message) async {
    if (!_isAndroid) return;
    try {
      await _invoke('showExternalNfcMessage', {'message': message});
    } on Object {
      // A feedback failure must never retry or roll back the saved play.
    }
  }
}

final nfcDeliveryContextServiceProvider = Provider<INfcDeliveryContextService>((
  ref,
) {
  return AndroidNfcDeliveryContextService();
});
