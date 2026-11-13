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
        // Feste Zeiten ggf. an den Entleerungen ausrichten (2.10)
        if (entry.urineMl > 0) alignFixedTimesIfNeeded()
    }

    // ---- Wecker-Modus (2.10, Parität zu iOS 4.13–4.20) ----

    /**
     * Richtet die festen Zeiten an den heutigen Entleerungen aus (idempotent) und heilt
     * einmalig Lücken über 4 Stunden im Grundplan. true = Zeiten geändert → Erinnerungen neu planen.
     */
    fun alignFixedTimesIfNeeded(now: LocalDateTime = LocalDateTime.now()): Boolean {
        val s = _settings.value
        if (s.useFixedTimes) {
            val healed = FixedPlan.filledFixedTimes(s.fixedTemplate)
            if (healed != s.fixedTemplate) {
                setFixedTemplate(healed, now)
                return true
            }
        }
        val aligned = FixedPlan.alignFixedTimes(s, _entries.value, now) ?: return false
        updateSettings(aligned)
        return true
    }

    /**
     * Lernender Grundplan: einmal täglich, nur solange heute noch keine Entleerung eingetragen
     * ist, den Grundplan aus der Füllrate der letzten 14 Tage neu ableiten. Nur im Wecker-Modus
     * mit Ausrichtung. true = Grundplan geändert.
     */
    fun learnTemplateIfDue(now: LocalDateTime = LocalDateTime.now()): Boolean {
        val s = _settings.value
        if (!s.autoLearnTemplate || !s.anchorToFirstVoid || !s.useFixedTimes) return false
        val today = now.toLocalDate()
        val key = today.toString()
        if (s.templateLearnDayKey == key) return false
        if (_entries.value.any { it.urineMl > 0 && it.dateTime.toLocalDate() == today }) return false
        val marked = s.copy(templateLearnDayKey = key)
        val learned = IntervalPlanner.intervalPlan(_entries.value, s.targetMl, now, 14)
            ?.let { FixedPlan.learnedTemplate(s.fixedTemplate, it.times) }
        if (learned == null) {
            updateSettings(marked)
            return false
        }
        updateSettings(marked.copy(templateLearnedFrom = s.fixedTemplate, templateLearnedAt = key))
        setFixedTemplate(learned, now)
        return true
    }

    /** Grundplan setzen. Lücken über 4 Stunden schließt die App selbst; bei Ausrichtung wird sofort verschoben. */
    fun setFixedTemplate(times: List<Int>, now: LocalDateTime = LocalDateTime.now()) {
        val sorted = FixedPlan.filledFixedTimes(times)
        var s = _settings.value
        if (s.anchorToFirstVoid) s = s.copy(fixedTimesTemplate = sorted, anchorDayKey = "")
        s = s.copy(fixedTimes = sorted)
        s = FixedPlan.alignFixedTimes(s, _entries.value, now) ?: s
        updateSettings(s)
    }

    fun setAnchorToFirstVoid(on: Boolean, now: LocalDateTime = LocalDateTime.now()) {
        var s = _settings.value
        if (on) {
            val template = FixedPlan.filledFixedTimes(s.sortedFixedTimes)
            s = s.copy(fixedTimesTemplate = template, fixedTimes = template, anchorToFirstVoid = true, anchorDayKey = "")
            s = FixedPlan.alignFixedTimes(s, _entries.value, now) ?: s
        } else {
            s = s.copy(fixedTimes = s.fixedTemplate, anchorToFirstVoid = false, anchorDayKey = "")
        }
        updateSettings(s)
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

    /** Sorte umbenannt (2.8): Einträge referenzieren den Namen und ziehen mit. */
    fun renameCatheterSort(oldName: String, newName: String) {
        if (oldName.isEmpty() || oldName == newName) return
        if (_entries.value.none { it.catheterSort == oldName }) return
        _entries.value = _entries.value.map { if (it.catheterSort == oldName) it.copy(catheterSort = newName) else it }
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
    /// Letzter BLASENEINTRAG — nur der taktet den Timer (Trink-/Stuhl-Einträge nie).
    val lastBladderEntry: ToiletEntry? get() = _entries.value.firstOrNull { it.urineMl > 0 }

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
