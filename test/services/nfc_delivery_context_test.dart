import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/nfc/nfc_delivery_context.dart';

void main() {
  test('native delivery maps external metadata and completes by ID', () async {
    final calls = <(String, Map<String, Object?>?)>[];
    final service = AndroidNfcDeliveryContextService(
      isAndroid: true,
      invoke: (method, arguments) async {
        calls.add((method, arguments));
        if (method == 'consumeNfcDelivery') {
          return <String, Object?>{'id': 12, 'external': true};
        }
        return null;
      },
    );

    final delivery = await service.consume();
    expect(delivery.id, 12);
    expect(delivery.mode, NfcDeliveryMode.external);
    await service.completeExternal(delivery);

    expect(calls, [
      ('consumeNfcDelivery', null),
      ('completeExternalNfcDelivery', <String, Object?>{'id': 12}),
    ]);
  });

  test('missing or malformed native metadata defaults to foreground', () async {
    final service = AndroidNfcDeliveryContextService(
      isAndroid: true,
      invoke: (method, arguments) async => <String, Object?>{
        'id': 'not-an-int',
        'external': true,
      },
    );

    final delivery = await service.consume();
    expect(delivery.mode, NfcDeliveryMode.foreground);
    expect(delivery.id, isNull);
  });

  test('unsupported platforms never invoke the Android channel', () async {
    var calls = 0;
    final service = AndroidNfcDeliveryContextService(
      isAndroid: false,
      invoke: (method, arguments) async {
        calls++;
        return null;
      },
    );

    final delivery = await service.consume();
    await service.completeExternal(delivery);
    await service.showExternalMessage('Play logged');

    expect(delivery.mode, NfcDeliveryMode.foreground);
    expect(calls, 0);
  });
}
