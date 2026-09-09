import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Notification navigation is deliberately distinct from a tag's log URI.
/// Reuse the strict parser, but never pass this URI to the play handler.
String? albumIdFromNotificationUri(Uri uri) {
  if (uri.scheme != 'groovefolio-notification') return null;
  return albumIdFromNfcUri(uri.replace(scheme: 'groovefolio'));
}

typedef NotificationMethodInvoker =
    Future<bool?> Function(String method, Map<String, Object?> arguments);

/// Displays an Android system notification after an automatic NFC play.
///
/// Manual play logging deliberately does not call this service; it stays in
/// the Flutter UI and uses an in-app confirmation instead.
abstract interface class INfcPlayNotificationService {
  Future<bool> showLoggedPlay({required Album album, required Play play});
}

class AndroidNfcPlayNotificationService implements INfcPlayNotificationService {
  AndroidNfcPlayNotificationService({
    NotificationMethodInvoker? invoke,
    bool? isAndroid,
  }) : _invoke = invoke ?? _invokePlatformMethod,
       _isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const _channel = MethodChannel(
    'com.huntergoller.vinyl_app/nfc_notifications',
  );

  final NotificationMethodInvoker _invoke;
  final bool _isAndroid;

  static Future<bool?> _invokePlatformMethod(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _channel.invokeMethod<bool>(method, arguments);
  }

  @override
  Future<bool> showLoggedPlay({
    required Album album,
    required Play play,
  }) async {
    if (!_isAndroid) return false;

    final artworkPath = album.artworkPath?.trim();
    try {
      return await _invoke('showNfcPlayLogged', {
            'playId': play.id,
            'albumId': album.id,
            'albumTitle': album.title.trim(),
            'sideLabel': _sideLabel(play.sidePlayed),
            if (artworkPath != null && artworkPath.isNotEmpty)
              'artworkPath': artworkPath,
          }) ??
          false;
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Groovefolio] NFC notification failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }
  }
}

/// Removes a success notification after its exact play has been undone.
Future<void> cancelNfcPlayNotification(String playId) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'com.huntergoller.vinyl_app/nfc_notifications',
    ).invokeMethod<bool>('cancelNfcPlayLogged', {'playId': playId});
  } on Object {
    // Notification cleanup must not turn a successful database Undo into an error.
  }
}

String _sideLabel(SidePlayed side) => switch (side) {
  SidePlayed.full => 'Full album',
  SidePlayed.sideA => 'Side A',
  SidePlayed.sideB => 'Side B',
};

final nfcPlayNotificationServiceProvider =
    Provider<INfcPlayNotificationService>((ref) {
      return AndroidNfcPlayNotificationService();
    });
