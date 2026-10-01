import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vinyl_app/features/albums/screens/barcode_scanner_screen.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  const settingsChannel = MethodChannel('app.groovefolio/app_settings');
  late MobileScannerPlatform previousPlatform;
  late _FakeScanner scanner;

  setUp(() {
    previousPlatform = MobileScannerPlatform.instance;
    scanner = _FakeScanner();
    MobileScannerPlatform.instance = scanner;
  });

  tearDown(() {
    MobileScannerPlatform.instance = previousPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, null);
  });

  Future<void> showScanner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const BarcodeScannerScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open settings').hitTestable(), findsOneWidget);
    expect(scanner.starts, 1);
  }

  testWidgets('permission recovery opens settings and resumes the camera', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      settingsChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    await showScanner(tester);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'openAppSettings');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    scanner.permissionGranted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(scanner.starts, 2);
    expect(find.text('Open settings'), findsNothing);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Try again retries camera permission', (tester) async {
    await showScanner(tester);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(scanner.starts, 2);
    expect(find.text('Open settings').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings failure explains how to grant permission manually', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      settingsChannel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    await showScanner(tester);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Apps > Groovefolio > Permissions > Camera'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeScanner extends MobileScannerPlatform {
  int starts = 0;
  bool permissionGranted = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    if (!permissionGranted) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
    );
  }

  @override
  Widget buildCameraView() => const SizedBox(key: Key('fake-camera-preview'));

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
