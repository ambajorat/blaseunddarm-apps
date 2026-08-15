package de.bajorat.blaseunddarm.notification

import de.bajorat.blaseunddarm.data.tr

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import de.bajorat.blaseunddarm.R

class ReminderManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "toilet_reminder"
        const val NOTIFICATION_ID = 1001
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            tr("Toiletten-Erinnerung"),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = tr("Erinnerungen an Toilettengänge")
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    fun scheduleReminder(afterMinutes: Int, quietFrom: Int = 22, quietTo: Int = 6, quietEnabled: Boolean = true) {
        cancelAll()

        var triggerTime = System.currentTimeMillis() + (afterMinutes * 60 * 1000L)

        // Skip quiet hours
        if (quietEnabled) {
            val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerTime }
            val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
            val inQuiet = if (quietFrom < quietTo) {
                hour in quietFrom until quietTo
            } else {
                hour >= quietFrom || hour < quietTo
            }
            if (inQuiet) {
                cal.set(java.util.Calendar.HOUR_OF_DAY, quietTo)
                cal.set(java.util.Calendar.MINUTE, 0)
                cal.set(java.util.Calendar.SECOND, 0)
                if (cal.timeInMillis <= triggerTime) {
                    cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
                }
                triggerTime = cal.timeInMillis
            }
        }

        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerTime,
            pendingIntent
        )
    }

    fun scheduleQuietHoursNotifications(quietFrom: Int, quietTo: Int, quietEnabled: Boolean) {
        if (!quietEnabled) return

        val alarmManager = context.getSystemService(AlarmManager::class.java)

        // Start of quiet hours
        val startCal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, quietFrom)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_MONTH, 1)
        }
        val startIntent = Intent(context, QuietHoursReceiver::class.java).apply { putExtra("type", "start"); putExtra("quietTo", quietTo) }
        val startPending = PendingIntent.getBroadcast(context, 100, startIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(AlarmManager.RTC_WAKEUP, startCal.timeInMillis, AlarmManager.INTERVAL_DAY, startPending)

        // End of quiet hours
        val endCal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, quietTo)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_MONTH, 1)
        }
        val endIntent = Intent(context, QuietHoursReceiver::class.java).apply { putExtra("type", "end") }
        val endPending = PendingIntent.getBroadcast(context, 101, endIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(AlarmManager.RTC_WAKEUP, endCal.timeInMillis, AlarmManager.INTERVAL_DAY, endPending)
    }

    fun cancelAll() {
        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.cancel(pendingIntent)
    }
}

class QuietHoursReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type") ?: return
        val title: String
        val body: String
        if (type == "start") {
            val quietTo = intent.getIntExtra("quietTo", 6)
            title = tr("Ruhezeit beginnt")
            body = "Erinnerungen sind bis $quietTo:00 Uhr pausiert. Gute Nacht!"
        } else {
            title = tr("Ruhezeit beendet")
            body = tr("Erinnerungen sind wieder aktiv.")
        }
        val notification = NotificationCompat.Builder(context, ReminderManager.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(if (type == "end") NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(if (type == "start") 1002 else 1003, notification)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Vibrate
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(VibratorManager::class.java)
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
        vibrator?.vibrate(
            VibrationEffect.createWaveform(
                longArrayOf(0, 500, 200, 500, 200, 500), -1
            )
        )

        // Show notification
        val notification = NotificationCompat.Builder(context, ReminderManager.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(tr("⚠️ Toiletten-Erinnerung"))
            .setContentText(tr("Zeit für den nächsten Toilettengang!"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(ReminderManager.NOTIFICATION_ID, notification)
    }
}
