import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/app_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.huntergoller.vinyl_app/app_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('reads installed package version and build', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getVersion');
      return {'version': '3.2.1', 'build': '42'};
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      (await container.read(appBuildInfoProvider.future))?.label,
      'Version 3.2.1 (build 42)',
    );
  });
  test('missing native implementation has no invented version', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(appBuildInfoProvider.future), isNull);
  });
}
