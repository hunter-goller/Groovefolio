import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/types/side_played.dart';

final _now = DateTime.parse('2026-08-24T12:00:00.000Z');

Album _album(String id, String title, {String artist = 'solo'}) => Album(
  id: id,
  title: title,
  artistId: artist,
  createdAt: '2025-01-01T00:00:00.000Z',
);

var _ids = 0;
Play _play(String albumId, String date) {
  final at = '${date}T12:00:00.000Z';
  return Play(
    id: 'p${_ids++}',
    albumId: albumId,
    playedAt: at,
    sidePlayed: SidePlayed.full,
    createdAt: at,
  );
}

RecommendationService _service(
  List<Album> albums,
  List<Play> plays, {
  DateTime? now,
  Map<String, String> artists = const {},
}) => RecommendationService(
  albumRepository: _Albums(albums),
  artistRepository: _Artists({
    for (final album in albums)
      album.artistId: artists[album.artistId] ?? album.artistId,
  }),
  playRepository: _Plays(plays),
  genreRepository: _Genres(),
  now: () => now ?? _now,
);

Iterable<String> _ids0(List<AlbumRecommendation> list) =>
    list.map((item) => item.album.id);

void _expectNoDuplicates(DiscoverRecommendations result) {
  final all = [
    ...result.pairings,
    ...result.rediscover,
    ...result.genrePicks,
    ...result.deepCuts,
    ...result.eraPicks,
    ...result.underplayed,
  ].map((item) => item.album.id).toList();
  expect(all.toSet().length, all.length, reason: 'a record is on two shelves');
}

