import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

void main() {
  test('maps Discogs search result into typed release summary', () {
    final result = discogsReleaseSearchResultFromJson({
      'id': 249504,
      'title': 'John Coltrane (2) - A Love Supreme',
      'year': '1965',
      'label': ['Impulse!'],
      'country': 'US',
      'format': ['Vinyl', 'LP', 'Album'],
      'cover_image': 'https://example.test/cover.jpg',
    });

    expect(result, isNotNull);
    expect(result!.releaseId, 249504);
    expect(result.artist, 'John Coltrane');
    expect(result.title, 'A Love Supreme');
    expect(result.year, 1965);
    expect(result.label, 'Impulse!');
    expect(result.country, 'US');
    expect(result.formats, ['Vinyl', 'LP', 'Album']);
  });

  test(
    'maps release details and combines genres/styles without duplicates',
    () {
      final details = discogsReleaseDetailsFromJson({
        'title': 'Blue Train',
        'year': 1957,
        'artists': [
          {'name': 'John Coltrane (2)'},
        ],
        'labels': [
          {'name': 'Blue Note'},
        ],
        'genres': ['Jazz'],
        'styles': ['Hard Bop', 'Jazz'],
        'images': [
          {'type': 'primary', 'uri': 'https://example.test/full.jpg'},
        ],
      }, releaseId: 123);

      expect(details.releaseId, 123);
      expect(details.title, 'Blue Train');
      expect(details.artist, 'John Coltrane');
      expect(details.year, 1957);
      expect(details.label, 'Blue Note');
      expect(details.genreNames, ['Jazz', 'Hard Bop']);
      expect(details.artworkUrl, 'https://example.test/full.jpg');
    },
  );
}
