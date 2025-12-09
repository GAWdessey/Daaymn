package com.daaymn.daaymn

import io.flutter.app.FlutterApplication
import androidx.multidex.MultiDex

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        MultiDex.install(this)
    }
}
