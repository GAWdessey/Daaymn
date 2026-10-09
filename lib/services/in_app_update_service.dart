import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InAppUpdateService {
  Future<void> checkForUpdate() async {
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed && await _isBelowMinimumVersion()) {
          // This version no longer works with the backend: block until updated
          final result = await InAppUpdate.performImmediateUpdate();
          if (result != AppUpdateResult.success) {
            await SystemNavigator.pop();
          }
          return;
        }

        // An update is available. Start a flexible update.
        // This will show a dialog to the user.
        await InAppUpdate.startFlexibleUpdate();
        
        // After the flexible update is started, you can optionally listen for the download to complete
        // and then prompt the user to install it.
        InAppUpdate.completeFlexibleUpdate().then((_) {
          print("Flexible update completed and app is restarting.");
        }).catchError((e) {
          print("Error completing flexible update: $e");
        });

      }
    } catch (e) {
      print("Error checking for in-app update: $e");
    }
  }

  // The minimum lives in public.app_config so it can be raised without a
  // release; if it can't be read, fall back to the flexible update.
  Future<bool> _isBelowMinimumVersion() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'min_android_version_code')
          .maybeSingle();
      final minVersionCode = (row?['value'] as num?)?.toInt();
      if (minVersionCode == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      return installedVersionCode < minVersionCode;
    } catch (e) {
      debugPrint("Error reading minimum app version: $e");
      return false;
    }
  }
}
