import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles Google's User Messaging Platform (UMP) consent flow (GDPR).
///
/// IMPORTANT: For a consent form to actually appear, a GDPR message must be
/// created and published in the AdMob console (Privacy & messaging > GDPR).
/// Without a configured message, [ConsentInformation] will report that no form
/// is available and ads will simply proceed.
///
/// This is intentionally robust: on ANY error we still allow ads to be
/// requested so that ads are never permanently blocked by a consent failure.
class ConsentService {
  /// Gathers consent (requesting an update, then loading/showing the form if
  /// required) and returns once it is safe to request ads.
  ///
  /// Returns `true` if ads can be requested (either consent was obtained, was
  /// not required, or an error occurred and we fall back to allowing ads).
  static Future<bool> gatherConsent() async {
    try {
      final params = ConsentRequestParameters();

      // requestConsentInfoUpdate uses success/error callbacks; wrap in a
      // Completer-free Future via a simple helper so callers can await it.
      await _requestConsentInfoUpdate(params);

      // Load & show the form only if the current consent status requires it.
      // This is a no-op if consent isn't required or no form is configured.
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null && kDebugMode) {
          debugPrint('UMP consent form error: ${error.message}');
        }
      });

      final canRequest = await ConsentInformation.instance.canRequestAds();
      return canRequest;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UMP consent gather failed, allowing ads anyway: $e');
      }
      // Fail open: never let a consent error permanently block ads.
      return true;
    }
  }

  static Future<void> _requestConsentInfoUpdate(
      ConsentRequestParameters params) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () => completer.complete(),
      (FormError error) {
        if (kDebugMode) {
          debugPrint('UMP requestConsentInfoUpdate error: ${error.message}');
        }
        // Complete normally; the caller falls back to allowing ads.
        completer.complete();
      },
    );
    return completer.future;
  }
}
