import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/nfc/nfc_play_undo.dart';

void main() {
  test(
    'Undo invokes its exact-play callback only once, even concurrently',
    () async {
      final pending = Completer<int>();
      final deleted = <String>[];
      final undo = NfcPlayUndo(
        deletePlay: () {
          deleted.add('play-new');
          return pending.future;
        },
      );
      final first = undo.undo();
      expect(await undo.undo(), isFalse);
      pending.complete(1);
      expect(await first, isTrue);
      expect(await undo.undo(), isFalse);
      expect(deleted, ['play-new']);
    },
  );

  test('Undo expires using monotonic elapsed time', () async {
    var elapsed = Duration.zero;
    var deletes = 0;
    final undo = NfcPlayUndo(
      elapsed: () => elapsed,
      deletePlay: () async => ++deletes,
    );
    elapsed = const Duration(seconds: 10);
    expect(await undo.undo(), isFalse);
    expect(deletes, 0);
  });

  test('already removed play cannot cause a different deletion', () async {
    var deletes = 0;
    final undo = NfcPlayUndo(
      deletePlay: () async {
        deletes++;
        return 0;
      },
    );
    expect(await undo.undo(), isFalse);
    expect(await undo.undo(), isFalse);
    expect(deletes, 1);
  });

  test(
    'failed database delete is reported and may retry within window',
    () async {
      var calls = 0;
      final undo = NfcPlayUndo(
        deletePlay: () async {
          if (++calls == 1) throw StateError('database unavailable');
          return 1;
        },
      );
      await expectLater(undo.undo(), throwsStateError);
      expect(await undo.undo(), isTrue);
    },
  );
}
