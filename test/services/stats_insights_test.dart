import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Local wall-clock times, stored as UTC like the app does.
final _now = DateTime(2026, 11, 24, 21);

Album _album(String id) =>
    Album(id: id, title: id, artistId: 'artist', createdAt: '2025-01-01');

var _ids = 0;
Play _play(
  String albumId,
  DateTime local, [
  SidePlayed side = SidePlayed.full,
]) {
  final iso = local.toUtc().toIso8601String();
  return Play(
    id: 'p${_ids++}',
    albumId: albumId,
    playedAt: iso,
    sidePlayed: side,
    createdAt: iso,
  );
}

DateTime _daysAgo(int days, [int hour = 20]) =>
    DateTime(_now.year, _now.month, _now.day - days, hour);

StatsInsights _insights(List<Play> plays, {int? year, List<Album>? albums}) =>
    StatsSnapshot(
      albums: albums ?? [_album('a'), _album('b'), _album('c')],
      plays: plays,
      genresByAlbum: const {},
      now: _now,
    ).insights(year: year);

void main() {
  group('streaks', () {
    test('counts consecutive days ending today', () {
      final insights = _insights([
        _play('a', _daysAgo(0)),
        _play('a', _daysAgo(0, 9)),
        _play('b', _daysAgo(1)),
        _play('a', _daysAgo(2)),
        _play('a', _daysAgo(5)),
      ]);
      expect(insights.currentStreakDays, 3);
      expect(insights.longestStreakDays, 3);
    });

    test('a streak ending yesterday is still alive today', () {
      final insights = _insights([
        _play('a', _daysAgo(1)),
        _play('a', _daysAgo(2)),
      ]);
      expect(insights.currentStreakDays, 2);
    });

    test('a gap of a day ends the current streak but keeps the best', () {
      final insights = _insights([
        _play('a', _daysAgo(2)),
        for (var day = 10; day < 16; day++) _play('a', _daysAgo(day)),
      ]);
      expect(insights.currentStreakDays, 0);
      expect(insights.longestStreakDays, 6);
    });

    test('streaks cross month and year boundaries', () {
      final insights = StatsSnapshot(
        albums: [_album('a')],
        plays: [
          _play('a', DateTime(2025, 12, 30, 20)),
          _play('a', DateTime(2025, 12, 31, 20)),
          _play('a', DateTime(2026, 1, 1, 20)),
          _play('a', DateTime(2026, 1, 2, 20)),
        ],
        genresByAlbum: const {},
        now: DateTime(2026, 1, 2, 22),
      ).insights();
      expect(insights.currentStreakDays, 4);
      expect(insights.longestStreakDays, 4);
    });
  });

  group('compared with last year', () {
    test('year range compares year to date with the same dates last year', () {
      final insights = _insights([
        _play('a', DateTime(2026, 1, 3, 20)),
        _play('a', DateTime(2026, 11, 24, 8)),
        _play('a', DateTime(2025, 2, 1, 20)),
        // After today's date last year, so not part of the comparison.
        _play('a', DateTime(2025, 12, 1, 20)),
      ], year: 2026);
      expect(insights.periodPlays, 2);
      expect(insights.previousPeriodPlays, 1);
    });

    test('all time compares the last 12 months with the 12 before', () {
      final insights = _insights([
        _play('a', _daysAgo(10)),
        _play('a', _daysAgo(300)),
        _play('a', _daysAgo(400)),
        _play('a', _daysAgo(800)),
      ]);
      expect(insights.periodPlays, 2);
      expect(insights.previousPeriodPlays, 1);
    });
  });

  group('habits', () {
    test('busiest weekday needs enough plays', () {
      final sunday = DateTime(2026, 11, 22, 20);
      expect(sunday.weekday, DateTime.sunday);
      final few = _insights([for (var i = 0; i < 4; i++) _play('a', sunday)]);
      expect(few.busiestWeekday, isNull);

      final many = _insights([
        for (var i = 0; i < 4; i++) _play('a', sunday),
        _play('a', DateTime(2026, 11, 18, 20)),
      ]);
      expect(many.busiestWeekday, DateTime.sunday);
      expect(many.busiestWeekdayPlays, 4);
    });

    test('side balance and busiest day follow the year filter', () {
      final insights = _insights([
        _play('a', DateTime(2026, 3, 1, 20), SidePlayed.sideA),
        _play('a', DateTime(2026, 3, 2, 20), SidePlayed.sideB),
        _play('a', DateTime(2025, 3, 1, 20), SidePlayed.sideA),
        _play('a', DateTime(2025, 3, 2, 20), SidePlayed.full),
      ], year: 2026);
      expect(insights.sideAPlays, 1);
      expect(insights.sideBPlays, 1);
      expect(insights.busiestWeekday, isNull);
    });
  });

  test('never-played counts records without any play, ever', () {
    final insights = _insights([
      _play('a', DateTime(2024, 1, 1, 20)),
    ], year: 2026);
    expect(insights.neverPlayedAlbums, 2);
  });

  test('no plays gives empty insights', () {
    final insights = _insights(const []);
    expect(insights.currentStreakDays, 0);
    expect(insights.longestStreakDays, 0);
    expect(insights.periodPlays, 0);
    expect(insights.busiestWeekday, isNull);
    expect(insights.neverPlayedAlbums, 3);
  });
}
