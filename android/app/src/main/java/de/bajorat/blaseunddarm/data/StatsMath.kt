package de.bajorat.blaseunddarm.data

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters

/**
 * Statistik-Rechenlogik (2.7) — Parität zu iOS 4.22:
 * Verdichtung der Diagramme (Tag/Woche/Monat), Trendlinie, Menge nach Tageszeit, Darm-Karte.
 * Bewusst ohne Android-Abhängigkeiten, damit die Logik für sich prüfbar bleibt.
 */
enum class StatsGranularity { DAY, WEEK, MONTH }

/** Ein Balken: ein Tag, eine Woche oder ein Monat. Bei Woche/Monat Ø pro Tag MIT Einträgen. */
data class StatsBucket(
    val start: LocalDate,
    val lengthDays: Int,
    val activeDays: Int,
    val avgMl: Double,
    val avgVisits: Double,
    val avgBowel: Double
) {
    /** Mitte des Abschnitts in Epochentagen — Stützpunkt der Trendlinie. */
    val mid: Double get() = start.toEpochDay() + lengthDays / 2.0
}

/** Ausgleichsgerade (kleinste Quadrate) über die Abschnitte mit Einträgen. */
data class StatsTrendLine(
    val startX: Double,
    val endX: Double,
    val startValue: Double,
    val endValue: Double
) {
    /** Veränderung vom Anfang zum Ende in Prozent; null, wenn der Anfangswert 0 ist. */
    val changePercent: Int?
        get() = if (startValue > 0) Math.round((endValue - startValue) / startValue * 100).toInt() else null
}

/** 3-Stunden-Block des Tages (0 = 00–03 … 7 = 21–24) mit Ø Urinmenge je Entleerung. */
data class VolumeBlock(val index: Int, val avgMl: Int, val count: Int) {
    val rangeText: String get() = "%02d–%02d".format(index * 3, index * 3 + 3)

    /** Deutscher Schlüssel — die Oberfläche übersetzt per tr(). */
    val label: String
        get() = when (index) {
            0 -> "Nachts"
            1 -> "Frühmorgens"
            2 -> "Morgens"
            3 -> "Vormittags"
            4 -> "Mittags"
            5 -> "Nachmittags"
            6 -> "Abends"
            else -> "Spätabends"
        }
}

data class BowelStats(
    val count: Int,
    /** Stuhlgänge pro Tag mit Stuhlgang. */
    val perDay: Double,
    /** Ø Abstand in Tagen zwischen Tagen mit Stuhlgang; null bei nur einem Tag. */
    val avgGapDays: Double?,
    val lastAgoDays: Int,
    val lastAgoHours: Int,
    val typed: Int,
    val hard: Int,
    val ok: Int,
    val loose: Int
)

object StatsMath {

    /** Bis 45 Tage Tageswerte, bis 180 Tage Wochen, darüber Monate. */
    fun granularity(days: Int): StatsGranularity = when {
        days <= 45 -> StatsGranularity.DAY
        days <= 180 -> StatsGranularity.WEEK
        else -> StatsGranularity.MONTH
    }

    /** Echter Toilettengang (Urin oder Stuhl) — reine Trink-/Medikamenten-Einträge zählen nicht. */
    private fun isVisit(e: ToiletEntry): Boolean = e.urineMl > 0 || e.bowel

