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
  if (uri.toString().length > 512 || uri.pathSegments.length != 2) return null;
  // The second segment distinguishes notifications for successive plays of
  // the same album. It is never used to look up or delete a play.
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(uri.pathSegments[1])) {
    return null;
  }
  return albumIdFromNfcUri(
    uri.replace(scheme: 'groovefolio', pathSegments: [uri.pathSegments.first]),
  );
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

/// Requests notification permission while the user is already in Groovefolio
/// after successfully linking a tag. External tag delivery never prompts.
Future<bool> requestNfcPlayNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await const MethodChannel(
          'com.huntergoller.vinyl_app/nfc_notifications',
        ).invokeMethod<bool>('requestNfcNotificationPermission') ??
        false;
  } on Object {
    return false;
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
