package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Optionale Trinkmengen-Erfassung — eigener Prefs-Key, Defaults identisch zu iOS. */
@Serializable
data class DrinkSettings(
    val enabled: Boolean = false,
    val presets: List<Int> = listOf(150, 200, 300, 500)
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "drink_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): DrinkSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return DrinkSettings()
            return try { json.decodeFromString(data) } catch (_: Exception) { DrinkSettings() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
