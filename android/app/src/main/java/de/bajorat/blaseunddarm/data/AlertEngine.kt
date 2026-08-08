package de.bajorat.blaseunddarm.data

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import de.bajorat.blaseunddarm.R
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

enum class RuleState { OK, WARN, WAITING, NO_DATA }

data class RuleStatus(
    val id: String,
    val title: String,
    val detail: String,
    val state: RuleState
)

data class Baseline(
    val avgMl: Int,
    val avgCount: Double,
    val days: Int
)

/**
 * Prüf-Logik für den "Hinweise"-Reiter — Regeln und Texte identisch zur
 * iOS-Fassung: Einzelmenge sofort beim Eintrag, "Über"-Checks jederzeit,
 * "Unter"-Checks ab 18 Uhr, persönliche 14-Tage-Baseline (mind. 5 Datentage).
 * Jede Warnung feuert pro Regel und Tag genau einmal.
 */
object AlertEngine {

    const val UNDER_CHECK_HOUR = 18
    private const val CHANNEL_ID = "toilet_alerts"
    private const val PREFS = "bb_data"

    // MARK: Baseline

    fun baseline(entries: List<ToiletEntry>): Baseline? {
        val today = LocalDate.now()
        val mlValues = mutableListOf<Int>()
        val counts = mutableListOf<Int>()
        for (i in 1..14) {
            val day = today.minusDays(i.toLong())
            val dayEntries = entries.filter { it.dateTime.toLocalDate() == day }
            if (dayEntries.isEmpty()) continue
            mlValues.add(dayEntries.sumOf { it.urineMl })
            counts.add(dayEntries.size)
        }
        if (mlValues.size < 5) return null
        return Baseline(
            avgMl = mlValues.sum() / mlValues.size,
            avgCount = counts.sum().toDouble() / counts.size,
            days = mlValues.size
        )
    }

    // MARK: Prüfungen mit Benachrichtigung

    /** Sofort beim Speichern eines Eintrags. */
    fun checkEntry(context: Context, entry: ToiletEntry, settings: AlertSettings = AlertSettings.load(context)) {
        if (!settings.singleOverEnabled || entry.urineMl < settings.singleOverMl) return
        notifyOnce(
            context,
            rule = "single_${entry.id}",
            title = "Hohe Einzelmenge",
            body = "${entry.urineMl} ml auf einmal — über deiner Grenze von ${settings.singleOverMl} ml."
        )
    }

    /** Tages-Checks: "Über" sofort, "Unter" und Abweichungen nach unten ab 18 Uhr. */
    fun checkDay(context: Context, entries: List<ToiletEntry>, settings: AlertSettings = AlertSettings.load(context)) {
        val today = LocalDate.now()
        val todayEntries = entries.filter { it.dateTime.toLocalDate() == today }
        val ml = todayEntries.sumOf { it.urineMl }
        val count = todayEntries.size
        val dateKey = today.format(DateTimeFormatter.ISO_LOCAL_DATE)
        val lateEnough = LocalDateTime.now().hour >= UNDER_CHECK_HOUR
        val base = if (settings.baselineEnabled) baseline(entries) else null
        val dev = settings.baselineDeviationPercent / 100.0

        if (settings.dayOverEnabled && ml >= settings.dayOverMl) {
            notifyOnce(context, "dayOver_$dateKey", "Hohe Tagesmenge",
                "Heute schon $ml ml — über deiner Grenze von ${settings.dayOverMl} ml.")
        }
        if (settings.countOverEnabled && count >= settings.countOverLimit) {
            notifyOnce(context, "countOver_$dateKey", "Viele Toilettengänge",
                "Heute schon $count Gänge — über deiner Grenze von ${settings.countOverLimit}.")
        }
        if (base != null) {
            if (ml > base.avgMl * (1 + dev)) {
                notifyOnce(context, "baseMlOver_$dateKey", "Deutlich über deinem Schnitt",
                    "Heute $ml ml — dein 14-Tage-Schnitt liegt bei ${base.avgMl} ml.")
            }
            if (count > base.avgCount * (1 + dev)) {
                notifyOnce(context, "baseCountOver_$dateKey", "Häufiger als sonst",
                    "Heute $count Gänge — dein Schnitt liegt bei ${"%.0f".format(base.avgCount)}.")
            }
        }

        if (!lateEnough) return

        if (settings.dayUnderEnabled && ml < settings.dayUnderMl) {
            notifyOnce(context, "dayUnder_$dateKey", "Niedrige Tagesmenge",
                "Bis jetzt $ml ml — unter deiner Grenze von ${settings.dayUnderMl} ml. Genug getrunken?")
        }
        if (settings.countUnderEnabled && count < settings.countUnderLimit) {
            notifyOnce(context, "countUnder_$dateKey", "Wenige Toilettengänge",
                "Bis jetzt $count Gänge — unter deiner Grenze von ${settings.countUnderLimit}.")
        }
        if (base != null) {
            if (ml < base.avgMl * (1 - dev)) {
                notifyOnce(context, "baseMlUnder_$dateKey", "Deutlich unter deinem Schnitt",
                    "Bis jetzt $ml ml — dein 14-Tage-Schnitt liegt bei ${base.avgMl} ml.")
            }
            if (count < base.avgCount * (1 - dev)) {
                notifyOnce(context, "baseCountUnder_$dateKey", "Seltener als sonst",
                    "Bis jetzt $count Gänge — dein Schnitt liegt bei ${"%.0f".format(base.avgCount)}.")
            }
        }
    }

