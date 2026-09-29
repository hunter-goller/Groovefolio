import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android uses the permanent Groovefolio application ID', () {
    final buildFile = File('android/app/build.gradle.kts').readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/app/groovefolio/MainActivity.kt',
    ).readAsStringSync();

    expect(buildFile, contains('namespace = "app.groovefolio"'));
    expect(buildFile, contains('applicationId = "app.groovefolio"'));
    expect(mainActivity, startsWith('package app.groovefolio'));
    expect(buildFile, isNot(contains('com.huntergoller.vinyl_app')));
  });

  test('Android native sources and activities keep the release namespace', () {
    final sources = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));
    expect(sources, isNotEmpty);
    for (final source in sources) {
      expect(
        source.readAsStringSync(),
        startsWith('package app.groovefolio'),
        reason: source.path,
      );
    }
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:taskAffinity="app.groovefolio.nfc"'));
    expect(manifest, contains('android:scheme="groovefolio"'));
    expect(manifest, contains('android:host="discogs-auth"'));
    expect(manifest, isNot(contains('com.huntergoller.vinyl_app')));
  });

  test('release source remains free of AdMob and advertising identifiers', () {
    for (final path in ['pubspec.yaml', 'pubspec.lock']) {
      final contents = File(path).readAsStringSync();
      for (final dependency in [
        'google_mobile_ads:',
        'google_mobile_ads_platform_interface:',
        'user_messaging_platform:',
      ]) {
        expect(contents, isNot(contains(dependency)), reason: path);
      }
    }
    for (final source
        in Directory('android/app/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('AndroidManifest.xml'))) {
      final contents = source.readAsStringSync();
      expect(
        contents,
        isNot(contains('com.google.android.gms.permission.AD_ID')),
      );
      expect(
        contents,
        isNot(contains('com.google.android.gms.ads.APPLICATION_ID')),
      );
    }
    for (final source
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        source.readAsStringSync(),
        isNot(contains('package:google_mobile_ads/')),
        reason: source.path,
      );
    }
  });
}
