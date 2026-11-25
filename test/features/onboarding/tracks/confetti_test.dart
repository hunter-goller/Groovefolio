import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';

void main() {
  Widget host({bool reduceMotion = false, VoidCallback? onTap}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Stack(
        children: [
          const Positioned.fill(child: Confetti()),
          Center(
            child: TextButton(onPressed: onTap, child: const Text('Next')),
          ),
          const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    ),
  );

  testWidgets('the burst plays once and then stops', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(ConfettiBurst.duration);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows the still confetti only', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps reach the content during the burst', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Next'));
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
}