void main() {
  group('because you played', () {
    final kob = _album('kob', 'Kind of Blue', artist: 'miles');
    final bt = _album('bt', 'Blue Train', artist: 'trane');

    test('suggests records played on the same days as a recent play', () async {
      final loner = _album('loner', 'Loner');
      final fresh = _album('fresh', 'Fresh');
      final result = await _service(
        [kob, bt, loner, fresh],
        [
          for (final day in ['2026-03-01', '2026-03-02', '2026-03-03']) ...[
            _play('kob', day),
            _play('bt', day),
            _play('fresh', day),
          ],
          for (final day in ['2026-04-01', '2026-04-02', '2026-04-03'])
            _play('loner', day),
          // Played within the last 30 days, so not suggested again yet.
          _play('fresh', '2026-08-10'),
          _play('kob', '2026-08-23'),
        ],
      ).getRecommendations();

      expect(_ids0(result.pairings), ['bt']);
      expect(result.pairingSeedTitle, 'Kind of Blue');
      final pick = result.pairings.single;
      expect(pick.kind, RecommendationKind.pairing);
      expect(
        pick.reason,
        'Played with Kind of Blue on 3 days • '
        'Last played Mar 3, 2026 (5 months ago)',
      );
      expect(pick.evidence.first.title, 'Played together on 3 days');
      expect(
        pick.evidence.first.detail,
        'On 3 of the 3 days you played Blue Train, you also played Kind of '
        'Blue.',
      );
      expect(pick.evidence[1].title, 'You just played Kind of Blue');
      _expectNoDuplicates(result);
    });

    test('a record that only sometimes overlaps is not "often"', () async {
      final result = await _service(
        [kob, bt],
        [
          for (var day = 1; day <= 10; day++)
            _play('bt', '2026-03-${day.toString().padLeft(2, '0')}'),
          _play('kob', '2026-03-01'),
          _play('kob', '2026-03-02'),
          _play('kob', '2026-08-23'),
        ],
      ).getRecommendations();
      // 2 shared days out of 10 is below the 25% bar.
      expect(result.pairings, isEmpty);
    });

    test('one shared day is not enough', () async {
      final result = await _service(
        [kob, bt],
        [
          _play('kob', '2026-03-01'),
          _play('bt', '2026-03-01'),
          _play('kob', '2026-08-23'),
        ],
      ).getRecommendations();
      expect(result.pairings, isEmpty);
    });

    test('picks for different recent records get a general title', () async {
      final mez = _album('mez', 'Mezzanine', artist: 'ma');
      final dum = _album('dum', 'Dummy', artist: 'ph');
      final result = await _service(
        [kob, bt, mez, dum],
        [
          for (final day in ['2026-03-01', '2026-03-02']) ...[
            _play('kob', day),
            _play('bt', day),
          ],
          for (final day in ['2026-04-01', '2026-04-02']) ...[
            _play('dum', day),
            _play('mez', day),
          ],
          _play('kob', '2026-08-23'),
          _play('dum', '2026-08-22'),
        ],
      ).getRecommendations();
      expect(_ids0(result.pairings).toSet(), {'bt', 'mez'});
      expect(result.pairingSeedTitle, isNull);
    });

    test('nothing played in the last two weeks means no pairings', () async {
      final result = await _service(
        [kob, bt],
        [
          for (final day in ['2026-03-01', '2026-03-02']) ...[
            _play('kob', day),
            _play('bt', day),
          ],
          _play('kob', '2026-08-01'),
        ],
      ).getRecommendations();
      expect(result.pairings, isEmpty);
    });
  });

  group('deep cuts', () {
    test('suggests barely played records by a much-played artist', () async {
      final albums = [
        _album('fav', 'Rumours', artist: 'fm'),
        _album('never', 'Tusk', artist: 'fm'),
        _album('once', 'Mirage', artist: 'fm'),
        _album('twice', 'Tango in the Night', artist: 'fm'),
        _album('casual', 'Casual Fav', artist: 'casual'),
        _album('casual2', 'Casual Other', artist: 'casual'),
      ];
      final result = await _service(
        albums,
        [
          for (var day = 1; day <= 6; day++)
            _play('fav', '2026-07-${day.toString().padLeft(2, '0')}'),
          _play('once', '2026-07-10'),
          _play('twice', '2026-07-11'),
          _play('twice', '2026-07-12'),
          for (var day = 1; day <= 4; day++)
            _play('casual', '2026-07-${day.toString().padLeft(2, '0')}'),
        ],
        artists: const {'fm': 'Fleetwood Mac'},
      ).getRecommendations();

      // Unplayed first, then played once; the favorite and the record with
      // two plays are left out, as is the artist with only 4 plays.
      expect(_ids0(result.deepCuts), ['never', 'once']);
      expect(
        result.deepCuts[1].reason,
        'You’ve played Fleetwood Mac 9 times • this one just once',
      );
      final pick = result.deepCuts.first;
      expect(pick.kind, RecommendationKind.deepCut);
      expect(
        pick.reason,
        'You’ve played Fleetwood Mac 9 times • never this one',
      );
      expect(pick.evidence.map((item) => item.title), [
        'An artist you play a lot',
        'Your favorite of theirs',
        'This record',
      ]);
      expect(pick.evidence[1].detail, 'Rumours • 6 plays logged');
      _expectNoDuplicates(result);
    });

    test('at most two per artist', () async {
      final albums = [
        _album('fav', 'Fav', artist: 'a'),
        for (var i = 0; i < 4; i++) _album('cut$i', 'Cut $i', artist: 'a'),
      ];
      final result = await _service(albums, [
        for (var day = 1; day <= 6; day++)
          _play('fav', '2026-07-${day.toString().padLeft(2, '0')}'),
      ]).getRecommendations();
      expect(result.deepCuts, hasLength(2));
    });
  });

  group('daily rotation', () {
    List<Album> manyUnplayed() => [
      for (var i = 0; i < 20; i++)
        _album('u${i.toString().padLeft(2, '0')}', 'Unplayed $i'),
    ];

    Future<List<String>> shelfOn(DateTime now) async {
      final result = await _service(
        manyUnplayed(),
        const [],
        now: now,
      ).getRecommendations();
      _expectNoDuplicates(result);
      return _ids0(result.underplayed).toList();
    }

    test('keeps the top picks and changes the rest each day', () async {
      final monday = await shelfOn(DateTime(2026, 8, 24, 10));
      final mondayNight = await shelfOn(DateTime(2026, 8, 24, 23));
      final tuesday = await shelfOn(DateTime(2026, 8, 25, 10));

      expect(monday, hasLength(6));
      expect(mondayNight, monday, reason: 'same picks all day');
      expect(tuesday.take(3), monday.take(3), reason: 'best picks stay');
      expect(tuesday.skip(3), isNot(monday.skip(3)));
      expect(tuesday.toSet(), hasLength(6));
    });

    test('short shelves are unchanged', () async {
      final albums = manyUnplayed().take(4).toList();
      final a = await _service(
        albums,
        const [],
        now: DateTime(2026, 8, 24),
      ).getRecommendations();
      final b = await _service(
        albums,
        const [],
        now: DateTime(2026, 8, 25),
      ).getRecommendations();
      expect(_ids0(a.underplayed), _ids0(b.underplayed));
    });
  });
}

class _Albums implements IAlbumRepository {
  _Albums(this.albums);
  final List<Album> albums;
  @override
  Future<List<Album>> findAll() async => albums;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Artists implements IArtistRepository {
  _Artists(this.names);
  final Map<String, String> names;
  @override
  Future<List<Artist>> findAll() async => [
    for (final entry in names.entries)
      Artist(id: entry.key, name: entry.value, createdAt: '2025-01-01'),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plays implements IPlayRepository {
  _Plays(this.plays);
  final List<Play> plays;
  @override
  Future<List<Play>> findAll() async => plays;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Genres implements IGenreRepository {
  @override
  Future<Map<String, List<Genre>>> findAllByAlbum() async => const {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
