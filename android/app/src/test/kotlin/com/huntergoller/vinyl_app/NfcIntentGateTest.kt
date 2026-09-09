package com.huntergoller.vinyl_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NfcIntentGateTest {
    private var time = 0L
    private val gate = NfcIntentGate({ time })
    private val owner = Any()
    private val ndef = "android.nfc.action.NDEF_DISCOVERED"
    private val view = "android.intent.action.VIEW"

    @Test
    fun ordinaryColdAndWarmTapsAreAllowed() {
        assertFalse(gate.shouldSuppress(ndef, "groovefolio", "album"))
        assertFalse(gate.shouldSuppress(view, "groovefolio", "album"))
    }

    @Test
    fun openErrorDialogRemainsProtectedBeyondAnyCooldown() {
        gate.setActive(owner, true)
        time = 60_000L
        assertTrue(gate.shouldSuppress(ndef, "groovefolio", "album"))
        assertTrue(gate.shouldSuppress(view, "GROOVEFOLIO", "ALBUM"))
        assertTrue(gate.shouldSuppress(ndef, null, null))
    }

    @Test
    fun closingInteractionSuppressesDelayedTapThenAllowsNewTap() {
        gate.setActive(owner, true)
        gate.setActive(owner, false)
        time = 500L
        assertTrue(gate.shouldSuppress(ndef, "groovefolio", "album"))
        time = 5_000L
        assertFalse(gate.shouldSuppress(ndef, "groovefolio", "album"))
    }

    @Test
    fun newActivityUsesSamePolicyAndCannotReleaseOriginalDialog() {
        gate.setActive(owner, true)
        val newActivityOwner = Any()
        // onCreate consults this process-wide gate before Flutter attaches.
        assertTrue(gate.shouldSuppress(ndef, "groovefolio", "album"))
        gate.setActive(newActivityOwner, false)
        time = 60_000L
        assertTrue(gate.shouldSuppress(ndef, "groovefolio", "album"))
    }

    @Test
    fun retryAndDuplicateCleanupDoNotLeaveGateStuckOrExtendCooldown() {
        gate.setActive(owner, true)
        gate.setActive(owner, true)
        gate.setActive(owner, false)
        time = 4_000L
        gate.setActive(owner, false)
        time = 5_000L
        assertFalse(gate.shouldSuppress(ndef, "groovefolio", "album"))
    }

    @Test
    fun otherActivityStillOwnsProtectionUntilItCloses() {
        val other = Any()
        gate.setActive(owner, true)
        gate.setActive(other, true)
        gate.setActive(owner, false)
        time = 60_000L
        assertTrue(gate.shouldSuppress(ndef, "groovefolio", "album"))
        gate.setActive(other, false)
        time += 5_000L
        assertFalse(gate.shouldSuppress(ndef, "groovefolio", "album"))
    }

    @Test
    fun oauthAndNotificationLauncherIntentsAreNotSuppressed() {
        gate.setActive(owner, true)
        assertFalse(gate.shouldSuppress(view, "groovefolio", "discogs-auth"))
        assertFalse(gate.shouldSuppress(view, "https", "groovefolio.app"))
        assertFalse(gate.shouldSuppress("android.intent.action.MAIN", null, null))
    }
}
