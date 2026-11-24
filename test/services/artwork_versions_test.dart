import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/artwork_versions.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/resilient_image.dart';

void main() {
  late Directory tempRoot;
  late ArtworkStorageService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('groovefolio-versions-');
    service = ArtworkStorageService(
      documentsDirectoryResolver: () async => tempRoot,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('images for the same file and version are equal', () {
    final file = File('/data/artwork/a.jpg');
    expect(
      ArtworkFileImage(file, version: 2),
      ArtworkFileImage(file, version: 2),
    );
    expect(
      ArtworkFileImage(file, version: 2),
      isNot(ArtworkFileImage(file, version: 3)),
    );
    expect(
      ArtworkFileImage(file, version: 2).hashCode,
      ArtworkFileImage(file, version: 2).hashCode,
    );
  });

  test(
    'saving, restoring and deleting artwork each change its image',
    () async {
      final path = await service.saveArtworkBytes(
        Uint8List.fromList([1, 2, 3]),
        'album-1',
      );
      final afterFirstSave = ArtworkFileImage(File(path));

      await service.saveArtworkBytes(Uint8List.fromList([4, 5, 6]), 'album-1');
      final afterReplace = ArtworkFileImage(File(path));
      expect(afterReplace, isNot(afterFirstSave));

      await service.restoreArtworkBytes(path, [1, 2, 3]);
      final afterRestore = ArtworkFileImage(File(path));
      expect(afterRestore, isNot(afterReplace));
      expect(await File(path).readAsBytes(), [1, 2, 3]);

      await service.deleteArtwork(path);
      expect(ArtworkFileImage(File(path)), isNot(afterRestore));
    },
  );

  testWidgets('a shown cover switches to the replaced file on rebuild', (
    tester,
  ) async {
    final path = p.join(tempRoot.path, 'artwork', 'album-2.jpg');
    await tester.runAsync(
      () => service.saveArtworkBytes(Uint8List.fromList([1]), 'album-2'),
    );
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, _) => ResilientImage.file(
            path: path,
            operation: 'load test artwork',
            fallback: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    final before = tester.widget<Image>(find.byType(Image)).image;

    await tester.runAsync(
      () => service.saveArtworkBytes(Uint8List.fromList([2]), 'album-2'),
    );
    rebuild.value++;
    await tester.pump();
    final after = tester.widget<Image>(find.byType(Image)).image;

    expect(after, isNot(before));
    expect(PaintingBinding.instance.imageCache.containsKey(before), isFalse);
  });
}
