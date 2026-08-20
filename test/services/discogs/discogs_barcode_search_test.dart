import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';

void main() {
  test('barcode candidates normalize punctuation and retry UPC as EAN-13', () {
    expect(discogsBarcodeSearchCandidates('0 74643-37751 2'), [
      '074643377512',
      '0074643377512',
    ]);
  });

  test('barcode candidates retry zero-prefixed EAN-13 as UPC-A', () {
    expect(discogsBarcodeSearchCandidates('0074643377512'), [
      '0074643377512',
      '074643377512',
    ]);
  });

  test('barcode candidates reject empty input', () {
    expect(() => discogsBarcodeSearchCandidates(' -- '), throwsArgumentError);
  });
}
