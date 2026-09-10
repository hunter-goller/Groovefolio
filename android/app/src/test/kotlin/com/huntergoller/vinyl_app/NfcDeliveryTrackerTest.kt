package com.huntergoller.vinyl_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NfcDeliveryTrackerTest {
    private val tracker = NfcDeliveryTracker()

    @Test
    fun visibleTagIsForegroundAndStoppedTagIsExternal() {
        val foreground = tracker.record(ndef, "groovefolio", "album", wasVisible = true)
        val external = tracker.record(ndef, "groovefolio", "album", wasVisible = false)

        assertFalse(foreground!!.external)
        assertTrue(external!!.external)
        assertEquals(foreground, tracker.consume())
        assertEquals(external, tracker.consume())
        assertNull(tracker.consume())
    }

    @Test
    fun identicalUrisRemainSeparateOrderedDeliveries() {
        val first = tracker.record(ndef, "groovefolio", "album", wasVisible = false)
        val second = tracker.record(ndef, "groovefolio", "album", wasVisible = false)

        assertEquals(1L, first!!.id)
        assertEquals(2L, second!!.id)
        assertEquals(first, tracker.consume())
        assertEquals(second, tracker.consume())
    }

    @Test
    fun oauthNotificationAndMalformedIntentsAreIgnored() {
        assertNull(tracker.record(view, "groovefolio", "discogs-auth", false))
        assertNull(tracker.record(view, "groovefolio-notification", "album", false))
        assertNull(tracker.record(ndef, null, null, false))
        assertNull(tracker.record("android.intent.action.MAIN", null, null, false))
        assertNull(tracker.consume())
    }

    private companion object {
        const val ndef = "android.nfc.action.NDEF_DISCOVERED"
        const val view = "android.intent.action.VIEW"
    }
}
