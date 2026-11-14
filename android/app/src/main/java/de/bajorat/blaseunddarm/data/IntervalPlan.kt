package de.bajorat.blaseunddarm.data

import java.time.Duration
import java.time.LocalDateTime

/** Ein Tagesfenster mit der eigenen Füllrate und dem daraus abgeleiteten Abstand. */
data class DaytimeSlot(
    val id: Int,
    val startHour: Int,
    /** exklusiv; 24 = Mitternacht */
    val endHour: Int,
    /** 75. Perzentil der Füllrate (ml pro Stunde). */
    val rateMlPerHour: Int,
    val samples: Int,
    val suggestedMinutes: Int,
    /** Abstände in diesem Fenster, deren Menge über der Zielmenge lag. */
    val overTarget: Int,
    /** true, wenn das Fenster zu wenige eigene Abstände hatte (Tages-Füllrate als Ersatz). */
    val usesFallback: Boolean
) {
    /** Deutscher Schlüssel — die Oberfläche übersetzt per tr(). */
    val label: String get() = IntervalPlanner.slotName(id)
    val rangeText: String get() = "%02d–%02d".format(startHour, endHour)
}

/** Vorschlag „Abstände nach Tageszeit“ — rein beschreibend aus den eigenen Einträgen. */
data class IntervalPlan(
    val targetMl: Int,
    val slots: List<DaytimeSlot>,
    /** Vorgeschlagene feste Erinnerungszeiten (Minuten seit Mitternacht). */
    val times: List<Int>,
    val wakeMinutes: Int,
    val bedMinutes: Int,
    val volumes: Int,
    val overTarget: Int,
    val morningMedianMl: Int?,
    val morningSamples: Int,
    val morningOverTarget: Int
)

/** Statistik-Karte „Zielmenge eingehalten“. */
data class TargetStats(val target: Int, val total: Int, val over: Int, val pct: Int, val worstSlot: Int?, val worstCount: Int)

/** Port von iOS SuggestionEngine.intervalPlan (4.20). */
object IntervalPlanner {
    /** Anteil der Entleerungen bis zur Zielmenge; null unter 5 Entleerungen. */
    fun targetStats(entries: List<ToiletEntry>, target: Int): TargetStats? {
        val voids = entries.filter { it.urineMl > 0 }
        if (voids.size < 5) return null
        val over = voids.filter { it.urineMl > target }
        val perSlot = IntArray(slotBounds.size)
        for (e in over) { val t = e.dateTime; perSlot[slotIndex(t.hour * 60 + t.minute)] += 1 }
        val worst = perSlot.indices.maxByOrNull { perSlot[it] }
        return TargetStats(target, voids.size, over.size,
            Math.round((voids.size - over.size).toDouble() / voids.size * 100).toInt(),
            worst, worst?.let { perSlot[it] } ?: 0)
    }

    const val DEFAULT_TARGET_ML = 400
    /** Tagesfenster: Morgens, Mittags, Nachmittags, Abends. */
    val slotBounds: List<Pair<Int, Int>> = listOf(5 to 11, 11 to 15, 15 to 19, 19 to 24)
    /** Längster Abstand, der noch als Tagesabstand zählt (darüber = Nachtpause). */
    const val MAX_DAY_GAP = 360
    const val MIN_NIGHT_GAP = 300
    /** Höchstens so viele Erinnerungen am Tag; darüber werden die Abstände leicht gestreckt. */
    const val MAX_TIMES_PER_DAY = 8

    fun slotName(id: Int): String = when (id) {
        0 -> "Morgens"
        1 -> "Mittags"
        2 -> "Nachmittags"
        else -> "Abends"
    }

    fun slotIndex(minute: Int): Int {
        val h = (minute / 60) % 24
        if (h < slotBounds[0].first) return 0
        val i = slotBounds.indexOfFirst { h >= it.first && h < it.second }
        return if (i >= 0) i else slotBounds.size - 1
    }

    private fun roundTo(value: Int, step: Int): Int = ((value + step / 2) / step) * step
    private fun percentile(sorted: List<Double>, p: Double): Double =
        if (sorted.isEmpty()) 0.0 else sorted[minOf(sorted.size - 1, (sorted.size * p).toInt())]
    private fun median(v: List<Int>): Int = v.sorted()[v.size / 2]

