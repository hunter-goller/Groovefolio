import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

void main() {
  test('genre names merge genres and styles, first spelling wins', () {
    const details = DiscogsReleaseDetails(
      releaseId: 1,
      title: 'Blue Train',
      artist: 'John Coltrane',
      genres: ['Jazz', ' ', 'jazz'],
      styles: ['Hard Bop', 'JAZZ', ' Hard bop '],
    );
    expect(details.genreNames, ['Jazz', 'Hard Bop']);
  });

  test('a collection item is vinyl when any format says so', () {
    const vinyl = DiscogsCollectionItem(
      releaseId: 1,
      instanceId: 2,
      title: 'Blue Train',
      artist: 'John Coltrane',
      formats: ['LP', ' Vinyl '],
    );
    const cd = DiscogsCollectionItem(
      releaseId: 3,
      instanceId: 4,
      title: 'Homogenic',
      artist: 'Björk',
      formats: ['CD'],
    );
    expect(vinyl.isVinyl, isTrue);
    expect(cd.isVinyl, isFalse);
  });

  test('a collection page knows whether more pages follow', () {
    const first = DiscogsCollectionPage(
      items: [],
      page: 1,
      pages: 2,
      totalItems: 101,
    );
    const last = DiscogsCollectionPage(
      items: [],
      page: 2,
      pages: 2,
      totalItems: 101,
    );
    expect(first.hasNextPage, isTrue);
    expect(last.hasNextPage, isFalse);
  });
}
