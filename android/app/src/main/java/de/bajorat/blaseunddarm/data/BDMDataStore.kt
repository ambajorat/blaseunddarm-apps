package de.bajorat.blaseunddarm.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime

class BDMDataStore(private val context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("bb_data", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    private val _entries = MutableStateFlow<List<ToiletEntry>>(emptyList())
    val entries: StateFlow<List<ToiletEntry>> = _entries

    private val _settings = MutableStateFlow(AppSettings())
    val settings: StateFlow<AppSettings> = _settings

    init {
        loadEntries()
        loadSettings()
    }

    fun addEntry(entry: ToiletEntry) {
        _entries.value = listOf(entry) + _entries.value
        saveEntries()
        AlertEngine.checkEntry(context, entry)
        AlertEngine.checkDay(context, _entries.value)
    }

    fun updateEntry(entry: ToiletEntry) {
        _entries.value = _entries.value.map { if (it.id == entry.id) entry else it }
            .sortedByDescending { it.timestamp }
        saveEntries()
    }

    fun deleteEntry(entry: ToiletEntry) {
        _entries.value = _entries.value.filter { it.id != entry.id }
        saveEntries()
    }

    fun restoreEntries(entries: List<ToiletEntry>) {
        _entries.value = (entries + _entries.value)
            .distinctBy { it.id }
            .sortedByDescending { it.timestamp }
        saveEntries()
    }

    fun deleteAll() {
        _entries.value = emptyList()
        saveEntries()
    }

    fun updateSettings(settings: AppSettings) {
        _settings.value = settings
        saveSettings()
    }

    val todayEntries: List<ToiletEntry>
        get() {
            val today = LocalDate.now()
            return _entries.value.filter { it.dateTime.toLocalDate() == today }
        }

    val todayMl: Int get() = todayEntries.sumOf { it.urineMl }
    val todayDrink: Int get() = todayEntries.sumOf { it.drinkMl }
    val todayBowel: Int get() = todayEntries.count { it.bowel }
    val todayCount: Int get() = todayEntries.size
    val lastEntry: ToiletEntry? get() = _entries.value.firstOrNull()

    private fun saveEntries() {
        val data = json.encodeToString(_entries.value)
        prefs.edit().putString("entries", data).apply()
    }

    private fun loadEntries() {
        val data = prefs.getString("entries", null) ?: return
        try {
            _entries.value = json.decodeFromString<List<ToiletEntry>>(data)
                .sortedByDescending { it.timestamp }
        } catch (_: Exception) {}
    }

    private fun saveSettings() {
        val data = json.encodeToString(_settings.value)
        prefs.edit().putString("settings", data).apply()
    }

    private fun loadSettings() {
        val data = prefs.getString("settings", null) ?: return
        try {
            _settings.value = json.decodeFromString(data)
        } catch (_: Exception) {}
    }
}
