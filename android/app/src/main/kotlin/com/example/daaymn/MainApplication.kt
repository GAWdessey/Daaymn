
package com.example.daaymn

import android.content.Context
import io.flutter.app.FlutterApplication
import android.util.Log
import java.io.File

class MainApplication : FlutterApplication() {

    override fun onCreate() {
        super.onCreate()
        try {
            // This is a dummy call to trigger the EncryptedSharedPreferences initialization
            // early, within a try-catch block.
            getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
        } catch (e: Exception) {
            Log.e("MainApplication", "EncryptedSharedPreferences failed to initialize.", e)
            
            // Check if the exception is the one we are looking for.
            if (e.message?.contains("AEADBadTagException") == true || 
                e.cause?.message?.contains("AEADBadTagException") == true) {
                
                Log.w("MainApplication", "AEADBadTagException detected. Clearing app data...")
                
                // This is a last resort to recover from a corrupted state.
                // This will clear all app data, including SharedPreferences, databases, etc.
                val dataDir = File(applicationInfo.dataDir)
                if (clearDirectory(dataDir)) {
                    Log.i("MainApplication", "App data cleared successfully.")
                    // Restart the app to apply changes
                    System.exit(0)
                } else {
                    Log.e("MainApplication", "Failed to clear app data.")
                }
            }
        }
    }

    private fun clearDirectory(dir: File): Boolean {
        if (!dir.exists()) return true
        for (file in dir.listFiles() ?: return dir.delete()) {
            if (file.isDirectory) {
                if (!clearDirectory(file)) return false
            } else {
                if (!file.delete()) return false
            }
        }
        return dir.delete()
    }
}