    // MARK: Status-Liste für den Hinweise-Reiter

    fun statusList(entries: List<ToiletEntry>, settings: AlertSettings): List<RuleStatus> {
        val today = LocalDate.now()
        val todayEntries = entries.filter { it.dateTime.toLocalDate() == today }
        val ml = todayEntries.sumOf { it.urineMl }
        val count = todayEntries.size
        val maxSingle = todayEntries.maxOfOrNull { it.urineMl } ?: 0
        val lateEnough = LocalDateTime.now().hour >= UNDER_CHECK_HOUR
        val base = baseline(entries)
        val dev = settings.baselineDeviationPercent / 100.0

        val result = mutableListOf<RuleStatus>()

        if (settings.singleOverEnabled) {
            result.add(RuleStatus("single", "Einzelmenge",
                "größte heute: $maxSingle ml · Grenze ${settings.singleOverMl} ml",
                if (maxSingle >= settings.singleOverMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.dayOverEnabled) {
            result.add(RuleStatus("dayOver", "Tagesmenge zu hoch",
                "$ml ml · Grenze ${settings.dayOverMl} ml",
                if (ml >= settings.dayOverMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.dayUnderEnabled) {
            result.add(RuleStatus("dayUnder", "Tagesmenge zu niedrig",
                "$ml ml · Grenze ${settings.dayUnderMl} ml",
                if (!lateEnough) RuleState.WAITING
                else if (ml < settings.dayUnderMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.countOverEnabled) {
            result.add(RuleStatus("countOver", "Zu viele Gänge",
                "$count · Grenze ${settings.countOverLimit}",
                if (count >= settings.countOverLimit) RuleState.WARN else RuleState.OK))
        }
        if (settings.countUnderEnabled) {
            result.add(RuleStatus("countUnder", "Zu wenige Gänge",
                "$count · Grenze ${settings.countUnderLimit}",
                if (!lateEnough) RuleState.WAITING
                else if (count < settings.countUnderLimit) RuleState.WARN else RuleState.OK))
        }
        if (settings.baselineEnabled) {
            if (base != null) {
                val mlHigh = ml > base.avgMl * (1 + dev)
                val mlLow = lateEnough && ml < base.avgMl * (1 - dev)
                val cntHigh = count > base.avgCount * (1 + dev)
                val cntLow = lateEnough && count < base.avgCount * (1 - dev)
                val deviates = mlHigh || mlLow || cntHigh || cntLow
                result.add(RuleStatus("baseline", "Abweichung vom Schnitt",
                    "Ø ${base.avgMl} ml · Ø ${"%.0f".format(base.avgCount)} Gänge (${base.days} Tage) · ±${settings.baselineDeviationPercent} %",
                    if (deviates) RuleState.WARN else RuleState.OK))
            } else {
                result.add(RuleStatus("baseline", "Abweichung vom Schnitt",
                    "Noch nicht genug Daten (mind. 5 Tage mit Einträgen in den letzten 14 Tagen)",
                    RuleState.NO_DATA))
            }
        }
        return result
    }

    // MARK: Benachrichtigung mit Dedup (pro Regel/Tag genau einmal)

    private fun notifyOnce(context: Context, rule: String, title: String, body: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val flag = "alert_fired_$rule"
        if (prefs.getBoolean(flag, false)) return
        prefs.edit().putBoolean(flag, true).apply()

        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("💡 $title")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        try {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(rule.hashCode(), notification)
        } catch (_: SecurityException) {
            // Benachrichtigungs-Erlaubnis fehlt — still übergehen
        }
    }

    private fun ensureChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Hinweise",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Warnungen bei auffälligen Mengen oder Häufigkeiten"
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
