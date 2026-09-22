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
}
