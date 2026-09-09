/// A short-lived, in-memory capability for undoing one newly created NFC play.
/// Never accepts a play ID from a tag, URI, or notification intent.
class NfcPlayUndo {
  NfcPlayUndo({
    required this._deletePlay,
    Duration Function()? elapsed,
    this.window = const Duration(seconds: 10),
  }) {
    final clock = Stopwatch()..start();
    _elapsed = elapsed ?? (() => clock.elapsed);
    _started = _elapsed();
  }

  final Future<int> Function() _deletePlay;
  final Duration window;
  late final Duration Function() _elapsed;
  late final Duration _started;
  bool _used = false;

  Future<bool> undo() async {
    if (_used || _elapsed() - _started >= window) return false;
    // Consume before awaiting so concurrent taps cannot issue two deletes.
    _used = true;
    try {
      return await _deletePlay() > 0;
    } on Object {
      _used = false;
      rethrow;
    }
  }
}
