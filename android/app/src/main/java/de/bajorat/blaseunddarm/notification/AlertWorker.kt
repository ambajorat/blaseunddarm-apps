package de.bajorat.blaseunddarm.notification

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import de.bajorat.blaseunddarm.data.AlertEngine
import de.bajorat.blaseunddarm.data.BDMDataStore
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalDate

/**
 * Täglicher Hinweise-Check um ~18 Uhr per WorkManager.
 * Das ist der Android-Vorteil gegenüber iOS: "Unter"-Warnungen
 * (zu wenig getrunken, zu wenige Gänge, unter dem eigenen Schnitt)
 * kommen von selbst — ohne dass die App geöffnet wird.
 */
class AlertWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val store = BDMDataStore(applicationContext)
        AlertEngine.checkDay(applicationContext, store.entries.value)
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "bdm_alert_evening_check"

        /** Einmal beim App-Start aufrufen (z. B. in MainActivity.onCreate). */
        fun schedule(context: Context) {
            val now = LocalDateTime.now()
            var target = LocalDate.now().atTime(AlertEngine.UNDER_CHECK_HOUR, 5)
            if (target.isBefore(now)) target = target.plusDays(1)
            val initialDelay = Duration.between(now, target)

            val request = PeriodicWorkRequestBuilder<AlertWorker>(Duration.ofDays(1))
                .setInitialDelay(initialDelay)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }
    }
}
