import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vinyl_app/services/artwork_storage_service.dart';

void main() {
  late Directory tempRoot;
  late Directory documentsDirectory;
  late ArtworkStorageService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'vinyl-artwork-storage-test-',
    );
    documentsDirectory = Directory(p.join(tempRoot.path, 'documents'));
    await documentsDirectory.create();

    service = ArtworkStorageService(
      documentsDirectoryResolver: () async => documentsDirectory,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('saveArtwork stores a stable jpg under documents/artwork', () async {
    final source = File(p.join(tempRoot.path, 'picked.png'));
    await source.writeAsBytes([1, 2, 3]);

    final storedPath = await service.saveArtwork(source, 'album-1');

    expect(
      storedPath,
      p.join(documentsDirectory.path, 'artwork', 'album-1.jpg'),
    );
    expect(await File(storedPath).readAsBytes(), [1, 2, 3]);
    expect(p.isWithin(documentsDirectory.path, storedPath), isTrue);
  });

  test('saving twice for the same album replaces the existing file', () async {
    final first = File(p.join(tempRoot.path, 'first.jpg'));
    final second = File(p.join(tempRoot.path, 'second.jpg'));
    await first.writeAsBytes([1, 1, 1]);
    await second.writeAsBytes([9, 9]);

    final firstPath = await service.saveArtwork(first, 'album-1');
    final secondPath = await service.saveArtwork(second, 'album-1');

    expect(secondPath, firstPath);
    expect(await File(secondPath).readAsBytes(), [9, 9]);

    final artworkFiles = Directory(
      p.join(documentsDirectory.path, 'artwork'),
    ).listSync().whereType<File>().toList();
    expect(artworkFiles, hasLength(1));
  });

  test('deleteArtwork is idempotent for null and missing files', () async {
    await service.deleteArtwork(null);
    await service.deleteArtwork('');
    await service.deleteArtwork(p.join(tempRoot.path, 'missing.jpg'));
  });

  test('deleteArtwork removes an existing stored file', () async {
    final source = File(p.join(tempRoot.path, 'picked.jpg'));
    await source.writeAsBytes([4, 5, 6]);
    final storedPath = await service.saveArtwork(source, 'album-2');

    await service.deleteArtwork(storedPath);

    expect(await File(storedPath).exists(), isFalse);
  });

  test('artworkFile returns a file only while the path exists', () async {
    final source = File(p.join(tempRoot.path, 'picked.jpg'));
    await source.writeAsBytes([7, 8]);
    final storedPath = await service.saveArtwork(source, 'album-3');

    expect(service.artworkFile(storedPath)?.path, storedPath);

    await File(storedPath).delete();

    expect(service.artworkFile(storedPath), isNull);
    expect(service.artworkFile(null), isNull);
    expect(service.artworkFile(''), isNull);
  });

  test('saveArtwork rejects empty album ids and missing sources', () async {
    final source = File(p.join(tempRoot.path, 'picked.jpg'));
    await source.writeAsBytes([1]);

    await expectLater(service.saveArtwork(source, '  '), throwsArgumentError);
    await expectLater(
      service.saveArtwork(
        File(p.join(tempRoot.path, 'does-not-exist.jpg')),
        'album-1',
      ),
      throwsArgumentError,
    );
  });
}
