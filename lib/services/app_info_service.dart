import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBuildInfo {
  const AppBuildInfo(this.version, this.build);
  final String version;
  final String build;
  String get label => 'Version $version (build $build)';
}

final appBuildInfoProvider = FutureProvider<AppBuildInfo?>((ref) async {
  try {
    final result = await const MethodChannel(
      'com.huntergoller.vinyl_app/app_info',
    ).invokeMapMethod<String, Object?>('getVersion');
    if (result case {
      'version': final String version,
      'build': final String build,
    } when version.isNotEmpty && build.isNotEmpty) {
      return AppBuildInfo(version, build);
    }
  } on Object {
    // Unsupported platforms/old native builds must not break Settings.
  }
  return null;
});
