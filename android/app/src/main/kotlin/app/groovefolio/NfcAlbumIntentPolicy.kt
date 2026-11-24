package app.groovefolio

/**
 * Decides whether an intent claiming to be an album tag tap can be trusted.
 *
 * Groovefolio's NFC activities are exported (Android's NFC service must be
 * able to reach them), so any installed app can send them an intent with a
 * `groovefolio://album/<id>` URI. A real tap is delivered by the NFC service
 * with the tag attached (`NfcAdapter.EXTRA_TAG`); a plain intent from another
 * app has the URI but no tag. Such an intent must never log a play.
 *
 * Kept free of Android types so it can be unit tested on the JVM.
 */
internal object NfcAlbumIntentPolicy {
    private const val NDEF_DISCOVERED = "android.nfc.action.NDEF_DISCOVERED"
    private const val VIEW = "android.intent.action.VIEW"

    /** True for an intent that would log an album play if trusted. */
    fun claimsAlbumTap(action: String?, scheme: String?, host: String?): Boolean =
        action == NDEF_DISCOVERED ||
            (action == VIEW &&
                scheme.equals("groovefolio", ignoreCase = true) &&
                host.equals("album", ignoreCase = true))

    /**
     * True when an intent claims to be an album tap but carries no tag, so it
     * can't have come from the NFC service. Real taps, including ones
     * forwarded inside Groovefolio with `Intent(intent)`, keep the tag.
     */
    fun isForged(action: String?, scheme: String?, host: String?, hasTag: Boolean): Boolean =
        !hasTag && claimsAlbumTap(action, scheme, host)
}
