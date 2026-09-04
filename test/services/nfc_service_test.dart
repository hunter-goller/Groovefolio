import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';

void main() {
  test('availability reports disabled without throwing', () async {
    final fixture = _Fixture(availability: NfcAvailabilityState.disabled);

    expect(await fixture.service.availability(), NfcAvailabilityState.disabled);
    expect(fixture.platform.pollCalls, 0);
  });

  test(
    'writeTag writes the album URI and saves the normalized tag ID',
    () async {
      final fixture = _Fixture();

      final association = await fixture.service.writeTag(' album-1 ');

      expect(
        fixture.platform.writtenUri,
        Uri.parse('groovefolio://album/album-1'),
      );
      expect(association.albumId, 'album-1');
      expect(association.nfcTagId, '04A7392B916180');
      expect(fixture.repository.createdTags, hasLength(1));
      expect(fixture.platform.finishCalls, 1);
    },
  );

  test('writeTag surfaces a typed failure for a read-only tag', () async {
    final fixture = _Fixture(
      tag: const NfcPlatformTag(
        identifier: '04:A7:39:2B:91:61:80',
        ndefAvailable: true,
        ndefWritable: false,
      ),
    );

    await expectLater(
      fixture.service.writeTag('album-1'),
      throwsA(_nfcFailure(NfcFailure.notWritable)),
    );

    expect(fixture.platform.writtenUri, isNull);
    expect(fixture.repository.createdTags, isEmpty);
    expect(fixture.platform.finishCalls, 1);
  });

  test(
    'startScan emits the registered album ID instead of the tag ID',
    () async {
      final fixture = _Fixture();
      await fixture.repository.create(
        albumId: 'album-1',
        nfcTagId: '04A7392B916180',
      );

      final result = await fixture.service.startScan().single;

      expect(result, 'album-1');
      expect(result, isNot(contains('04A739')));
      expect(fixture.platform.finishCalls, 1);
    },
  );

  test('startScan surfaces an unregistered tag as a typed failure', () async {
    final fixture = _Fixture();

    await expectLater(
      fixture.service.startScan(),
      emitsError(_nfcFailure(NfcFailure.unregisteredTag)),
    );

    expect(fixture.platform.finishCalls, 1);
  });

  test('disabled NFC prevents polling and returns a typed failure', () async {
    final fixture = _Fixture(availability: NfcAvailabilityState.disabled);

    await expectLater(
      fixture.service.startScan(),
      emitsError(_nfcFailure(NfcFailure.disabled)),
    );

    expect(fixture.platform.pollCalls, 0);
    expect(fixture.platform.finishCalls, 0);
  });

  test('stopScan cancels an active poll and closes the session once', () async {
    final pollCompleter = Completer<NfcPlatformTag>();
    final fixture = _Fixture(pollCompleter: pollCompleter);

    final error = fixture.service.startScan().single.then<Object?>(
      (_) => null,
      onError: (Object error, StackTrace _) => error,
    );
    await Future<void>.delayed(Duration.zero);

    await fixture.service.stopScan();

    expect(await error, _nfcFailure(NfcFailure.cancelled));
    expect(fixture.platform.finishCalls, 1);
  });

  test('album NFC URIs round-trip and reject unrelated links', () {
    final uri = nfcAlbumUri('album/with space');

    expect(albumIdFromNfcUri(uri), 'album/with space');
    expect(
      albumIdFromNfcUri(Uri.parse('groovefolio://discogs-auth/callback')),
      isNull,
    );
    expect(albumIdFromNfcUri(Uri.parse('https://groovefolio.app')), isNull);
  });

  test('a written tag scans back to the same album', () async {
    final fixture = _Fixture();

    await fixture.service.writeTag('album-1');
    final albumId = await fixture.service.startScan().single;

    expect(albumId, 'album-1');
    expect(fixture.repository.createdTags, hasLength(1));
    expect(fixture.platform.finishCalls, 2);
  });
}

Matcher _nfcFailure(NfcFailure failure) {
  return isA<NfcException>().having(
    (exception) => exception.failure,
    'failure',
    failure,
  );
}

class _Fixture {
  _Fixture({
    NfcAvailabilityState availability = NfcAvailabilityState.available,
    NfcPlatformTag tag = const NfcPlatformTag(
      identifier: '04:A7:39:2B:91:61:80',
      ndefAvailable: true,
      ndefWritable: true,
    ),
    Completer<NfcPlatformTag>? pollCompleter,
  }) : platform = _FakeNfcPlatform(
         availabilityState: availability,
         tag: tag,
         pollCompleter: pollCompleter,
       ),
       repository = _FakeNfcTagRepository() {
    service = NfcService(platform: platform, repository: repository);
  }

  final _FakeNfcPlatform platform;
  final _FakeNfcTagRepository repository;
  late final NfcService service;
}

class _FakeNfcPlatform implements INfcPlatformAdapter {
  _FakeNfcPlatform({
    required this.availabilityState,
    required this.tag,
    this.pollCompleter,
  });

  final NfcAvailabilityState availabilityState;
  final NfcPlatformTag tag;
  final Completer<NfcPlatformTag>? pollCompleter;

  int pollCalls = 0;
  int finishCalls = 0;
  Uri? writtenUri;

  @override
  Future<NfcAvailabilityState> availability() async => availabilityState;

  @override
  Future<void> finish() async {
    finishCalls += 1;
    if (pollCompleter case final completer? when !completer.isCompleted) {
      completer.completeError(
        PlatformException(code: 'cancelled', message: 'cancelled'),
      );
    }
  }

  @override
  Future<NfcPlatformTag> poll({required Duration timeout}) {
    pollCalls += 1;
    return pollCompleter?.future ?? Future.value(tag);
  }

  @override
  Future<void> writeUri(Uri uri) async {
    writtenUri = uri;
  }
}

class _FakeNfcTagRepository implements INfcTagRepository {
  final List<NfcTag> createdTags = [];

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) async {
    final tag = NfcTag(
      id: 'nfc-${createdTags.length + 1}',
      albumId: albumId,
      nfcTagId: nfcTagId,
      writtenAt: (writtenAt ?? DateTime.utc(2026, 9, 2)).toIso8601String(),
    );
    createdTags.add(tag);
    return tag;
  }

  @override
  Future<int> delete(String id) async {
    final previousLength = createdTags.length;
    createdTags.removeWhere((tag) => tag.id == id);
    return previousLength - createdTags.length;
  }

  @override
  Future<NfcTag?> findByAlbum(String albumId) async {
    for (final tag in createdTags) {
      if (tag.albumId == albumId) return tag;
    }
    return null;
  }

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async {
    for (final tag in createdTags) {
      if (tag.nfcTagId == nfcTagId) return tag;
    }
    return null;
  }
}