    fun buckets(
        entries: List<ToiletEntry>,
        days: Int,
        granularity: StatsGranularity,
        today: LocalDate = LocalDate.now()
    ): List<StatsBucket> {
        val first = today.minusDays(days - 1L)
        val perDay: Map<LocalDate, List<ToiletEntry>> = entries
            .filter { isVisit(it) }
            .groupBy { it.dateTime.toLocalDate() }
            .filterKeys { !it.isBefore(first) && !it.isAfter(today) }

        fun make(start: LocalDate, length: Int, dates: List<LocalDate>): StatsBucket {
            val active = dates.filter { perDay.containsKey(it) }
            val n = maxOf(active.size, 1).toDouble()
            val es = active.flatMap { perDay[it].orEmpty() }
            return StatsBucket(
                start = start,
                lengthDays = length,
                activeDays = active.size,
                avgMl = es.sumOf { it.urineMl } / n,
                avgVisits = es.size / n,
                avgBowel = es.count { it.bowel } / n
            )
        }

        return when (granularity) {
            // Jeder Tag bleibt ein Balken (auch leere Tage).
            StatsGranularity.DAY -> (0 until days).map { first.plusDays(it.toLong()) }.map { make(it, 1, listOf(it)) }
            StatsGranularity.WEEK -> perDay.keys
                .groupBy { it.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)) }
                .map { (start, dates) -> make(start, 7, dates) }
                .sortedBy { it.start }
            StatsGranularity.MONTH -> perDay.keys
                .groupBy { it.withDayOfMonth(1) }
                .map { (start, dates) -> make(start, start.lengthOfMonth(), dates) }
                .sortedBy { it.start }
        }
    }

    /** null bei weniger als 3 Abschnitten mit Einträgen. Werte werden bei 0 gekappt. */
    fun trend(buckets: List<StatsBucket>, value: (StatsBucket) -> Double): StatsTrendLine? {
        val pts = buckets.filter { it.activeDays > 0 }
        if (pts.size < 3) return null
        val x0 = pts.first().mid
        val xs = pts.map { it.mid - x0 }
        val ys = pts.map(value)
        val mx = xs.average()
        val my = ys.average()
        var sxx = 0.0
        var sxy = 0.0
        for (i in pts.indices) {
            sxx += (xs[i] - mx) * (xs[i] - mx)
            sxy += (xs[i] - mx) * (ys[i] - my)
        }
        if (sxx <= 0.0) return null
        val slope = sxy / sxx
        val intercept = my - slope * mx
        return StatsTrendLine(
            startX = pts.first().mid,
            endX = pts.last().mid,
            startValue = maxOf(0.0, intercept),
            endValue = maxOf(0.0, intercept + slope * xs.last())
        )
    }

    /** Ø Urinmenge je Entleerung in 3-Stunden-Blöcken; Blöcke unter minCount Einträgen fehlen. */
    fun volumeBlocks(entries: List<ToiletEntry>, since: LocalDate? = null, minCount: Int = 3): List<VolumeBlock> {
        val bucketsMl = List(8) { mutableListOf<Int>() }
        for (e in entries) {
            if (e.urineMl <= 0) continue
            val dt = e.dateTime
            if (since != null && dt.toLocalDate().isBefore(since)) continue
            bucketsMl[(dt.hour / 3).coerceIn(0, 7)].add(e.urineMl)
        }
        return bucketsMl.mapIndexedNotNull { i, mls ->
            if (mls.size < minCount) null
            else VolumeBlock(i, Math.round(mls.sum().toDouble() / mls.size).toInt(), mls.size)
        }
    }

    /** Darm-Karte: Frequenz, Abstand, letzter Stuhlgang, Bristol-Bänder. null ohne Stuhlgang im Zeitraum. */
    fun bowelStats(entries: List<ToiletEntry>, days: Int, now: LocalDateTime = LocalDateTime.now()): BowelStats? {
        val today = now.toLocalDate()
        val first = today.minusDays(days - 1L)
        val bowel = entries.filter { it.bowel }
            .map { it to it.dateTime }
            .filter { !it.second.toLocalDate().isBefore(first) && !it.second.isAfter(now) }
            .sortedBy { it.second }
        if (bowel.isEmpty()) return null
        val uniqueDays = bowel.map { it.second.toLocalDate() }.distinct().sorted()
        val gaps = uniqueDays.zipWithNext { a, b -> ChronoUnit.DAYS.between(a, b).toInt() }
        val last = bowel.last().second
        val typedTypes = bowel.mapNotNull { (e, _) ->
            runCatching { BristolType.valueOf(e.bristolType) }.getOrNull()?.takeIf { it != BristolType.NONE }
        }
        return BowelStats(
            count = bowel.size,
            perDay = bowel.size.toDouble() / uniqueDays.size,
            avgGapDays = if (gaps.isEmpty()) null else gaps.average(),
            lastAgoDays = ChronoUnit.DAYS.between(uniqueDays.last(), today).toInt(),
            lastAgoHours = maxOf(1, ChronoUnit.HOURS.between(last, now).toInt()),
            typed = typedTypes.size,
            hard = typedTypes.count { it == BristolType.TYPE1 || it == BristolType.TYPE2 },
            ok = typedTypes.count { it == BristolType.TYPE3 || it == BristolType.TYPE4 || it == BristolType.TYPE5 },
            loose = typedTypes.count { it == BristolType.TYPE6 || it == BristolType.TYPE7 }
        )
    }
}
