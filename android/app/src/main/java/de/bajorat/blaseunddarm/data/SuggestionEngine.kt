package de.bajorat.blaseunddarm.data

import java.time.LocalDate

/**
 * Vorschläge aus den EIGENEN Daten der letzten 30 Tage — 1:1 zur iOS-Fassung.
 * Rein beschreibende Statistik; nichts wird automatisch übernommen.
 */
data class Suggestions(
    val singleOverMl: Int? = null,
    val singleCapped: Boolean = false,
    val dayOverMl: Int? = null,
    val dayUnderMl: Int? = null,
    val countOver: Int? = null,
    val countUnder: Int? = null,
    val intervalMinutes: Int? = null
) {
    val isEmpty: Boolean
        get() = singleOverMl == null && dayOverMl == null && dayUnderMl == null
                && countOver == null && countUnder == null && intervalMinutes == null
}

object SuggestionEngine {

    const val SINGLE_CAP = 500

    fun compute(entries: List<ToiletEntry>): Suggestions? {
        val start = LocalDate.now().minusDays(30)
        val recent = entries.filter { it.dateTime.toLocalDate().isAfter(start) }
        val byDay = recent.groupBy { it.dateTime.toLocalDate() }
        val daysWithUrine = byDay.filterValues { list -> list.any { it.urineMl > 0 } }
        if (daysWithUrine.size < 7) return null

        var singleOver: Int? = null
        var capped = false
        val singles = recent.map { it.urineMl }.filter { it > 0 }.sorted()
        if (singles.size >= 20) {
            val p95 = singles[minOf(singles.size - 1, (singles.size * 0.95).toInt())]
            val rounded = roundTo(p95, 25)
            if (rounded > SINGLE_CAP) { singleOver = SINGLE_CAP; capped = true }
            else if (rounded >= 200) singleOver = rounded
        }

        val totals = daysWithUrine.values.map { list -> list.sumOf { it.urineMl } }
        val avgTotal = totals.sum() / totals.size
        val dayOver = if (avgTotal > 0) roundTo((avgTotal * 1.2).toInt(), 50) else null
        val dayUnder = if (avgTotal > 0) roundTo((avgTotal * 0.8).toInt(), 50) else null

        val counts = daysWithUrine.values.map { list -> list.count { it.urineMl > 0 } }
        val avgCount = counts.sum().toDouble() / counts.size
        val countOver = maxOf(Math.round(avgCount).toInt() + 2, Math.round(avgCount * 1.3).toInt())
        val countUnder = maxOf(1, minOf(Math.round(avgCount).toInt() - 2, Math.round(avgCount * 0.7).toInt()))

        val gaps = mutableListOf<Int>()
        for ((_, dayEntries) in daysWithUrine) {
            val times = dayEntries.filter { it.urineMl > 0 }.map { it.dateTime }.sorted()
            for (i in 1 until times.size) {
                val m = java.time.Duration.between(times[i - 1], times[i]).toMinutes().toInt()
                if (m in 30..480) gaps.add(m)
            }
        }
        val interval = if (gaps.size >= 10) {
            val median = gaps.sorted()[gaps.size / 2]
            minOf(240, maxOf(60, roundTo(median, 30)))
        } else null

        return Suggestions(singleOver, capped, dayOver, dayUnder, countOver, countUnder, interval)
    }

    private fun roundTo(value: Int, step: Int): Int = ((value + step / 2) / step) * step
}
