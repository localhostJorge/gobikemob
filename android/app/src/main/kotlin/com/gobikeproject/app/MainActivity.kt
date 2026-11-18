package com.gobikeproject.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * One channel per sound/vibration choice in the resident's Notification Settings. The server
     * picks the channel for each push (gobike_alerts, gobike_sound, gobike_vibrate, gobike_quiet),
     * because Android fixes a channel's sound and vibration once it is created.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        fun channel(id: String, name: String, sound: Boolean, vibrate: Boolean) =
            NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "SOS, home visit and check-up updates"
                enableVibration(vibrate)
                if (!vibrate) vibrationPattern = longArrayOf(0)
                if (!sound) setSound(null, null)
            }

        manager.createNotificationChannels(
            listOf(
                channel("gobike_alerts", "Alerts", sound = true, vibrate = true),
                channel("gobike_sound", "Alerts (sound only)", sound = true, vibrate = false),
                channel("gobike_vibrate", "Alerts (vibrate only)", sound = false, vibrate = true),
                channel("gobike_quiet", "Alerts (silent)", sound = false, vibrate = false),
            )
        )
    }
}
