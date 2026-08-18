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

  test('maps a paginated Discogs collection response', () {
    final page = discogsCollectionPageFromJson({
      'pagination': {'page': 1, 'pages': 2, 'per_page': 100, 'items': 101},
      'releases': [
        {
          'id': 123,
          'instance_id': 456,
          'basic_information': {
            'id': 123,
            'title': 'Blue Train',
            'year': 1957,
            'artists': [
              {'name': 'John Coltrane (2)'},
            ],
            'labels': [
              {'name': 'Blue Note'},
            ],
            'formats': [
              {
                'name': 'Vinyl',
                'descriptions': ['LP', 'Album'],
              },
            ],
            'cover_image': 'https://example.test/blue-train.jpg',
          },
        },
      ],
    });

    expect(page.page, 1);
    expect(page.pages, 2);
    expect(page.totalItems, 101);
    expect(page.hasNextPage, isTrue);
    expect(page.items, hasLength(1));

    final item = page.items.single;
    expect(item.releaseId, 123);
    expect(item.instanceId, 456);
    expect(item.title, 'Blue Train');
    expect(item.artist, 'John Coltrane');
    expect(item.year, 1957);
    expect(item.label, 'Blue Note');
    expect(item.formats, ['Vinyl', 'LP', 'Album']);
    expect(item.isVinyl, isTrue);
  });
}
