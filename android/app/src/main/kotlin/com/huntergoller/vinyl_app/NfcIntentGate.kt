package com.huntergoller.vinyl_app

/** Process-wide policy shared by cold and warm activity entry points.
 * Each activity owns its gate, so destroying one cannot release another's.
 */
internal class NfcIntentGate(
    private val nowMillis: () -> Long,
    private val cooldownMillis: Long = 5_000L,
) {
    private val owners = mutableSetOf<Any>()
    private var suppressUntil = 0L

    @Synchronized
    fun setActive(owner: Any, active: Boolean) {
        if (active) {
            owners.add(owner)
        } else if (owners.remove(owner) && owners.isEmpty()) {
            suppressUntil = nowMillis() + cooldownMillis
        }
    }

    @Synchronized
    fun shouldSuppress(action: String?, scheme: String?, host: String?): Boolean {
        // Block NFC delivery even if Android omitted Intent.data. Do not
        // intercept OAuth callbacks, launcher intents, or other VIEW links.
        val isAlbumDelivery = action == "android.nfc.action.NDEF_DISCOVERED" ||
            (action == "android.intent.action.VIEW" &&
                scheme.equals("groovefolio", ignoreCase = true) &&
                host.equals("album", ignoreCase = true))
        return isAlbumDelivery && (owners.isNotEmpty() || nowMillis() < suppressUntil)
    }
}
