import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class InitializationHelper {
  static final Completer<void> _adsReady = Completer<void>();

  /// Completes once the AdMob SDK has finished initializing (after the consent
  /// flow). Ad widgets await this before calling `NativeAd.load()`, so a cold
  /// start can't fire an ad request before `MobileAds.instance.initialize()`
  /// has run — which silently drops the request and leaves the ad slot blank
  /// until the app is relaunched (the bug where the ad only appeared right
  /// after login, when the auth flow gave init enough time to finish first).
  static Future<void> get adsReady => _adsReady.future;

  /// Whether the ads SDK is already initialized, so an ad can load right away
  /// without deferring on [adsReady] (true on every navigation after the first).
  static bool get isAdsReady => _adsReady.isCompleted;

  /// Test seam: mark the ads SDK ready so widget tests can exercise the ad
  /// load path without booting the real consent/init flow.
  @visibleForTesting
  static void debugMarkAdsReady() {
    if (!_adsReady.isCompleted) _adsReady.complete();
  }

  Future<FormError?> initialize() async {
    final completer = Completer<FormError?>();

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await _loadConsentForm();
      } else {
        // There is no message to display,
        // so initialize the components here.
        await _initialize();
      }

      completer.complete();
    }, (error) {
      completer.complete(error);
    });

    return completer.future;
  }

  Future<FormError?> _loadConsentForm() async {
    final completer = Completer<FormError?>();

    ConsentForm.loadConsentForm((consentForm) async {
      final status = await ConsentInformation.instance.getConsentStatus();
      if (status == ConsentStatus.required) {
        consentForm.show((formError) {
          completer.complete(_loadConsentForm());
        });
      } else {
        // The user has chosen an option,
        // it's time to initialize the ads component.
        await _initialize();
        completer.complete();
      }
    }, (FormError? error) {
      completer.complete(error);
    });

    return completer.future;
  }

  Future<void> _initialize() async {
    await MobileAds.instance.initialize();
    if (!_adsReady.isCompleted) _adsReady.complete();
  }

  Future<bool> changePrivacyPreferences() async {
    final completer = Completer<bool>();

    ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadConsentForm((consentForm) {
          consentForm.show((formError) async {
            await _initialize();
            completer.complete(true);
          });
        }, (formError) {
          completer.complete(false);
        });
      } else {
        completer.complete(false);
      }
    }, (error) {
      completer.complete(false);
    });

    return completer.future;
  }
}
