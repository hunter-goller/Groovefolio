import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _backupDomains = <String>[
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

void main() {
  test(
    'Android manifest disables automatic backup and references both rules',
    () async {
      final manifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();

      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    },
  );

  test('Android 11 and earlier rules exclude every backup domain', () async {
    final rules = await File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsString();

    expect(rules, contains('<full-backup-content>'));
    for (final domain in _backupDomains) {
      expect(
        rules,
        contains('<exclude domain="$domain" path="." />'),
        reason: '$domain must be excluded from legacy Android backup',
      );
    }
  });

  test('Android 12+ rules exclude cloud and device-transfer data', () async {
    final rules = await File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsString();

    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    for (final domain in _backupDomains) {
      expect(
        '<exclude domain="$domain" path="." />'.allMatches(rules),
        hasLength(2),
        reason: '$domain must be excluded from both Android 12+ modes',
      );
    }
  });
}
