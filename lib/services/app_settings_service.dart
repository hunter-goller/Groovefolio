import 'package:flutter/services.dart';

/// Opens this installation's Android settings without adding a permissions SDK.
class AppSettingsService {
  static const _channel = MethodChannel('app.groovefolio/app_settings');

  static Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
