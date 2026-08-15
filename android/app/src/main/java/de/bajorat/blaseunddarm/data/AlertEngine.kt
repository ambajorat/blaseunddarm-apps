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
 * Prüf-Logik für den tr("Hinweise")-Reiter — Regeln und Texte identisch zur
 * iOS-Fassung: Einzelmenge sofort beim Eintrag, tr("Über")-Checks jederzeit,
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
        checkUtiEntry(context, entry)
        checkAdEntry(context, entry)
        if (!settings.singleOverEnabled || entry.urineMl < settings.singleOverMl) return
        notifyOnce(
            context,
            rule = "single_${entry.id}",
            title = tr("Hohe Einzelmenge"),
            body = trf("{0} ml auf einmal — über deiner Grenze von {1} ml.", entry.urineMl, settings.singleOverMl)
        )
    }

    /** Tages-Checks: tr("Über") sofort, "Unter" und Abweichungen nach unten ab 18 Uhr. */
    fun checkDay(context: Context, entries: List<ToiletEntry>, settings: AlertSettings = AlertSettings.load(context)) {
        val today = LocalDate.now()
        val todayEntries = entries.filter { it.dateTime.toLocalDate() == today }
        val ml = todayEntries.sumOf { it.urineMl }
        val count = todayEntries.size
        val dateKey = today.format(DateTimeFormatter.ISO_LOCAL_DATE)
        val lateEnough = LocalDateTime.now().hour >= UNDER_CHECK_HOUR
        val base = if (settings.baselineEnabled) baseline(entries) else null
        val dev = settings.baselineDeviationPercent / 100.0

        checkCatheterStock(context, entries, dateKey)
        checkUtiDay(context, entries, dateKey)

        if (settings.dayOverEnabled && ml >= settings.dayOverMl) {
            notifyOnce(context, "dayOver_$dateKey", tr("Hohe Tagesmenge"),
                trf("Heute schon {0} ml — über deiner Grenze von {1} ml.", ml, settings.dayOverMl))
        }
        if (settings.countOverEnabled && count >= settings.countOverLimit) {
            notifyOnce(context, "countOver_$dateKey", tr("Viele Toilettengänge"),
                trf("Heute schon {0} Gänge — über deiner Grenze von {1}.", count, settings.countOverLimit))
        }
        if (base != null) {
            if (ml > base.avgMl * (1 + dev)) {
                notifyOnce(context, "baseMlOver_$dateKey", tr("Deutlich über deinem Schnitt"),
                    trf("Heute {0} ml — dein 14-Tage-Schnitt liegt bei {1} ml.", ml, base.avgMl))
            }
            if (count > base.avgCount * (1 + dev)) {
                notifyOnce(context, "baseCountOver_$dateKey", tr("Häufiger als sonst"),
                    trf("Heute {0} Gänge — dein Schnitt liegt bei {1}.", count, "%.0f".format(base.avgCount)))
            }
        }

        if (!lateEnough) return

        if (settings.dayUnderEnabled && ml < settings.dayUnderMl) {
            notifyOnce(context, "dayUnder_$dateKey", tr("Niedrige Tagesmenge"),
                trf("Bis jetzt {0} ml — unter deiner Grenze von {1} ml. Genug getrunken?", ml, settings.dayUnderMl))
        }
        if (settings.countUnderEnabled && count < settings.countUnderLimit) {
            notifyOnce(context, "countUnder_$dateKey", tr("Wenige Toilettengänge"),
                trf("Bis jetzt {0} Gänge — unter deiner Grenze von {1}.", count, settings.countUnderLimit))
        }
        if (base != null) {
            if (ml < base.avgMl * (1 - dev)) {
                notifyOnce(context, "baseMlUnder_$dateKey", tr("Deutlich unter deinem Schnitt"),
                    trf("Bis jetzt {0} ml — dein 14-Tage-Schnitt liegt bei {1} ml.", ml, base.avgMl))
            }
            if (count < base.avgCount * (1 - dev)) {
                notifyOnce(context, "baseCountUnder_$dateKey", tr("Seltener als sonst"),
                    trf("Bis jetzt {0} Gänge — dein Schnitt liegt bei {1}.", count, "%.0f".format(base.avgCount)))
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
            result.add(RuleStatus("single", tr("Einzelmenge"),
                trf("größte heute: {0} ml · Grenze {1} ml", maxSingle, settings.singleOverMl),
                if (maxSingle >= settings.singleOverMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.dayOverEnabled) {
            result.add(RuleStatus("dayOver", tr("Tagesmenge zu hoch"),
                trf("{0} ml · Grenze {1} ml", ml, settings.dayOverMl),
                if (ml >= settings.dayOverMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.dayUnderEnabled) {
            result.add(RuleStatus("dayUnder", tr("Tagesmenge zu niedrig"),
                trf("{0} ml · Grenze {1} ml", ml, settings.dayUnderMl),
                if (!lateEnough) RuleState.WAITING
                else if (ml < settings.dayUnderMl) RuleState.WARN else RuleState.OK))
        }
        if (settings.countOverEnabled) {
            result.add(RuleStatus("countOver", tr("Zu viele Gänge"),
                trf("{0} · Grenze {1}", count, settings.countOverLimit),
                if (count >= settings.countOverLimit) RuleState.WARN else RuleState.OK))
        }
        if (settings.countUnderEnabled) {
            result.add(RuleStatus("countUnder", tr("Zu wenige Gänge"),
                trf("{0} · Grenze {1}", count, settings.countUnderLimit),
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
                result.add(RuleStatus("baseline", tr("Abweichung vom Schnitt"),
                    trf("Ø {0} ml · Ø {1} Gänge ({2} Tage) · ±{3} %", base.avgMl, "%.0f".format(base.avgCount), base.days, settings.baselineDeviationPercent),
                    if (deviates) RuleState.WARN else RuleState.OK))
            } else {
                result.add(RuleStatus("baseline", tr("Abweichung vom Schnitt"),
                    tr("Noch nicht genug Daten (mind. 5 Tage mit Einträgen in den letzten 14 Tagen)"),
                    RuleState.NO_DATA))
            }
        }
        return result
    }

    // MARK: HWI-Frühwarnung (identisch zur iOS-Fassung)

    fun checkUtiEntry(context: Context, entry: ToiletEntry, uti: UtiSettings = UtiSettings.load(context)) {
        if (!uti.enabled) return
        val urgent = entry.utiSymptoms.filter { it.isUrgent }
        if (urgent.isEmpty()) return
        val names = urgent.joinToString(", ") { it.label }
        notifyOnce(context, "utiUrgent_${entry.id}",
            tr("Auffälligkeit erfasst"),
            trf("{0} — bei ISK bitte zeitnah ärztlich abklären.", names))
    }

    fun checkUtiDay(context: Context, entries: List<ToiletEntry>, dateKey: String, uti: UtiSettings = UtiSettings.load(context)) {
        if (!uti.enabled) return
        val today = LocalDate.now()

        fun daySymptoms(offset: Long): Set<UtiSymptom> =
            entries.filter { it.dateTime.toLocalDate() == today.minusDays(offset) }
                .flatMap { it.utiSymptoms }.toSet()

        val t = daySymptoms(0)
        val y = daySymptoms(1)
        if (t.isNotEmpty() && y.isNotEmpty() && (t + y).size >= 2) {
            notifyOnce(context, "utiPattern_$dateKey",
                tr("Auffälligkeiten seit zwei Tagen"),
                tr("Mehrere Anzeichen an zwei Tagen in Folge — das kann bei ISK auf einen Harnwegsinfekt hindeuten. Ggf. ärztlich abklären."))
        }

        var darkDays = 0
        for (i in 0..2L) {
            val day = today.minusDays(i)
            val colored = entries.filter { it.dateTime.toLocalDate() == day && it.urineColor != UrineColor.NONE.name }
            if (colored.isEmpty()) continue
            val dark = colored.count { it.urineColor == UrineColor.DARK_YELLOW.name || it.urineColor == UrineColor.CLOUDY.name }
            if (dark * 2 > colored.size) darkDays++
        }
        if (darkDays >= 2) {
            notifyOnce(context, "utiColor_$dateKey",
                tr("Urin auffällig dunkel oder trüb"),
                tr("An mehreren Tagen überwiegend dunkler oder trüber Urin — mehr trinken und beobachten; hält es an, ärztlich abklären."))
        }
    }

    // MARK: Vegetative Zeichen (AD)

    fun checkAdEntry(context: Context, entry: ToiletEntry, ad: AdSettings = AdSettings.load(context)) {
        if (!ad.enabled) return
        if (entry.adSignList.isEmpty() || entry.urineMl > 0) return
        notifyOnce(context, "adSigns_${entry.id}",
            tr("Vegetative Zeichen erfasst"),
            tr("Bei voller Blase können das Füllungssignale sein — Blase entleeren und mögliche Auslöser prüfen."))
    }

    // MARK: Katheterbestand

    fun checkCatheterStock(context: Context, entries: List<ToiletEntry>, dateKey: String, stock: CatheterStock = CatheterStock.load(context)) {
        if (!stock.enabled) return
        val days = stock.daysRemaining(entries) ?: return
        if (days > stock.warnDays) return
        val count = stock.currentStock(entries)
        val empty = stock.estimatedEmptyDate(entries)
        val body = if (empty != null)
            trf("Noch {0} Katheter — reicht etwa bis {1}. Zeit fürs Rezept.", count, empty.format(DateTimeFormatter.ofPattern("d.M.")))
        else
            trf("Noch {0} Katheter. Zeit fürs Rezept.", count)
        notifyOnce(context, "cathLow_$dateKey", tr("Katheter werden knapp"), body)
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
            .setContentTitle(trf("💡 {0}", title))
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
            tr("Hinweise"),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = tr("Warnungen bei auffälligen Mengen oder Häufigkeiten")
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
