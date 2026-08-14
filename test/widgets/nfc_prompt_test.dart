import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/widgets/shared/nfc_prompt.dart';

void main() {
  testWidgets('NFC prompt can cancel and restart scanning', (tester) async {
    var scanning = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: NFCPrompt(
                isScanning: scanning,
                onCancel: () => setState(() => scanning = false),
                onStart: () => setState(() => scanning = true),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Scanning for NFC…'), findsOneWidget);
    expect(find.byKey(const Key('nfc-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nfc-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Scan an NFC tag'), findsOneWidget);
    expect(find.byKey(const Key('nfc-start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nfc-start')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Scanning for NFC…'), findsOneWidget);
    expect(find.byKey(const Key('nfc-cancel')), findsOneWidget);
  });
}
