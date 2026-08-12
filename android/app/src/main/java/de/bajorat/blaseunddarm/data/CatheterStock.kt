package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Optionaler Katheterbestand (ISK) — Logik identisch zur iOS-Fassung:
 * Bestand + Korrekturzeitpunkt, davon werden Blaseneinträge seither
 * abgezogen (selbstheilend, kein Decrement).
 */
@Serializable
data class CatheterStock(
    val enabled: Boolean = false,
    val stockAtAdjustment: Int = 0,
    val adjustmentDate: String = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
    val packSize: Int = 30,
    val warnDays: Int = 10
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "catheter_stock"
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

    private val adjustment: LocalDateTime
        get() = LocalDateTime.parse(adjustmentDate, DateTimeFormatter.ISO_LOCAL_DATE_TIME)

    fun usedSince(entries: List<ToiletEntry>): Int =
        entries.count { it.urineMl > 0 && it.dateTime.isAfter(adjustment) }

    fun currentStock(entries: List<ToiletEntry>): Int =
        maxOf(0, stockAtAdjustment - usedSince(entries))

    /** Ø Katheterisierungen/Tag über die letzten 14 vollen Tage, min. 3 Datentage. */
    fun dailyUsage(entries: List<ToiletEntry>): Double? {
        val today = LocalDate.now()
        val counts = (1..14).mapNotNull { i ->
            val day = today.minusDays(i.toLong())
            val n = entries.count { it.urineMl > 0 && it.dateTime.toLocalDate() == day }
            if (n > 0) n else null
        }
        if (counts.size < 3) return null
        return counts.sum().toDouble() / counts.size
    }

    fun daysRemaining(entries: List<ToiletEntry>): Int? {
        val usage = dailyUsage(entries) ?: return null
        if (usage <= 0) return null
        return (currentStock(entries) / usage).toInt()
    }

    fun estimatedEmptyDate(entries: List<ToiletEntry>): LocalDate? {
        val days = daysRemaining(entries) ?: return null
        return LocalDate.now().plusDays(days.toLong())
    }

    fun withStock(value: Int): CatheterStock = copy(
        stockAtAdjustment = maxOf(0, value),
        adjustmentDate = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
    )

    fun withPackAdded(entries: List<ToiletEntry>): CatheterStock =
        withStock(currentStock(entries) + packSize)
}
