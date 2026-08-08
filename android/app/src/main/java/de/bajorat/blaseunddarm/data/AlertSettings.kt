package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Einstellungen für den "Hinweise"-Reiter.
 * Bewusst EIGENER Prefs-Key (nicht AppSettings erweitern):
 * So bleibt das Decoding der bestehenden Einstellungen von
 * Bestandsnutzern beim Update unangetastet.
 * Defaults identisch zur iOS-Fassung.
 */
@Serializable
data class AlertSettings(
    // Einzelmenge (wichtigste Warnung — Überdehnungsrisiko)
    val singleOverEnabled: Boolean = true,
    val singleOverMl: Int = 450,

    // Tagesmenge
    val dayOverEnabled: Boolean = false,
    val dayOverMl: Int = 2500,
    val dayUnderEnabled: Boolean = false,
    val dayUnderMl: Int = 1000,

    // Häufigkeit (Toilettengänge pro Tag)
    val countOverEnabled: Boolean = false,
    val countOverLimit: Int = 10,
    val countUnderEnabled: Boolean = false,
    val countUnderLimit: Int = 4,

    // Persönliche Baseline (Ø der letzten 14 Tage)
    val baselineEnabled: Boolean = true,
    val baselineDeviationPercent: Int = 30
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "alert_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): AlertSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return AlertSettings()
            return try {
                json.decodeFromString(data)
            } catch (_: Exception) {
                AlertSettings()
            }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
