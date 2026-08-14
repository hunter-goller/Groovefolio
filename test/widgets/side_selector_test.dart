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
}
