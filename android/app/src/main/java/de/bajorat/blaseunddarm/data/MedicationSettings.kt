package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID

/** Ein Medikament mit optionalen festen Einnahmezeiten (Minuten seit
 *  Mitternacht). Leere Zeiten = Bedarfsmedikament (nur Doku). */
@Serializable
data class Medication(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val times: List<Int> = emptyList(),
    val remindersEnabled: Boolean = true
)

/** Viertes Zusatzmodul — eigener Prefs-Key, iOS-Parität (bb_medication_settings). */
@Serializable
data class MedicationSettings(
    val enabled: Boolean = false,
    val medications: List<Medication> = emptyList()
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "medication_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): MedicationSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return MedicationSettings()
            return try { json.decodeFromString(data) } catch (_: Exception) { MedicationSettings() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