    /**
     * null bei zu wenig Daten (unter 7 Tagen mit Urin-Einträgen im Zeitraum oder unter
     * 20 Tagesabständen). days = Betrachtungszeitraum (Vorschlag 30, lernender Grundplan 14).
     */
    fun intervalPlan(entries: List<ToiletEntry>, targetMl: Int, now: LocalDateTime = LocalDateTime.now(), days: Int = 30): IntervalPlan? {
        val start = now.toLocalDate().atStartOfDay().minusDays(days.toLong())

        // Urin-Einträge; Doppel innerhalb von 10 Minuten = eine Entleerung
        val pts = mutableListOf<Pair<LocalDateTime, Int>>()
        val sorted = entries.filter { it.urineMl > 0 }.map { it.dateTime to it.urineMl }
            .filter { !it.first.isBefore(start) && !it.first.isAfter(now) }.sortedBy { it.first }
        for ((t, ml) in sorted) {
            val last = pts.lastOrNull()
            if (last != null && Duration.between(last.first, t).seconds < 600) {
                pts[pts.size - 1] = t to maxOf(last.second, ml)
            } else {
                pts.add(t to ml)
            }
        }
        if (pts.map { it.first.toLocalDate() }.distinct().size < 7) return null

        fun minuteOfDay(d: LocalDateTime) = d.hour * 60 + d.minute

        val slotRates = List(slotBounds.size) { mutableListOf<Double>() }
        val slotOver = IntArray(slotBounds.size)
        val morningMl = mutableListOf<Int>()
        val wakes = mutableListOf<Int>()
        val beds = mutableListOf<Int>()

        for (i in 1 until pts.size) {
            val a = pts[i - 1]
            val b = pts[i]
            val gap = Duration.between(a.first, b.first).toMinutes().toInt()
            val aMin = minuteOfDay(a.first)
            if (gap >= MIN_NIGHT_GAP && b.first.hour in 4..11) {
                // Nachtpause: a = letzte vor dem Schlafen, b = erste am Morgen
                morningMl.add(b.second)
                wakes.add(minuteOfDay(b.first))
                beds.add(if (aMin < 4 * 60) aMin + 1440 else aMin)
                continue
            }
            if (gap !in 20..MAX_DAY_GAP || aMin < slotBounds[0].first * 60) continue
            // Der Abstand zählt für das Fenster, in dem seine Mitte liegt.
            val idx = slotIndex(minOf(aMin + gap / 2, 1439))
            slotRates[idx].add(b.second.toDouble() / gap * 60)
            if (b.second > targetMl) slotOver[idx] += 1
        }

        val allRates = slotRates.flatten().sorted()
        if (allRates.size < 20) return null
        val pooledP75 = percentile(allRates, 0.75)

        fun minutesFor(rate: Double): Int {
            if (rate <= 0) return 240
            return minOf(240, maxOf(60, roundTo((targetMl * 60 / rate).toInt(), 15)))
        }

        val rates = DoubleArray(slotBounds.size)
        val slots = slotBounds.mapIndexed { i, b ->
            val r = slotRates[i].sorted()
            val fallback = r.size < 8
            val rate = if (fallback) pooledP75 else percentile(r, 0.75)
            rates[i] = rate
            DaytimeSlot(i, b.first, b.second, Math.round(rate).toInt(), r.size, minutesFor(rate), slotOver[i], fallback)
        }

        // Tagesrahmen aus den eigenen Gewohnheiten (Median, auf 15 min)
        val wake = if (wakes.size >= 5) roundTo(median(wakes), 15) else 7 * 60
        var bed = if (beds.size >= 5) roundTo(median(beds), 15) else 22 * 60
        bed = minOf(bed, 1425)
        if (bed <= wake + 120) return null

        // Minuten ab t, bis target ml zusammenkommen — über die Fenstergrenzen hinweg
        // gerechnet (60…240 min, auf 15 min). Port von iOS.
        fun step(t: Int, target: Double): Int {
            var ml = 0.0
            var cur = t.toDouble()
            while (true) {
                val idx = slotIndex(cur.toInt())
                val rate = rates[idx]
                if (rate <= 0) { cur = (t + 240).toDouble(); break }
                val end = (slotBounds[idx].second * 60).toDouble()
                val need = (target - ml) / rate * 60
                if (end >= 1440 || cur + need <= end) { cur += need; break }
                ml += (end - cur) * rate / 60
                cur = end
            }
            return minOf(240, maxOf(60, roundTo(cur.toInt() - t, 15)))
        }
        fun build(target: Double): List<Int> {
            val out = mutableListOf(wake)
            var t = wake
            while (out.size < 16) {
                val next = t + step(t, target)
                if (next > bed) break
                out.add(next)
                t = next
            }
            if (bed - out.last() >= 75 && bed < 1440) out.add(bed)
            return out
        }
        // Höchstens MAX_TIMES_PER_DAY Erinnerungen: sonst in 5-%-Schritten strecken.
        var effTarget = targetMl.toDouble()
        var times = build(effTarget)
        var rounds = 0
        while (times.size > MAX_TIMES_PER_DAY && rounds < 5) {
            effTarget *= 1.05
            times = build(effTarget)
            rounds += 1
        }

        val vols = pts.map { it.second }
        return IntervalPlan(
            targetMl = targetMl,
            slots = slots,
            times = times,
            wakeMinutes = wake,
            bedMinutes = bed,
            volumes = vols.size,
            overTarget = vols.count { it > targetMl },
            morningMedianMl = if (morningMl.size >= 5) median(morningMl) else null,
            morningSamples = morningMl.size,
            morningOverTarget = morningMl.count { it > targetMl }
        )
    }
}
