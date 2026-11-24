import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/backup/rescue_copy_service.dart';

void main() {
  late Directory docs;
  late RescueCopyService service;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('groovefolio_rescue_test');
    service = RescueCopyService(
      documentsDirectoryResolver: () async => docs,
      clock: () => DateTime(2026, 11, 23, 8),
    );
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  void write(String relative, List<int> bytes) {
    File('${docs.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  Map<String, List<int>> entries(List<int> zip) => {
    for (final file in ZipDecoder().decodeBytes(zip).files)
      if (file.isFile) file.name: file.content,
  };

  test(
    'copies the database, its sidecar files and covers without opening it',
    () async {
      write(AppDatabase.fileName, [1, 2, 3]);
      write('${AppDatabase.fileName}-wal', [4, 5]);
      write('artwork/album-1.jpg', [9, 9, 9]);
      write('artwork/album-2.jpg', [8]);
      write('unrelated.txt', [7]);
      write('artwork/nested/ignored.jpg', [6]);

      final copy = entries(await service.createRescueCopy());

      expect(copy['database/${AppDatabase.fileName}'], [1, 2, 3]);
      expect(copy['database/${AppDatabase.fileName}-wal'], [4, 5]);
      expect(copy['artwork/album-1.jpg'], [9, 9, 9]);
      expect(copy['artwork/album-2.jpg'], [8]);
      expect(copy.keys, isNot(contains('unrelated.txt')));
      expect(copy.keys.where((name) => name.contains('nested')), isEmpty);

      final manifest =
          jsonDecode(utf8.decode(copy[RescueCopyFormat.manifestName]!))
              as Map<String, Object?>;
      expect(manifest['format'], RescueCopyFormat.name);
      expect(manifest['formatVersion'], 1);
      expect(manifest['databaseFiles'], [
        AppDatabase.fileName,
        '${AppDatabase.fileName}-wal',
      ]);
      expect(manifest['artworkFiles'], 2);
      expect(
        manifest['createdAt'],
        DateTime(2026, 11, 23, 8).toUtc().toIso8601String(),
      );
    },
  );

  test('works with no covers', () async {
    write(AppDatabase.fileName, [1]);
    final copy = entries(await service.createRescueCopy());
    expect(copy.keys, {
      'database/${AppDatabase.fileName}',
      RescueCopyFormat.manifestName,
    });
  });

  test('fails clearly when there is no database file', () async {
    write('artwork/album-1.jpg', [9]);
    await expectLater(
      service.createRescueCopy(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('suggested file name uses the local date', () {
    expect(service.suggestedFileName(), 'groovefolio-rescue-2026-11-23.zip');
  });
}
