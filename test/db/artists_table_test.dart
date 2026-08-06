import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  test('can insert and select an artist', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: 'artist-1',
            name: 'John Coltrane',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

    final result = await db.select(db.artists).getSingle();

    expect(result.id, 'artist-1');
    expect(result.name, 'John Coltrane');

    await db.close();
  });
}
