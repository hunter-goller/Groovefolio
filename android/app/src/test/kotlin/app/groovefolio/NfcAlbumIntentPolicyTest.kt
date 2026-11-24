package app.groovefolio

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NfcAlbumIntentPolicyTest {
    private val ndef = "android.nfc.action.NDEF_DISCOVERED"
    private val view = "android.intent.action.VIEW"
    private val main = "android.intent.action.MAIN"

    @Test
    fun realTapsWithTheTagAreTrusted() {
        assertFalse(NfcAlbumIntentPolicy.isForged(ndef, "groovefolio", "album", hasTag = true))
        // Forwarded inside the app with Intent(intent): still carries the tag.
        assertFalse(NfcAlbumIntentPolicy.isForged(view, "groovefolio", "album", hasTag = true))
    }

    @Test
    fun albumLinksWithoutATagAreForged() {
        assertTrue(NfcAlbumIntentPolicy.isForged(ndef, "groovefolio", "album", hasTag = false))
        assertTrue(NfcAlbumIntentPolicy.isForged(view, "groovefolio", "album", hasTag = false))
        assertTrue(NfcAlbumIntentPolicy.isForged(view, "GROOVEFOLIO", "ALBUM", hasTag = false))
        // An NDEF delivery with no tag can't be real, whatever its data.
        assertTrue(NfcAlbumIntentPolicy.isForged(ndef, null, null, hasTag = false))
    }

    @Test
    fun otherLinksAndLaunchesAreUntouched() {
        assertFalse(NfcAlbumIntentPolicy.isForged(main, null, null, hasTag = false))
        assertFalse(
            NfcAlbumIntentPolicy.isForged(view, "groovefolio", "discogs-auth", hasTag = false),
        )
        assertFalse(
            NfcAlbumIntentPolicy.isForged(
                view,
                "groovefolio-notification",
                "album",
                hasTag = false,
            ),
        )
        assertFalse(NfcAlbumIntentPolicy.isForged(null, null, null, hasTag = false))
    }
}
