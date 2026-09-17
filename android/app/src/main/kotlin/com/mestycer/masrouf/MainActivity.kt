package com.mestycer.masrouf

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE keeps the ledger out of the recent-apps thumbnail and
        // blocks screenshots and screen recording of it. The app puts account
        // balances on its first screen, so the recents preview alone leaks them
        // to anyone who picks up an unlocked phone.
        //
        // Release builds only. In debug it would also block the developer's own
        // screenshots and `adb shell screencap`, which is how this app is
        // actually inspected while being built. Read from the manifest's
        // debuggable flag rather than BuildConfig, which newer AGP versions do
        // not generate unless buildConfig is explicitly enabled.
        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onCreate(savedInstanceState)
    }
}
