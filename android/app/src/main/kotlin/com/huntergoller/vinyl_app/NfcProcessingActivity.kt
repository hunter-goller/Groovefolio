package com.huntergoller.vinyl_app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/** Cold-start host: Flutter processes the play but never paints Collection. */
class NfcProcessingActivity : MainActivity() {
    override val isNfcOnlyHost = true
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val releaseWindow = Runnable { if (!isFinishing) finish() }

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Texture rendering (transparent mode) avoids an opaque SurfaceView.
        // Alpha, not GONE, allows Flutter's first-frame/bootstrap to complete.
        findViewById<View>(android.R.id.content).alpha = 0f
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
        // A bootstrap/plugin error must not leave an invisible activity above
        // the user's screen forever. Do not retry a possibly committed play.
        timeoutHandler.postDelayed(releaseWindow, 30_000L)
    }

    override fun onDestroy() {
        timeoutHandler.removeCallbacks(releaseWindow)
        super.onDestroy()
    }
}
