import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('genre names are unique case-insensitively', () async {
    await db
        .into(db.genres)
        .insert(
          GenresCompanion.insert(
            id: 'genre-1',
            name: 'Progressive Rock',
            createdAt: '2026-08-14T20:00:00.000Z',
          ),
        );

    await expectLater(
      db
          .into(db.genres)
          .insert(
            GenresCompanion.insert(
              id: 'genre-2',
              name: 'progressive rock',
              createdAt: '2026-08-14T20:01:00.000Z',
            ),
          ),
      throwsA(anything),
    );
  });

  test('distinct genre names can coexist', () async {
    await db.batch((batch) {
      batch.insert(
        db.genres,
        GenresCompanion.insert(
          id: 'genre-1',
          name: 'Progressive Rock',
          createdAt: '2026-08-14T20:00:00.000Z',
        ),
      );
      batch.insert(
        db.genres,
        GenresCompanion.insert(
          id: 'genre-2',
          name: 'Art Rock',
          createdAt: '2026-08-14T20:01:00.000Z',
        ),
      );
    });

    final genres = await db.select(db.genres).get();
    expect(genres, hasLength(2));
  });
}
