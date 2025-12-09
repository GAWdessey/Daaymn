import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initDeepLinks(BuildContext context) async {
  final appLinks = AppLinks();

  appLinks.uriLinkStream.listen((Uri uri) async {
    if (kDebugMode) print('[DEEP_LINK_LOG] Stream received URI: $uri');

    if (uri.host == 'reset-password' && uri.queryParameters.containsKey('access_token')) {
      final accessToken = uri.queryParameters['access_token']!;

      // --- THIS IS THE FIX ---
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('password_recovery_email');
      // -----------------------

      if (email == null) {
        if (kDebugMode) print('[DEEP_LINK_LOG] No recovery email found. Cannot proceed.');
        return;
      }

      if (kDebugMode) print('[DEEP_LINK_LOG] Found recovery token and email ($email). Verifying...');

      try {
        // --- Pass the email to verifyOTP ---
        await Supabase.instance.client.auth.verifyOTP(
          token: accessToken,
          type: OtpType.recovery,
          email: email,
        );
        // ---------------------------------
        if (kDebugMode) print('[DEEP_LINK_LOG] verifyOTP call successful.');
      } on AuthException catch (e) {
        if (kDebugMode) print('[DEEP_LINK_LOG] Error during stream verifyOTP: ${e.message}');
      }
    }
  });
}