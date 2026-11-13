package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.UUID

private fun nowIso(): String = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

/**
 * Eine Kathetersorte (2.8, Parität zu iOS 4.11). Einträge referenzieren die Sorte
 * über ihren NAMEN (menschenlesbar in der CSV, robust bei Sorten-Löschung:
 * unbekannter Name → erste Sorte der Liste).
 */
@Serializable
data class CatheterSort(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "Sorte 1",
    /** Charrière-Größe; 0 = nicht angegeben. */
    val sizeCharriere: Int = 0,
    val material: String = "",
    val stockAtAdjustment: Int = 0,
    val adjustmentDate: String = nowIso()
) {
    /** „Ch 12 · PVC“ oder leer. */
    val specText: String
        get() = listOfNotNull(
            if (sizeCharriere > 0) "Ch $sizeCharriere" else null,
            material.trim().takeIf { it.isNotEmpty() }
        ).joinToString(" · ")
}

/** Ø Urinmenge einer Sorte (Statistik-Karte). */
data class SortVolume(val sort: CatheterSort, val avgMl: Int, val count: Int)

/**
 * Optionaler Katheterbestand (ISK) — Logik identisch zur iOS-Fassung:
 * Bestand + Korrekturzeitpunkt je Sorte, davon werden Blaseneinträge seither
 * abgezogen (selbstheilend, kein Decrement).
 */
