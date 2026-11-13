package de.bajorat.blaseunddarm.data

import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Wecker-Modus (2.10) — Port der iOS-Logik aus AppSettings (4.13–4.20):
 * Grundplan lückenfrei halten, an den Entleerungen des Tages ausrichten,
 * Fälligkeit, lernender Grundplan. Reines Kotlin, ohne Android.
 * Zeiten sind Minuten seit Mitternacht.
 */
object FixedPlan {

    /** Größter Abstand im Grundplan, der ohne Zwischenzeit bleibt (4 Stunden). */
    const val MAX_GAP = 240

    data class Gap(val from: Int, val to: Int, val suggestion: Int)

    /** Größte Lücke über maxGap samt Vorschlag (Mitte, auf 15 Minuten). null = kein Handlungsbedarf. */
    fun fixedTemplateGap(times: List<Int>, maxGap: Int = MAX_GAP): Gap? {
        val s = times.distinct().sorted()
        var best: Pair<Int, Int>? = null
        for (i in 1 until s.size) {
            val a = s[i - 1]
            val b = s[i]
            val bestSpan = best?.let { it.second - it.first } ?: 0
            if (b - a > maxGap && b - a > bestSpan) best = a to b
        }
        val g = best ?: return null
        var m = Math.round((g.first + (g.second - g.first) / 2) / 15.0).toInt() * 15
        if (s.contains(m)) m += 15
        return Gap(g.first, g.second, m)
    }

    /** Grundplan ohne Lücken über maxGap: zu große Abstände werden geteilt. Idempotent. */
    fun filledFixedTimes(times: List<Int>, maxGap: Int = MAX_GAP): List<Int> {
        var s = times.distinct().sorted()
        var rounds = 0
        while (rounds < 32) {
            val g = fixedTemplateGap(s, maxGap) ?: break
            s = (s + g.suggestion).distinct().sorted()
            rounds++
        }
        return s
    }

    /**
     * Lernender Grundplan — Leitplanken gegen „Zittern“: Bei gleicher Anzahl Zeiten wird jede
     * Zeit nur übernommen, wenn sie sich um mindestens minShift Minuten unterscheidet; ändert
     * sich die Anzahl, gilt der Vorschlag ganz. null = keine lohnende Änderung.
     */
    fun learnedTemplate(current: List<Int>, proposed: List<Int>, minShift: Int = 15): List<Int>? {
        val cur = current.distinct().sorted()
        val prop = filledFixedTimes(proposed)
        if (prop.isEmpty()) return null
        if (prop.size != cur.size || cur.isEmpty()) return if (prop == cur) null else prop
        val out = cur.toMutableList()
        for (i in cur.indices) if (kotlin.math.abs(prop[i] - cur[i]) >= minShift) out[i] = prop[i]
        val filled = filledFixedTimes(out)
        return if (filled == cur) null else filled
    }

    /** Grundplan so verschieben, dass seine erste Zeit auf firstVoidMinute fällt. */
    fun shiftedTimes(template: List<Int>, firstVoidMinute: Int, keepPastMidnight: Boolean = false): List<Int> {
        val base = template.minOrNull() ?: return emptyList()
        val delta = firstVoidMinute - base
        return template.map { it + delta }.filter { it >= 0 && (keepPastMidnight || it < 1440) }.distinct().sorted()
    }

    private fun minuteOf(d: LocalDateTime): Int = d.hour * 60 + d.minute

    /**
     * Erste Entleerung des heutigen Morgens (= Aufwachen): erster Urin-Eintrag heute im
     * Morgenfenster bis 12 Uhr nach der Nacht. Fenster ab 04 Uhr, mit Aufwachzeit erst ab
     * 2,5 Std davor — eine Nacht-Entleerung um 04:31 bei Aufwachzeit 08:15 ist KEIN Aufwachen.
     * Nach der Nacht = ≥ 5 Std Pause ODER die Entleerung davor lag vor dem Fenster.
     */
    fun firstMorningVoid(entries: List<ToiletEntry>, now: LocalDateTime, wakeMinute: Int? = null): LocalDateTime? {
        val urine = entries.filter { it.urineMl > 0 }.map { it.dateTime }.filter { !it.isAfter(now) }.sorted()
        val today = now.toLocalDate().atStartOfDay()
        val windowStart = maxOf(240, (wakeMinute ?: 240) - 150)
        val windowStartDate = today.plusMinutes(windowStart.toLong())
        for ((i, t) in urine.withIndex()) {
            if (t.isBefore(windowStartDate)) continue
            if (t.hour >= 12) break
            if (i == 0 || Duration.between(urine[i - 1], t).toMinutes() >= 300 || urine[i - 1].isBefore(windowStartDate)) return t
        }
        return null
    }

