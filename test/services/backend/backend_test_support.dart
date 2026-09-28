import 'dart:convert';
import 'dart:typed_data';
import 'package:vinyl_app/services/backend/backend_store.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';

const installationId = '00000000-0000-4000-8000-000000000001';
const flowId = '00000000-0000-4000-8000-000000000002';
final oldToken = base64Url.encode(List.filled(32, 1)).replaceAll('=', '');
final nextToken = base64Url.encode(List.filled(32, 2)).replaceAll('=', '');
final fixedNow = DateTime.utc(2026, 9, 27);

BackendResponse response(
  int status, [
  Object? body,
  Map<String, String> headers = const {},
]) => BackendResponse(
  status,
  Uint8List.fromList(utf8.encode(body == null ? '' : jsonEncode(body))),
  headers,
);
Map<String, Object> identity([int days = 30]) => {
  'installationId': installationId,
  'expiresAt': fixedNow.add(Duration(days: days)).toIso8601String(),
};

class MemoryBackendStore implements BackendStore {
  final values = <String, String>{};
  bool failWrites = false;
  int legacyClears = 0;
  void seed({int days = 30, String? pending}) {
    values['session'] = jsonEncode({
      ...identity(days),
      'token': oldToken,
      'pendingToken': pending,
    });
  }

  void seedFlow() {
    values['flow'] = jsonEncode({
      'transactionId': flowId,
      'installationId': installationId,
      'expiresAt': fixedNow.add(const Duration(minutes: 10)).toIso8601String(),
    });
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('Secure storage unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clearLegacyDiscogs() async {
    legacyClears++;
  }
}
