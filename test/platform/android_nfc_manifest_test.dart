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
      final activities = RegExp(
        r'<activity\b[^>]*>[\s\S]*?</activity>',
      ).allMatches(manifest).map((match) => match.group(0)!).toList();
      String activity(String name) => activities.singleWhere(
        (element) => element.contains('android:name=".$name"'),
      );

      final main = activity('MainActivity');
      expect(main, contains('android:launchMode="singleTask"'));
      expect(main, isNot(contains('android:taskAffinity=')));
      expect(main, contains('android.intent.category.LAUNCHER'));
      expect(main, isNot(contains('android.nfc.action.NDEF_DISCOVERED')));

      final entry = activity('NfcEntryActivity');
      expect(entry, contains('android:exported="true"'));
      expect(entry, contains('android:taskAffinity=""'));
      expect(entry, contains('android:theme="@style/NfcTransparentTheme"'));
      expect(entry, contains('android.nfc.action.NDEF_DISCOVERED'));
      expect(entry, contains('android:host="album"'));

      final processor = activity('NfcProcessingActivity');
      expect(processor, contains('android:exported="false"'));
      expect(processor, contains('android:excludeFromRecents="true"'));
      expect(processor, contains('android:theme="@style/NfcTransparentTheme"'));
      expect(processor, isNot(contains('<intent-filter>')));
    },
  );

  test('cold launch guards the payload before Flutter attaches', () {
    final activity = File(
      'android/app/src/main/kotlin/com/huntergoller/vinyl_app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('override fun onNewIntent(intent: Intent)'));
    final create = activity.indexOf('override fun onCreate(');
    final guard = activity.indexOf(
      'shouldSuppressAlbumNfcIntent(intent)',
      create,
    );
    final sanitize = activity.indexOf('intent = Intent(', create);
    final attach = activity.indexOf(
      'super.onCreate(savedInstanceState)',
      create,
    );
    expect(create, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(create));
    expect(sanitize, greaterThan(guard));
    expect(attach, greaterThan(sanitize));
  });
}
