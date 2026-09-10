package com.huntergoller.vinyl_app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Transparent NDEF router. Never launches or raises MainActivity. */
class NfcEntryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data
        if (intent.action == "android.nfc.action.NDEF_DISCOVERED" &&
            uri?.scheme == "groovefolio" && uri.host == "album"
        ) {
            if (!MainActivity.deliverToExistingHost(intent)) {
                startActivity(Intent(intent).apply {
                    setClass(this@NfcEntryActivity, NfcProcessingActivity::class.java)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
                })
            }
        }
        finish()
    }
}
