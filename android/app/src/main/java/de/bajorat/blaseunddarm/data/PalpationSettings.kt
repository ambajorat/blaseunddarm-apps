package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Optionaler Tastbefund (ISK) — identisch zur iOS-Fassung. */
@Serializable
data class PalpationSettings(
    val enabled: Boolean = false
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "palpation_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): PalpationSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return PalpationSettings()
            return try { json.decodeFromString(data) } catch (_: Exception) { PalpationSettings() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
