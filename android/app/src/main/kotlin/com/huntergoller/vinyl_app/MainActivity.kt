package com.huntergoller.vinyl_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference

open class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.huntergoller.vinyl_app/nfc_notifications"
        private const val SHOW_NFC_PLAY_LOGGED = "showNfcPlayLogged"
        private const val REQUEST_NFC_NOTIFICATION_PERMISSION =
            "requestNfcNotificationPermission"
        private const val FOREGROUND_INTENT_CHANNEL =
            "com.huntergoller.vinyl_app/nfc_foreground_intents"
        private const val DELIVERY_CHANNEL =
            "com.huntergoller.vinyl_app/nfc_delivery"
        private const val SET_FOREGROUND_NFC_OPERATION_ACTIVE =
            "setForegroundNfcOperationActive"
        private const val NOTIFICATION_CHANNEL_ID = "nfc_play_logging"
        private const val NOTIFICATION_CHANNEL_NAME = "NFC play logging"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
        private const val NOTIFICATION_PERMISSION_ASKED = "notification_permission_asked"
        private const val MAX_ARTWORK_BYTES = 8L * 1024L * 1024L
        private const val MAX_ARTWORK_DIMENSION = 1024

        private val foregroundIntentGate = NfcIntentGate(SystemClock::elapsedRealtime)
        private val nfcDeliveryTracker = NfcDeliveryTracker()
        private var retainedEngine: FlutterEngine? = null
        private var currentHost = WeakReference<MainActivity>(null)

        /** Deliver without startActivity: never raises the Collection task. */
        internal fun deliverToExistingHost(intent: Intent): Boolean {
            val host = currentHost.get() ?: return false
            if (host.isFinishing || host.isDestroyed) return false
            host.onNewIntent(intent)
            return true
        }
    }

    private val nfcGateOwner = Any()
    private var isActivityVisible = false
    private var pendingPermissionResult: MethodChannel.Result? = null
    protected open val isNfcOnlyHost = false

    override fun provideFlutterEngine(context: Context): FlutterEngine? = retainedEngine

    // Keep the database, URI subscription and cooldown in one engine when the
    // transparent host finishes or the user later opens the real app.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val suppressed = shouldSuppressAlbumNfcIntent(intent)
        if (!suppressed) recordAlbumNfcDelivery(intent)
        traceNfcEntry("onCreate", suppressed)
        if (suppressed) {
            // AppLinks inspects activity.intent when Flutter attaches. Remove
            // the complete NFC payload BEFORE super creates/attaches the engine.
            intent = Intent(this, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
        }
        super.onCreate(savedInstanceState)
        currentHost = WeakReference(this)
        // singleTask normally routes to the existing activity; if Android did
        // create a second one, return to the original dialog without logging.
        if (suppressed) {
            finish()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        retainedEngine = flutterEngine
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    SHOW_NFC_PLAY_LOGGED -> {
                        val notification = parseNotification(call)
                        if (notification == null) {
                            result.error(
                                "invalid_arguments",
                                "Invalid NFC notification data",
                                null,
                            )
                        } else {
                            result.success(showNotification(notification))
                        }
                    }
                    REQUEST_NFC_NOTIFICATION_PERMISSION -> {
                        requestNfcNotificationPermission(result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_INTENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != SET_FOREGROUND_NFC_OPERATION_ACTIVE) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val active = call.argument<Boolean>("active")
                if (active == null) {
                    result.error("invalid_arguments", "Missing NFC operation state", null)
                    return@setMethodCallHandler
                }

                foregroundIntentGate.setActive(nfcGateOwner, active)
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DELIVERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeNfcDelivery" -> {
                        val delivery = nfcDeliveryTracker.consume()
                        result.success(
                            delivery?.let {
                                mapOf("id" to it.id, "external" to it.external)
                            },
                        )
                    }
                    "completeExternalNfcDelivery" -> {
                        val id = call.argument<Number>("id")?.toLong()
                        if (nfcDeliveryTracker.complete(id) && isNfcOnlyHost) finish()
                        result.success(null)
                    }
                    "showExternalNfcMessage" -> {
                        val message = safeArgument(call, "message", 240)
                        if (message == null) {
                            result.error("invalid_arguments", "Missing NFC message", null)
                        } else {
                            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        val suppressed = shouldSuppressAlbumNfcIntent(intent)
        if (!suppressed) recordAlbumNfcDelivery(intent)
        traceNfcEntry("onNewIntent", suppressed)
        if (suppressed) return
        super.onNewIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        isActivityVisible = !isNfcOnlyHost
    }

    override fun onStop() {
        isActivityVisible = false
        super.onStop()
    }

    private fun recordAlbumNfcDelivery(intent: Intent): NfcDelivery? {
        return nfcDeliveryTracker.record(
            action = intent.action,
            scheme = intent.data?.scheme,
            host = intent.data?.host,
            wasVisible = isActivityVisible,
        )
    }

    private fun shouldSuppressAlbumNfcIntent(intent: Intent): Boolean {
        val uri = intent.data
        return foregroundIntentGate.shouldSuppress(intent.action, uri?.scheme, uri?.host)
    }

    override fun onDestroy() {
        if (currentHost.get() === this) currentHost.clear()
        foregroundIntentGate.setActive(nfcGateOwner, false)
        super.onDestroy()
    }

    override fun detachFromFlutterEngine() {
        super.detachFromFlutterEngine()
        // A notification/launcher opening MainActivity takes over the same
        // engine. The old transparent host must not remain in another task.
        if (isNfcOnlyHost) finish()
    }

    private fun traceNfcEntry(entry: String, suppressed: Boolean) {
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            // No album IDs, URIs, credentials, or NDEF contents in diagnostics.
            Log.d("GroovefolioNfc", "$entry task=$taskId suppressed=$suppressed")
        }
    }

    private fun parseNotification(call: MethodCall): NfcPlayNotification? {
        val playId = safeArgument(call, "playId", 128) ?: return null
        val albumId = safeArgument(call, "albumId", 128) ?: return null
        val albumTitle = safeArgument(call, "albumTitle", 200) ?: return null
        val sideLabel = safeArgument(call, "sideLabel", 40) ?: return null
        val artworkPath = call.argument<String>("artworkPath")?.trim()?.take(4096)
        return NfcPlayNotification(playId, albumId, albumTitle, sideLabel, artworkPath)
    }

    private fun safeArgument(call: MethodCall, key: String, maxLength: Int): String? {
        return call.argument<String>(key)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.take(maxLength)
    }

    private fun requestNfcNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        val preferences = getSharedPreferences("groovefolio_notifications", MODE_PRIVATE)
        if (preferences.getBoolean(NOTIFICATION_PERMISSION_ASKED, false) ||
            pendingPermissionResult != null
        ) {
            result.success(false)
            return
        }

        preferences.edit().putBoolean(NOTIFICATION_PERMISSION_ASKED, true).apply()
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun showNotification(notification: NfcPlayNotification): Boolean {
        return try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                !manager.areNotificationsEnabled()
            ) {
                return false
            }

            createNotificationChannel(manager)
            val notificationId = notification.playId.hashCode() and Int.MAX_VALUE
            // An explicit immutable navigation intent, never a tag/log URI.
            val launchIntent = Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.Builder()
                    .scheme("groovefolio-notification")
                    .authority("album")
                    .appendPath(notification.albumId)
                    .appendPath(notification.playId)
                    .build())
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val contentIntent = PendingIntent.getActivity(
                this,
                notificationId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val title = "Play logged: ${notification.albumTitle}"
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
                .setSmallIcon(R.drawable.ic_launcher_monochrome)
                .setContentTitle(title)
                .setContentText(notification.sideLabel)
                .setCategory(Notification.CATEGORY_STATUS)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentIntent)

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                builder.setPriority(Notification.PRIORITY_HIGH)
            }

            val artwork = decodeArtwork(notification.artworkPath)
            if (artwork == null) {
                builder.setStyle(
                    Notification.BigTextStyle()
                        .setBigContentTitle(title)
                        .bigText(notification.sideLabel),
                )
            } else {
                builder
                    .setLargeIcon(artwork)
                    .setStyle(
                        Notification.BigPictureStyle()
                            .setBigContentTitle(title)
                            .setSummaryText(notification.sideLabel)
                            .bigPicture(artwork),
                    )
            }

            // String tags avoid hash collisions between unrelated play IDs.
            manager.notify(notification.playId, 0, builder.build())
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun createNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Confirms plays logged by tapping a record's NFC tag"
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannel(channel)
    }

    private fun decodeArtwork(path: String?): Bitmap? {
        if (path.isNullOrBlank()) return null

        val artwork = try {
            File(path).canonicalFile
        } catch (_: Exception) {
            return null
        }
        val dataRoot = try {
            File(applicationInfo.dataDir).canonicalFile
        } catch (_: Exception) {
            return null
        }
        if (!artwork.path.startsWith(dataRoot.path + File.separator) ||
            !artwork.isFile ||
            artwork.length() !in 1..MAX_ARTWORK_BYTES
        ) {
            return null
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(artwork.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (bounds.outWidth / sampleSize > MAX_ARTWORK_DIMENSION ||
            bounds.outHeight / sampleSize > MAX_ARTWORK_DIMENSION
        ) {
            sampleSize *= 2
        }

        return BitmapFactory.decodeFile(
            artwork.path,
            BitmapFactory.Options().apply { inSampleSize = sampleSize },
        )
    }

    private data class NfcPlayNotification(
        val playId: String,
        val albumId: String,
        val albumTitle: String,
        val sideLabel: String,
        val artworkPath: String?,
    )
}
