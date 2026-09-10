package com.huntergoller.vinyl_app

/**
 * Records whether an album-tag intent arrived while Groovefolio was already
 * visible. Flutter consumes deliveries in the same order that AppLinks emits
 * their URIs, so repeated identical tags remain distinct events.
 */
internal class NfcDeliveryTracker {
    private val pending = ArrayDeque<NfcDelivery>()
    private var nextId = 1L

    @Synchronized
    fun record(
        action: String?,
        scheme: String?,
        host: String?,
        wasVisible: Boolean,
    ): NfcDelivery? {
        val isAlbumDelivery =
            (action == "android.nfc.action.NDEF_DISCOVERED" ||
                action == "android.intent.action.VIEW") &&
                scheme.equals("groovefolio", ignoreCase = true) &&
                host.equals("album", ignoreCase = true)
        if (!isAlbumDelivery) return null

        return NfcDelivery(id = nextId++, external = !wasVisible).also {
            pending.addLast(it)
        }
    }

    @Synchronized
    fun consume(): NfcDelivery? = if (pending.isEmpty()) null else pending.removeFirst()
}

internal data class NfcDelivery(val id: Long, val external: Boolean)
