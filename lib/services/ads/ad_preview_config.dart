import 'dart:io';

/// Explicitly opt in to Google's sample ads in an internal build. Never load
/// ads in normal builds, including release builds handed to testers.
const bool adPreviewRequested = bool.fromEnvironment('GROOVEFOLIO_ADS_PREVIEW');

const String androidTestBannerUnitId = 'ca-app-pub-3940256099942544/9214589741';

bool get canPreviewAds => adPreviewRequested && Platform.isAndroid;

bool shouldShowAd({
  required bool previewEnabled,
  required bool walkthroughActive,
  required bool onboardingRoute,
}) => previewEnabled && !walkthroughActive && !onboardingRoute;
