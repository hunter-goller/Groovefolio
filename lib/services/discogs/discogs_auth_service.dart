import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/services/backend/backend_store.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

typedef DiscogsBrowserLauncher = Future<bool> Function(Uri uri);

class DiscogsAuthService {
  DiscogsAuthService({
    required DiscogsApiClient apiClient,
    required BackendStore store,
    DiscogsBrowserLauncher? launcher,
  }) : _api = apiClient,
       _store = store,
       _launch =
           launcher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final DiscogsApiClient _api;
  final BackendStore _store;
  final DiscogsBrowserLauncher _launch;
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<DiscogsAccount?> currentAccount() => _api.account();

  Future<Map<String, dynamic>?> _flow() async {
    final raw = await _store.read('flow');
    if (raw == null) {
      return null;
    }
    try {
      final flow = jsonDecode(raw) as Map<String, dynamic>;
      if (flow['installationId'] != await _api.session.installationId()) {
        await _store.delete('flow');
        return null;
      }
      if (!RegExp(
        r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
      ).hasMatch(flow['transactionId'] as String)) {
        throw const FormatException('Invalid flow');
      }
      return flow;
    } on TypeError {
      throw const DiscogsApiFailure('Saved authorization could not be read.');
    } on FormatException {
      throw const DiscogsApiFailure('Saved authorization could not be read.');
    }
  }

  Future<Uri> beginAuthorization() => _serial(() async {
    await _api.session.registerIfNeeded();
    final previous = await _flow();
    if (previous != null) {
      await _cancel(previous);
    }
    final flow = await _api.call('POST', '/v1/discogs/connections');
    final url = Uri.tryParse(
      flow['authorizationUrl'] is String
          ? flow['authorizationUrl'] as String
          : '',
    );
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'www.discogs.com' ||
        url.port != 443 ||
        url.userInfo.isNotEmpty ||
        url.path != '/oauth/authorize' ||
        url.hasFragment) {
      throw const DiscogsApiFailure(
        'The server returned an invalid authorization link.',
      );
    }
    final id = flow['transactionId'] is String
        ? flow['transactionId'] as String
        : '';
    if (!RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$').hasMatch(id)) {
      throw const DiscogsApiFailure(
        'The server returned an invalid authorization session.',
      );
    }
    await _store.write(
      'flow',
      jsonEncode({
        'transactionId': id,
        'installationId': await _api.session.installationId(),
        'expiresAt': flow['expiresAt'],
      }),
    );
    return url;
  });

  Future<void> launchAuthorization() async {
    final uri = await beginAuthorization();
    if (!await _launch(uri)) {
      throw const DiscogsNetworkFailure(
        'Could not open Discogs authorization. Try again.',
      );
    }
  }

  /// Browser return/deep links never carry credentials into the app. Query the
  /// stored, installation-owned server transaction, including after a restart.
  Future<String> authorizationStatus() => _serial(() async {
    final flow = await _flow();
    if (flow == null) {
      return 'none';
    }
    Map<String, dynamic> progress;
    try {
      progress = await _api.call(
        'GET',
        '/v1/discogs/connections/${flow['transactionId']}',
      );
    } on DiscogsApiFailure catch (error) {
      if (error.statusCode == 404) {
        await _store.delete('flow');
      }
      rethrow;
    }
    final status = progress['status'];
    if (status == 'pending') {
      return 'pending';
    }
    if (status == 'connected') {
      if (await currentAccount() == null) {
        throw const DiscogsAuthenticationFailure(
          'Connect Discogs again in Settings.',
        );
      }
      await _store.delete('flow');
      return 'connected';
    }
    if (const {'canceled', 'expired', 'failed'}.contains(status)) {
      await _store.delete('flow');
      throw const DiscogsAuthenticationFailure(
        'Authorization ended without connecting. Please try again.',
      );
    }
    throw const DiscogsApiFailure(
      'The server returned an invalid authorization status.',
    );
  });

  Future<void> _cancel(Map<String, dynamic> flow) async {
    try {
      await _api.call(
        'DELETE',
        '/v1/discogs/connections/${flow['transactionId']}',
      );
    } on DiscogsApiFailure catch (error) {
      if (error.statusCode != 404 && error.statusCode != 409) {
        rethrow;
      }
    }
    await _store.delete('flow');
  }

  Future<void> cancelAuthorization() => _serial(() async {
    final flow = await _flow();
    if (flow != null) {
      await _cancel(flow);
    }
  });
  Future<void> disconnect() => _serial(() async {
    if (await _api.session.hasSession()) {
      await _api.call('DELETE', '/v1/discogs/account');
    }
    await _store.delete('flow');
    await _store.clearLegacyDiscogs();
  });
}
