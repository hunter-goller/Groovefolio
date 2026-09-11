import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';
import 'package:vinyl_app/widgets/shared/side_selector.dart';

void main() {
  testWidgets('SideSelector reports the selected side', (tester) async {
    SidePlayed selected = SidePlayed.full;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SideSelector(
            value: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Side A'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(selected, SidePlayed.sideA);
  });

  testWidgets('supports large text and exposes selected state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SideSelector(value: SidePlayed.full, onChanged: (_) {}),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text('Full album'));
    expect(semantics.label, 'Full album');
    expect(semantics.hint, 'Selected');
    expect(tester.takeException(), isNull);
  });
}