@Serializable
data class CatheterStock(
    val enabled: Boolean = false,
    /** Alt-Daten (vor 2.8): Bestand ohne Sorten. Wird lesend als eine Sorte gezeigt. */
    val stockAtAdjustment: Int = 0,
    val adjustmentDate: String = nowIso(),
    val packSize: Int = 30,
    val warnDays: Int = 10,
    // 2.8 — kotlinx-Defaults halten Alt-Daten decoding-sicher.
    val sorts: List<CatheterSort> = emptyList(),
    /** Standardsorte; leer = erste Sorte. */
    val defaultSortId: String = "",
    /** Rezept läuft aus am (ISO-Datum); leer = keine Rezept-Erinnerung. */
    val prescriptionDate: String = ""
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "catheter_stock"
        const val LEGACY_SORT_ID = "legacy"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): CatheterStock {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return CatheterStock()
            return try { json.decodeFromString(data) } catch (_: Exception) { CatheterStock() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }

    // ---- Sorten ----

    /** Gültige Sortenliste. Alt-Daten (ohne sorts) erscheinen als EINE Sorte mit den Legacy-Werten. */
    val effectiveSorts: List<CatheterSort>
        get() = sorts.ifEmpty {
            listOf(CatheterSort(id = LEGACY_SORT_ID, name = "Sorte 1", stockAtAdjustment = stockAtAdjustment, adjustmentDate = adjustmentDate))
        }

    /** Migration festschreiben (vor jeder Änderung an der Liste). */
    fun ensureSorts(): CatheterStock = if (sorts.isEmpty()) copy(sorts = effectiveSorts) else this

    val defaultSort: CatheterSort
        get() = effectiveSorts.firstOrNull { it.id == defaultSortId } ?: effectiveSorts.first()

    /** Name der Standardsorte — wird bei jedem Blaseneintrag hinterlegt. null, wenn der Bestand aus ist. */
    val defaultSortName: String? get() = if (enabled) defaultSort.name else null

    /** Gehört ein Eintrag zu dieser Sorte? Ohne (oder mit unbekanntem) Sortennamen zählt er auf die erste Sorte. */
    fun belongs(entry: ToiletEntry, sort: CatheterSort): Boolean {
        val list = effectiveSorts
        val n = entry.catheterSort
        if (n.isNotEmpty() && list.any { it.name == n }) return n == sort.name
        return sort.id == list.first().id
    }

    private fun adjustmentOf(sort: CatheterSort): LocalDateTime =
        runCatching { LocalDateTime.parse(sort.adjustmentDate, DateTimeFormatter.ISO_LOCAL_DATE_TIME) }.getOrDefault(LocalDateTime.MIN)

    fun usedSince(entries: List<ToiletEntry>, sort: CatheterSort): Int {
        val adj = adjustmentOf(sort)
        return entries.count { it.urineMl > 0 && it.dateTime.isAfter(adj) && belongs(it, sort) }
    }

    fun stock(sort: CatheterSort, entries: List<ToiletEntry>): Int =
        maxOf(0, sort.stockAtAdjustment - usedSince(entries, sort))

    /** Gesamtbestand über alle Sorten. */
    fun currentStock(entries: List<ToiletEntry>): Int = effectiveSorts.sumOf { stock(it, entries) }

    /** Ø Katheterisierungen/Tag über ALLE Sorten, letzte 14 volle Tage, min. 3 Datentage. */
    fun dailyUsage(entries: List<ToiletEntry>): Double? {
        val today = LocalDate.now()
        val perDay = entries.filter { it.urineMl > 0 }.groupingBy { it.dateTime.toLocalDate() }.eachCount()
        val counts = (1..14).mapNotNull { i -> perDay[today.minusDays(i.toLong())] }
        if (counts.size < 3) return null
        return counts.sum().toDouble() / counts.size
    }

    /** Gesamtreichweite: Gesamtbestand ÷ Gesamt-Verbrauch/Tag. */
    fun daysRemaining(entries: List<ToiletEntry>): Int? {
        val usage = dailyUsage(entries) ?: return null
        if (usage <= 0) return null
        return (currentStock(entries) / usage).toInt()
    }

    fun estimatedEmptyDate(entries: List<ToiletEntry>): LocalDate? {
        val days = daysRemaining(entries) ?: return null
        return LocalDate.now().plusDays(days.toLong())
    }

    // ---- Änderungen (liefern eine neue Kopie; selbstheilendes Prinzip je Sorte) ----

    private fun mapSort(id: String, change: (CatheterSort) -> CatheterSort): CatheterStock {
        val base = ensureSorts()
        return base.copy(sorts = base.sorts.map { if (it.id == id) change(it) else it })
    }

    fun withStock(value: Int, sortId: String): CatheterStock =
        mapSort(sortId) { it.copy(stockAtAdjustment = maxOf(0, value), adjustmentDate = nowIso()) }

    fun withPackAdded(entries: List<ToiletEntry>, sortId: String): CatheterStock =
        withDelivery(packSize, entries, sortId)

    /** Lieferung zubuchen: aktueller Bestand + Stück wird die neue Korrektur. */
    fun withDelivery(pieces: Int, entries: List<ToiletEntry>, sortId: String): CatheterStock {
        val base = ensureSorts()
        val sort = base.sorts.firstOrNull { it.id == sortId } ?: return base
        return base.withStock(base.stock(sort, entries) + maxOf(0, pieces), sortId)
    }

    fun withSortUpdated(sort: CatheterSort): CatheterStock = mapSort(sort.id) { sort }

    /** Neue Sorte mit eindeutigem Namen „Sorte N“. */
    fun withSortAdded(): CatheterStock {
        val base = ensureSorts()
        var n = base.sorts.size + 1
        while (base.sorts.any { it.name == "Sorte $n" }) n++
        return base.copy(sorts = base.sorts + CatheterSort(name = "Sorte $n"))
    }

    /** Sorte entfernen (mindestens eine bleibt). Ihre Einträge zählen danach auf die erste Sorte. */
    fun withSortRemoved(sortId: String): CatheterStock {
        val base = ensureSorts()
        if (base.sorts.size <= 1) return base
        return base.copy(
            sorts = base.sorts.filter { it.id != sortId },
            defaultSortId = if (base.defaultSortId == sortId) "" else base.defaultSortId
        )
    }

    /** Name frei? (nicht leer, von keiner ANDEREN Sorte belegt) */
    fun isNameFree(name: String, sortId: String): Boolean =
        name.isNotBlank() && effectiveSorts.none { it.id != sortId && it.name == name.trim() }

    // ---- Rezept ----

    val prescriptionLocalDate: LocalDate?
        get() = runCatching { LocalDate.parse(prescriptionDate) }.getOrNull()

    /** Resttage bis zum Rezept-Ablauf (negativ = abgelaufen). null ohne Datum. */
    fun prescriptionDaysLeft(today: LocalDate = LocalDate.now()): Int? =
        prescriptionLocalDate?.let { ChronoUnit.DAYS.between(today, it).toInt() }

    // ---- Statistik ----

    /**
     * Ø Urinmenge je Kathetersorte. Zählt bewusst NUR Einträge, an denen die Sorte
     * ausdrücklich hinterlegt ist — nicht über belongs(), das Einträge ohne
     * Sortennamen der ersten Sorte zuschlägt und deren Schnitt verfälschen würde.
     */
    fun averageMlPerSort(entries: List<ToiletEntry>, since: LocalDate? = null, minCount: Int = 3): List<SortVolume> =
        effectiveSorts.mapNotNull { sort ->
            val mls = entries.filter {
                it.urineMl > 0 && it.catheterSort == sort.name &&
                    (since == null || !it.dateTime.toLocalDate().isBefore(since))
            }.map { it.urineMl }
            if (mls.size < minCount) null
            else SortVolume(sort, Math.round(mls.sum().toDouble() / mls.size).toInt(), mls.size)
        }
}
