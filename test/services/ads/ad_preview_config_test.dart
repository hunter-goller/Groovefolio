import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/ads/ad_preview_config.dart';

void main() {
  test(
    'test ads require explicit opt-in and are hidden during walkthroughs',
    () {
      expect(
        shouldShowAd(
          previewEnabled: false,
          walkthroughActive: false,
          onboardingRoute: false,
        ),
        isFalse,
      );
      expect(
        shouldShowAd(
          previewEnabled: true,
          walkthroughActive: true,
          onboardingRoute: false,
        ),
        isFalse,
      );
      expect(
        shouldShowAd(
          previewEnabled: true,
          walkthroughActive: false,
          onboardingRoute: true,
        ),
        isFalse,
      );
      expect(
        shouldShowAd(
          previewEnabled: true,
          walkthroughActive: false,
          onboardingRoute: false,
        ),
        isTrue,
      );
    },
  );
}
