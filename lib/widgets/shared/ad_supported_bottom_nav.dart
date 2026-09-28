import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vinyl_app/services/ads/ad_consent_service.dart';
import 'package:vinyl_app/services/ads/ad_preview_config.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

/// A small banner above navigation on the three browsing screens only.
class AdSupportedBottomNav extends ConsumerWidget {
  const AdSupportedBottomNav({required this.navigationBar, super.key});

  final Widget navigationBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = shouldShowAd(
      previewEnabled: canPreviewAds,
      walkthroughActive: ref.watch(walkthroughProvider).active,
      onboardingRoute:
          GoRouterState.of(context).uri.queryParameters['onboarding'] == 'true',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [if (visible) const _TestBanner(), navigationBar],
    );
  }
}

class _TestBanner extends StatefulWidget {
  const _TestBanner();

  @override
  State<_TestBanner> createState() => _TestBannerState();
}

class _TestBannerState extends State<_TestBanner> {
  BannerAd? _banner;
  AdSize? _size;
  int? _width;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    adConsentService.addListener(_onConsentChanged);
    adConsentService.start();
  }

  void _onConsentChanged() {
    if (!adConsentService.value.ready) {
      _banner?.dispose();
      setState(() {
        _banner = null;
        _size = null;
        _loading = false;
        _failed = false;
      });
    } else {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    if (_loading ||
        _failed ||
        _banner != null ||
        !adConsentService.value.ready) {
      return;
    }
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) return;
    _loading = true;
    AdSize? size;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    } on Object {
      if (mounted) _failed = true;
      _loading = false;
      return;
    }
    if (!mounted || !adConsentService.value.ready || size == null) {
      if (size == null) _failed = true;
      _loading = false;
      return;
    }
    final banner = BannerAd(
      adUnitId: androidTestBannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !adConsentService.value.ready) {
            ad.dispose();
            return;
          }
          setState(() {
            _size = size;
            _banner = ad as BannerAd;
            _width = width;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _loading = false;
              _failed = true;
            });
          }
        },
      ),
    );
    try {
      await banner.load();
    } on Object {
      await banner.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (_width != null && width != _width) {
      // A rotation changes the adaptive banner's width; load a fresh one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _banner?.dispose();
        setState(() {
          _banner = null;
          _size = null;
          _width = null;
          _failed = false;
        });
        _loadBanner();
      });
    } else if (adConsentService.value.ready && _banner == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadBanner();
      });
    }
    final banner = _banner;
    final size = _size;
    if (banner == null || size == null) return const SizedBox.shrink();
    return SizedBox(
      key: const Key('ad-preview-banner'),
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }

  @override
  void dispose() {
    adConsentService.removeListener(_onConsentChanged);
    _banner?.dispose();
    super.dispose();
  }
}
