import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  Future<void> checkForUpdate() async {
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
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
}
