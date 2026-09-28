import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vinyl_app/services/ads/ad_preview_config.dart';

@immutable
class AdConsentState {
  const AdConsentState({
    this.ready = false,
    this.privacyOptionsRequired = false,
  });

  final bool ready;
  final bool privacyOptionsRequired;
}

/// One UMP update per launch, before the first ad request. An unavailable
/// consent service fails closed and never blocks the rest of the application.
class AdConsentService extends ValueNotifier<AdConsentState> {
  AdConsentService() : super(const AdConsentState());

  Future<void>? _startup;

  Future<void> start() {
    if (!canPreviewAds) return Future<void>.value();
    return _startup ??= _requestConsent();
  }

  Future<void> _requestConsent() async {
    final updated = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => updated.complete(true),
        (error) => updated.complete(false),
      );
      if (!await updated.future) return;

      final form = Completer<bool>();
      ConsentForm.loadAndShowConsentFormIfRequired(
        (error) => form.complete(error == null),
      );
      if (!await form.future) return;

      await _updateEligibility();
    } on Object catch (error) {
      debugPrint('Ad consent unavailable: $error');
    }
  }

  Future<void> _updateEligibility() async {
    final options = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    final allowed = await ConsentInformation.instance.canRequestAds();
    if (allowed) {
      await MobileAds.instance.initialize();
    }
    value = AdConsentState(
      ready: allowed,
      privacyOptionsRequired:
          options == PrivacyOptionsRequirementStatus.required,
    );
  }

  Future<bool> showPrivacyOptions() async {
    if (!value.privacyOptionsRequired) return false;
    final shown = Completer<bool>();
    try {
      ConsentForm.showPrivacyOptionsForm(
        (error) => shown.complete(error == null),
      );
      if (!await shown.future) return false;
      await _updateEligibility();
      return true;
    } on Object catch (error) {
      debugPrint('Privacy options unavailable: $error');
      value = const AdConsentState();
      return false;
    }
  }
}

final adConsentService = AdConsentService();
