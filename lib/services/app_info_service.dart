import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Version/build reported by the installed native package for Settings.
/// This may differ from an edited pubspec until a new native build is installed.
class AppBuildInfo {
  const AppBuildInfo(this.version, this.build);
  final String version;
  final String build;
  String get label => 'Version $version (build $build)';
}

/// Reads the Android app-info channel; null means unsupported or unavailable.
/// Settings can omit the version row without failing the rest of the screen.
final appBuildInfoProvider = FutureProvider<AppBuildInfo?>((ref) async {
  try {
    final result = await const MethodChannel(
      'app.groovefolio/app_info',
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
