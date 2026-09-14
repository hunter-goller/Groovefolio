import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/onboarding/widgets/guide_target.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

class _ActiveGuide extends WalkthroughController {
  @override
  WalkthroughState build() =>
      const WalkthroughState(active: true, step: 1, replay: true);
}

Widget _host(Widget child, {bool reducedMotion = false}) => ProviderScope(
  overrides: [walkthroughProvider.overrideWith(_ActiveGuide.new)],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  testWidgets('tap cue settles and leaves the real button usable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GuideTarget(
          steps: const [1],
          child: FilledButton(
            onPressed: () => taps++,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('guide-cue-symbol')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-cue-symbol')), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch dismisses the cue without swallowing the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GuideTarget(
          steps: const [1],
          child: SizedBox(
            width: 200,
            height: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const Text('Tap here'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('guide-cue-symbol'))),
    );
    await tester.pump();
    expect(taps, 1);
    expect(find.byKey(const Key('guide-cue-symbol')), findsNothing);
  });

  testWidgets('swipe cue moves left and passes through real drags', (
    tester,
  ) async {
    var distance = 0.0;
    await tester.pumpWidget(
      _host(
        GuideTarget(
          steps: const [1],
          cue: GuideCue.swipe,
          child: SizedBox(
            width: 300,
            height: 80,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (event) => distance += event.delta.dx,
              child: const Text('A record'),
            ),
          ),
        ),
      ),
    );
    final symbol = find.byKey(const Key('guide-cue-symbol'));
    await tester.pump(const Duration(milliseconds: 400));
    final start = tester.getCenter(symbol).dx;
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(symbol).dx, lessThan(start));
    await tester.drag(find.text('A record'), const Offset(-100, 0));
    await tester.pump();
    expect(distance, lessThan(0));
    expect(symbol, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion uses a stationary cue without a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const GuideTarget(
          steps: [1],
          cue: GuideCue.swipe,
          child: SizedBox(width: 300, height: 80),
        ),
        reducedMotion: true,
      ),
    );
    final symbol = find.byKey(const Key('guide-cue-symbol'));
    final start = tester.getCenter(symbol);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getCenter(symbol), start);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive targets do not show cues or change tight width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 280,
          child: GuideTarget(
            steps: [2],
            child: SizedBox(key: Key('real-control'), height: 48),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('guide-cue-symbol')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('real-control'))).width, 280);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
