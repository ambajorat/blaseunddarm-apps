package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Optionale vegetative Zeichen (AD) samt Blutdruckfeld — identisch zur iOS-Fassung. */
@Serializable
data class AdSettings(
    val enabled: Boolean = false,
    val bpEnabled: Boolean = false
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "ad_settings"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): AdSettings {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return AdSettings()
            return try { json.decodeFromString(data) } catch (_: Exception) { AdSettings() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }
}
