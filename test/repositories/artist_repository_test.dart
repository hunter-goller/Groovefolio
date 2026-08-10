import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';

void main() {
  late AppDatabase db;
  late ArtistRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ArtistRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'findOrCreate creates an artist when no matching artist exists',
    () async {
      final created = await repository.findOrCreate('Miles Davis');
      final stored = await repository.findById(created.id);

      expect(created.name, 'Miles Davis');
      expect(created.id, startsWith('artist-'));
      expect(stored, created);
    },
  );

  test(
    'findOrCreate is idempotent for case-insensitive name matches',
    () async {
      final first = await repository.findOrCreate('John Coltrane');
      final second = await repository.findOrCreate('jOhN cOlTrAnE');
      final artists = await repository.findAll();

      expect(second.id, first.id);
      expect(second.name, first.name);
      expect(artists, hasLength(1));
    },
  );

  test('findOrCreate trims the name before matching and creating', () async {
    final first = await repository.findOrCreate('  Daft Punk  ');
    final second = await repository.findOrCreate('daft punk');

    expect(first.name, 'Daft Punk');
    expect(second.id, first.id);
    expect(await repository.findAll(), hasLength(1));
  });

  test('findOrCreate rejects an empty artist name', () async {
    expect(() => repository.findOrCreate('   '), throwsA(isA<ArgumentError>()));
  });

  test('findById returns the matching artist and null when missing', () async {
    final created = await repository.findOrCreate('Nina Simone');

    final found = await repository.findById(created.id);
    final missing = await repository.findById('missing');

    expect(found, created);
    expect(missing, isNull);
  });

  test('findAll returns every artist', () async {
    await repository.findOrCreate('Miles Davis');
    await repository.findOrCreate('John Coltrane');

    final artists = await repository.findAll();

    expect(artists, hasLength(2));
    expect(artists.map((artist) => artist.name).toSet(), {
      'Miles Davis',
      'John Coltrane',
    });
  });
}
