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

  test(
    'no manifest lets Android route arbitrary NFC tags or payment cards',
    () {
      // Payment cards and unrelated tags only reach an app through broad
      // TECH_DISCOVERED or TAG_DISCOVERED filters, or an NDEF filter without
      // the Groovefolio URI. Debug and profile manifests merge into builds.
      final manifests = Directory('android/app/src')
          .listSync()
          .whereType<Directory>()
          .map((dir) => File('${dir.path}/AndroidManifest.xml'))
          .where((file) => file.existsSync())
          .toList();
      expect(
        manifests.map((file) => file.path),
        contains(endsWith('main/AndroidManifest.xml')),
      );

      for (final file in manifests) {
        final manifest = file.readAsStringSync();
        expect(
          manifest,
          isNot(contains('android.nfc.action.TECH_DISCOVERED')),
          reason: '${file.path} must not declare TECH_DISCOVERED',
        );
        expect(
          manifest,
          isNot(contains('android.nfc.action.TAG_DISCOVERED')),
          reason: '${file.path} must not declare TAG_DISCOVERED',
        );

        final ndefFilters =
            RegExp(r'<intent-filter\b[^>]*>[\s\S]*?</intent-filter>')
                .allMatches(manifest)
                .map((match) => match.group(0)!)
                .where((filter) => filter.contains('NDEF_DISCOVERED'));
        for (final filter in ndefFilters) {
          final data = RegExp(
            r'<data\b[^>]*/>',
          ).allMatches(filter).map((match) => match.group(0)!).toList();
          expect(
            data,
            hasLength(1),
            reason: 'NDEF filters must declare exactly one <data> element',
          );
          expect(data.single, contains('android:scheme="groovefolio"'));
          expect(data.single, contains('android:host="album"'));
          expect(data.single, isNot(contains('android:mimeType')));
        }
      }
    },
  );

  test('cold launch guards the payload before Flutter attaches', () {
    final activity = File(
      'android/app/src/main/kotlin/app/groovefolio/MainActivity.kt',
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
