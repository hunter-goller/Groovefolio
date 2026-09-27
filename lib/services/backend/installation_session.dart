import 'dart:convert';
import 'dart:math';

import 'package:vinyl_app/services/backend/backend_store.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

class InstallationSession {
  InstallationSession({
    required this.origin,
    required this.store,
    required this.transport,
    DateTime Function()? now,
    String Function()? newToken,
  }) : _now = now ?? DateTime.now,
       _newToken = newToken ?? _randomToken;
  final Uri origin;
  final BackendStore store;
  final BackendTransport transport;
  final DateTime Function() _now;
  final String Function() _newToken;
  Future<void> _tail = Future.value();

  // All authenticated requests share this queue, including rotation/recovery.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Uri uri(String path, [Map<String, String>? query]) =>
      origin.replace(path: path, queryParameters: query);

  Future<_Session?> _read() async {
    final raw = await store.read('session');
    if (raw == null) {
      return null;
    }
    try {
      return _Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const DiscogsApiFailure('Saved connection data could not be read.');
    }
  }

  Future<void> _save(_Session value) =>
      store.write('session', jsonEncode(value.toJson()));
  Future<bool> hasSession() => _serial(() async => await _read() != null);
  Future<String?> installationId() => _serial(() async => (await _read())?.id);

  /// Registration happens only when the user explicitly connects Discogs.
  Future<void> registerIfNeeded() => _serial(() async {
    if (await _read() != null) {
      await store.clearLegacyDiscogs();
      return;
    }
    try {
      final response = await transport.send(
        'POST',
        uri('/v1/installations'),
        body: '{}',
      );
      final json = response.json();
      final value = _Session.fromJson({...json, 'pendingToken': null});
      await _save(value);
      await store.clearLegacyDiscogs();
    } on BackendError catch (error) {
      throw backendFailure(error);
    }
  });

  Future<BackendResponse> request(
    String method,
    String path, {
    Map<String, String>? query,
    String? body,
  }) => _serial(() async {
    var session = await _read();
    if (session == null) {
      throw const DiscogsAuthenticationFailure(
        'Connect Discogs in Settings to continue.',
      );
    }
    try {
      if (session.pending != null) {
        session = await _recover(session);
      }
      if (!session.expiresAt.isAfter(_now().add(const Duration(days: 3)))) {
        session = _Session(
          session.id,
          session.token,
          session.expiresAt,
          _newToken(),
        );
        await _save(session); // Persist successor BEFORE sending the rotation.
        session = await _rotate(session);
      }
      return await transport.send(
        method,
        uri(path, query),
        token: session.token,
        body: body,
      );
    } on BackendError catch (error) {
      if (error.invalidToken) {
        await store.delete('flow');
        await store.delete('session');
      }
      throw backendFailure(error);
    }
  });

  Future<_Session> _recover(_Session session) async {
    try {
      final response = await transport.send(
        'GET',
        uri('/v1/installation'),
        token: session.pending,
      );
      return _promote(session, response, session.pending!);
    } on BackendError catch (error) {
      if (!error.invalidToken) {
        rethrow;
      }
    }
    // Only a definite rejection permits retrying the old token. Preserve both
    // on timeouts/5xx/storage failures, and never issue a new installation here.
    final status = await transport.send(
      'GET',
      uri('/v1/installation'),
      token: session.token,
    );
    if (status.json()['installationId'] != session.id) {
      throw const DiscogsApiFailure(
        'The server returned an invalid connection.',
      );
    }
    return _rotate(session);
  }

  Future<_Session> _rotate(_Session session) async {
    try {
      final response = await transport.send(
        'POST',
        uri('/v1/installation/rotate'),
        token: session.token,
        body: jsonEncode({'nextToken': session.pending}),
      );
      return _promote(session, response, session.pending!);
    } on BackendError catch (error) {
      if (error.status == 409 && error.code == 'token_conflict') {
        await _save(
          _Session(session.id, session.token, session.expiresAt, null),
        );
      }
      rethrow;
    }
  }

  Future<_Session> _promote(
    _Session old,
    BackendResponse response,
    String token,
  ) async {
    final next = _Session.fromJson({...response.json(), 'token': token});
    if (next.id != old.id) {
      throw const DiscogsApiFailure(
        'The server returned an invalid connection.',
      );
    }
    await _save(next);
    return next;
  }

  static String _randomToken() {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}

class _Session {
  const _Session(this.id, this.token, this.expiresAt, this.pending);
  final String id;
  final String token;
  final DateTime expiresAt;
  final String? pending;
  factory _Session.fromJson(Map<String, dynamic> json) {
    try {
      final token = json['token'] as String;
      final pending = json['pendingToken'] as String?;
      final id = json['installationId'] as String;
      final pattern = RegExp(r'^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$');
      if (!pattern.hasMatch(token) ||
          (pending != null && !pattern.hasMatch(pending)) ||
          !RegExp(
            r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
          ).hasMatch(id)) {
        throw const FormatException('Invalid installation');
      }
      return _Session(
        id,
        token,
        DateTime.parse(json['expiresAt'] as String).toUtc(),
        pending,
      );
    } on FormatException {
      throw const DiscogsApiFailure(
        'The server returned invalid connection data.',
      );
    } on TypeError {
      throw const DiscogsApiFailure(
        'The server returned invalid connection data.',
      );
    }
  }
  Map<String, dynamic> toJson() => {
    'installationId': id,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'pendingToken': pending,
  };
}
