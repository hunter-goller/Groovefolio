package app.groovefolio

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Bundle

/** Transparent NDEF router. Never launches or raises MainActivity. */
class NfcEntryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data
        // Only a real tap (delivered by the NFC service with the tag attached)
        // is forwarded. Another app's tagless album link is dropped.
        val realTap = !NfcAlbumIntentPolicy.isForged(
            action = intent.action,
            scheme = uri?.scheme,
            host = uri?.host,
            hasTag = intent.hasExtra(NfcAdapter.EXTRA_TAG),
        )
        if (realTap && intent.action == "android.nfc.action.NDEF_DISCOVERED" &&
            uri?.scheme == "groovefolio" && uri.host == "album"
        ) {
            if (!MainActivity.deliverToExistingHost(intent)) {
                // Intent(intent) copies the extras, so the tag stays attached.
                startActivity(Intent(intent).apply {
                    setClass(this@NfcEntryActivity, NfcProcessingActivity::class.java)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
                })
            }
        }
        finish()
    }
}
