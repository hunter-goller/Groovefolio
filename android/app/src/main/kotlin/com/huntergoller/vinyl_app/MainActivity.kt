package com.huntergoller.vinyl_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.nfc.NfcAdapter
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.huntergoller.vinyl_app/nfc_notifications"
        private const val SHOW_NFC_PLAY_LOGGED = "showNfcPlayLogged"
        private const val FOREGROUND_INTENT_CHANNEL =
            "com.huntergoller.vinyl_app/nfc_foreground_intents"
        private const val SET_FOREGROUND_NFC_OPERATION_ACTIVE =
            "setForegroundNfcOperationActive"
        private const val FOREGROUND_INTENT_COOLDOWN_MILLIS = 5_000L
        private const val NOTIFICATION_CHANNEL_ID = "nfc_play_logging"
        private const val NOTIFICATION_CHANNEL_NAME = "NFC play logging"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
        private const val NOTIFICATION_PERMISSION_ASKED = "notification_permission_asked"
        private const val MAX_ARTWORK_BYTES = 8L * 1024L * 1024L
        private const val MAX_ARTWORK_DIMENSION = 1024

        @Volatile
        private var foregroundNfcOperationActive = false

        @Volatile
        private var suppressAlbumNfcIntentsUntil = 0L
    }

    private var pendingNotification: NfcPlayNotification? = null
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != SHOW_NFC_PLAY_LOGGED) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val notification = parseNotification(call)
                if (notification == null) {
                    result.error("invalid_arguments", "Invalid NFC notification data", null)
                    return@setMethodCallHandler
                }
                showOrRequestNotificationPermission(notification, result)
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

                foregroundNfcOperationActive = active
                suppressAlbumNfcIntentsUntil = if (active) {
                    Long.MAX_VALUE
                } else {
                    SystemClock.elapsedRealtime() + FOREGROUND_INTENT_COOLDOWN_MILLIS
                }
                result.success(null)
            }
    }

    override fun onNewIntent(intent: Intent) {
        if (shouldSuppressAlbumNfcIntent(intent)) return
        super.onNewIntent(intent)
    }

    private fun shouldSuppressAlbumNfcIntent(intent: Intent): Boolean {
        if (intent.action != NfcAdapter.ACTION_NDEF_DISCOVERED) return false

        val uri = intent.data ?: return false
        if (!uri.scheme.equals("groovefolio", ignoreCase = true) ||
            !uri.host.equals("album", ignoreCase = true)
        ) {
            return false
        }

        return foregroundNfcOperationActive ||
            SystemClock.elapsedRealtime() < suppressAlbumNfcIntentsUntil
    }

    private fun parseNotification(call: MethodCall): NfcPlayNotification? {
        val playId = safeArgument(call, "playId", 128) ?: return null
        val albumTitle = safeArgument(call, "albumTitle", 200) ?: return null
        val sideLabel = safeArgument(call, "sideLabel", 40) ?: return null
        val artworkPath = call.argument<String>("artworkPath")?.trim()?.take(4096)
        return NfcPlayNotification(playId, albumTitle, sideLabel, artworkPath)
    }

    private fun safeArgument(call: MethodCall, key: String, maxLength: Int): String? {
        return call.argument<String>(key)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.take(maxLength)
    }

    private fun showOrRequestNotificationPermission(
        notification: NfcPlayNotification,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            val preferences = getSharedPreferences("groovefolio_notifications", MODE_PRIVATE)
            if (preferences.getBoolean(NOTIFICATION_PERMISSION_ASKED, false) ||
                pendingNotificationResult != null
            ) {
                result.success(false)
                return
            }

            preferences.edit().putBoolean(NOTIFICATION_PERMISSION_ASKED, true).apply()
            pendingNotification = notification
            pendingNotificationResult = result
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
            return
        }

        result.success(showNotification(notification))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

        val notification = pendingNotification
        val result = pendingNotificationResult
        pendingNotification = null
        pendingNotificationResult = null

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        result?.success(granted && notification != null && showNotification(notification))
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
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
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

            manager.notify(notificationId, builder.build())
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
        val albumTitle: String,
        val sideLabel: String,
        val artworkPath: String?,
    )
}