    /**
     * Restplan ab einer Entleerung um e neu takten: Die Entleerung ersetzt die NÄCHSTGELEGENE
     * geplante Zeit, alle Zeiten danach rücken um dieselbe Differenz mit. `protected` =
     * Minuten echter Entleerungen von heute — die werden nie ersetzt.
     */
    fun rechainedTimes(times: List<Int>, e: Int, keepPastMidnight: Boolean = false, protected: Set<Int> = emptySet()): List<Int> {
        val s = times.distinct().sorted()
        val j = s.indexOfFirst { it > e }
        if (j < 0) return s
        val k = if (j > 0 && !protected.contains(s[j - 1]) && e - s[j - 1] <= s[j] - e) j - 1 else j
        val delta = e - s[k]
        if (delta == 0) return s
        val out = s.subList(0, k) + e + s.subList(k + 1, s.size).map { it + delta }.filter { keepPastMidnight || it < 1440 }
        return out.distinct().sorted()
    }

    /**
     * Richtet fixedTimes an den Entleerungen des Tages aus: erst den ganzen Grundplan auf die
     * erste Morgen-Entleerung, dann jede weitere Entleerung der Reihe nach. Der Tagesplan wird
     * bei jedem Aufruf komplett aus dem Grundplan neu berechnet; Zeiten nach Mitternacht bleiben
     * zwischenzeitlich erhalten. Tagesende-Anker = letzte Grundplanzeit.
     * null = nichts geändert, sonst die neuen Einstellungen (Erinnerungen neu planen).
     */
    fun alignFixedTimes(settings: AppSettings, entries: List<ToiletEntry>, now: LocalDateTime): AppSettings? {
        if (!settings.anchorToFirstVoid || !settings.useFixedTimes) return null
        val template = settings.fixedTemplate
        if (template.isEmpty()) return null
        val key = now.toLocalDate().toString()
        val first = firstMorningVoid(entries, now, template.first()) ?: return null
        var plan = shiftedTimes(template, minuteOf(first), keepPastMidnight = true)
        if (plan.isEmpty()) return null

        val voids = entries.filter { it.urineMl > 0 }.map { it.dateTime }
            .filter { it.isAfter(first) && !it.isAfter(now) }.sorted()
        val done = mutableSetOf(minuteOf(first))
        for (v in voids) {
            val firstTime = plan.firstOrNull() ?: continue
            if (minuteOf(v) < firstTime) continue
            plan = rechainedTimes(plan, minuteOf(v), keepPastMidnight = true, protected = done)
            done.add(minuteOf(v))
        }
        val lastTemplate = template.maxOrNull() ?: 1439
        var base = plan.map { minOf(it, lastTemplate) }.distinct().sorted()
        val last = base.lastOrNull()
        if (last != null && last < lastTemplate - 90) {
            val lastVoid = done.maxOrNull() ?: 0
            val tail = filledFixedTimes(base.filter { it >= lastVoid } + lastTemplate)
            base = (base.filter { it < lastVoid } + tail).distinct().sorted()
        }
        if (base.isEmpty()) return null

        var out = settings
        var changed = false
        if (out.anchorDayKey != key) { out = out.copy(anchorDayKey = key); changed = true }
        if (base != out.sortedFixedTimes) { out = out.copy(fixedTimes = base); changed = true }
        return if (changed) out else null
    }

    /** Die HEUTE gültigen Zeiten. Bei Ausrichtung gilt bis zur ersten Morgen-Entleerung der Grundplan. */
    fun effectiveFixedTimes(settings: AppSettings, today: LocalDate): List<Int> {
        if (!settings.anchorToFirstVoid) return settings.sortedFixedTimes
        return if (settings.anchorDayKey == today.toString()) settings.sortedFixedTimes else settings.fixedTemplate
    }

    /**
     * Fälligkeit im Wecker-Modus: die erste geplante Zeit NACH der letzten Entleerung (heute).
     * Liegt sie vor now, ist die Erinnerung überfällig. Letzte Entleerung vor heute → erste Zeit
     * des heutigen Plans. Nach der letzten Zeit des Tages → erste Grundplanzeit morgen.
     */
    fun fixedDue(settings: AppSettings, lastVoid: LocalDateTime?, now: LocalDateTime): LocalDateTime? {
        val today = now.toLocalDate()
        val times = effectiveFixedTimes(settings, today)
        if (times.isEmpty()) return null
        if (lastVoid != null && !lastVoid.toLocalDate().isBefore(today)) {
            val m = minuteOf(lastVoid)
            val next = times.firstOrNull { it > m }
            if (next != null) return today.atTime(next / 60, next % 60)
            val first = settings.fixedTemplate.firstOrNull() ?: times.first()
            return today.plusDays(1).atTime(first / 60, first % 60)
        }
        return today.atTime(times[0] / 60, times[0] % 60)
    }

    /** Nächster Alarmzeitpunkt nach now: heute die nächste gültige Zeit, sonst die erste Grundplanzeit morgen. */
    fun nextTrigger(settings: AppSettings, now: LocalDateTime): LocalDateTime? {
        val today = now.toLocalDate()
        val times = effectiveFixedTimes(settings, today)
        if (times.isEmpty()) return null
        val nowMin = minuteOf(now)
        val next = times.firstOrNull { it > nowMin }
        if (next != null) return today.atTime(next / 60, next % 60)
        val first = settings.fixedTemplate.firstOrNull() ?: times.first()
        return today.plusDays(1).atTime(first / 60, first % 60)
    }

    fun clock(minutes: Int): String = "%02d:%02d".format((minutes / 60) % 24, minutes % 60)
}
