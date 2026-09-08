import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android manifest declares optional NFC and the album intent filter',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.NFC'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.hardware.nfc'));
      expect(manifest, contains('android:required="false"'));
      expect(manifest, contains('android.nfc.action.NDEF_DISCOVERED'));
      expect(manifest, contains('android:scheme="groovefolio"'));
      expect(manifest, contains('android:host="album"'));
    },
  );

  test('Android drops album intents during foreground NFC operations', () {
    final activity = File(
      'android/app/src/main/kotlin/com/huntergoller/vinyl_app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('override fun onNewIntent(intent: Intent)'));
    expect(activity, contains('NfcAdapter.ACTION_NDEF_DISCOVERED'));
    expect(activity, contains('foregroundNfcOperationActive'));
    expect(activity, contains('FOREGROUND_INTENT_COOLDOWN_MILLIS'));
  });
}
