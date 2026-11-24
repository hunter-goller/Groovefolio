import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';

enum DiscogsCheckIn {
  /// Not connected, or checked in recently.
  skipped,
  ok,

  /// The server no longer knows this app; the saved connection was cleared.
  lost,

  /// Offline or the server failed; tried again next time the app opens.
  failed,
}

/// Keeps an existing Discogs connection alive while the app is in use.
///
/// The server ends a connection after a period with no requests (X-02). Most
/// people import once and rarely use Discogs again, so opening the app checks
/// in at most once per [interval], and only when a connection already exists.
/// The request is the ordinary authenticated path, so it also renews the
/// app's token when that is close to expiring. No collection data is sent.
class DiscogsKeepAlive {
  DiscogsKeepAlive(
    this._session, {
    DateTime Function()? now,
    this.interval = const Duration(hours: 20),
  }) : _now = now ?? DateTime.now;

  final InstallationSession _session;
  final DateTime Function() _now;
  final Duration interval;
  DateTime? _lastCheckIn;
  Future<DiscogsCheckIn>? _running;

  Future<DiscogsCheckIn> checkIn() =>
      _running ??= _checkIn().whenComplete(() => _running = null);

  Future<DiscogsCheckIn> _checkIn() async {
    final last = _lastCheckIn;
    if (last != null && _now().difference(last) < interval) {
      return DiscogsCheckIn.skipped;
    }
    try {
      if (!await _session.hasSession()) return DiscogsCheckIn.skipped;
      await _session.request(
        'GET',
        '/v1/installation',
        timeout: DiscogsApiClient.connectionTimeout,
      );
      _lastCheckIn = _now();
      return DiscogsCheckIn.ok;
    } on DiscogsAuthenticationFailure {
      _lastCheckIn = _now();
      return DiscogsCheckIn.lost;
    } on Object {
      // Offline, server trouble or unreadable storage: try again next time.
      return DiscogsCheckIn.failed;
    }
  }
}

final discogsKeepAliveProvider = Provider<DiscogsKeepAlive>(
  (ref) => DiscogsKeepAlive(ref.watch(installationSessionProvider)),
);

/// True after a check-in found the Discogs connection had already ended, so
/// Settings can say why it shows "Connect Discogs" again.
final discogsConnectionLostProvider =
    NotifierProvider<DiscogsConnectionLost, bool>(DiscogsConnectionLost.new);

class DiscogsConnectionLost extends Notifier<bool> {
  @override
  bool build() => false;

  void report() => state = true;
}

/// Checks in when the app opens and each time it comes back to the
/// foreground. [DiscogsKeepAlive] limits this to once a day.
class DiscogsKeepAliveScope extends ConsumerStatefulWidget {
  const DiscogsKeepAliveScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DiscogsKeepAliveScope> createState() =>
      _DiscogsKeepAliveScopeState();
}

class _DiscogsKeepAliveScopeState extends ConsumerState<DiscogsKeepAliveScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIn());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkIn();
  }

  void _checkIn() {
    if (!mounted) return;
    final keepAlive = ref.read(discogsKeepAliveProvider);
    unawaited(
      keepAlive.checkIn().then((result) {
        if (result != DiscogsCheckIn.lost || !mounted) return;
        ref.read(discogsConnectionLostProvider.notifier).report();
        ref.invalidate(discogsAccountProvider);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
