package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Optionale HWI-Frühwarnung — eigener Prefs-Key, identisch zur iOS-Fassung. */
@Serializable
data class UtiSettings(
    val enabled: Boolean = false
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "uti_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): UtiSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return UtiSettings()
            return try { json.decodeFromString(data) } catch (_: Exception) { UtiSettings() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
