package de.bajorat.blaseunddarm.data

import kotlinx.serialization.Serializable
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

enum class UrineColor(val label: String, val emoji: String) {
    NONE("", ""),
    CLEAR("Durchsichtig", "💧"),
    LIGHT_YELLOW("Hell gelb", "🟡"),
    DARK_YELLOW("Dunkel gelb", "🟠"),
    CLOUDY("Trüb", "🌫️");

    companion object {
        fun displayValues() = entries.filter { it != NONE }
    }
}

enum class BristolType(val label: String, val shortDesc: String, val category: String) {
    NONE("", "", ""),
    TYPE1("Typ 1", "Einzelne harte Klumpen", "Verstopfung"),
    TYPE2("Typ 2", "Wurstartig, klumpig", "Verstopfung"),
    TYPE3("Typ 3", "Wurstartig, rissig", "Normal"),
    TYPE4("Typ 4", "Glatt, weich", "Normal"),
    TYPE5("Typ 5", "Weiche Klümpchen", "Durchfall"),
    TYPE6("Typ 6", "Breiig, aufgelöst", "Durchfall"),
    TYPE7("Typ 7", "Wässrig, flüssig", "Durchfall");

    companion object {
        fun displayValues() = entries.filter { it != NONE }
    }
}

enum class PalpationFinding(val label: String) {
    SOFT("Tief eindrückbar"),
    MEDIUM("Leichter Widerstand"),
    FIRM("Deutlich federnd")
}

enum class AdSign(val label: String) {
    GOOSEBUMPS("Gänsehaut"),
    SWEATING("Schwitzen"),
    HEAT("Hitzegefühl"),
    HEADACHE("Kopfschmerz")
}

enum class StoolAmount(val label: String, val emoji: String) {
    VERY_SMALL("Sehr klein", "🐜"),
    SMALL("Klein", "🐭"),
    MEDIUM("Mittel", "🐰"),
    LARGE("Groß", "🐕"),
    HUGE("Riesig", "🐘")
}

enum class UtiSymptom(val label: String) {
    SMELL("Starker Geruch"),
    BLOOD("Blut im Urin"),
    PAIN("Brennen/Schmerzen"),
    SPASTICITY("Vermehrte Spastik"),
    FEVER("Fieber/Schüttelfrost"),
    MALAISE("Abgeschlagenheit");

    val isUrgent: Boolean get() = this == BLOOD || this == FEVER
}

@Serializable
data class ToiletEntry(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: String = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
    val urineMl: Int = 0,
    val bowel: Boolean = false,
    val bristolType: String = BristolType.NONE.name,
    val urineColor: String = UrineColor.NONE.name,
    val note: String = "",
    val drinkMl: Int = 0,
    val symptoms: List<String> = emptyList(),
    val palpation: String = "",
    val adSigns: List<String> = emptyList(),
    val systolicBp: Int = 0,
    val stoolAmount: String = ""
) {
    val utiSymptoms: List<UtiSymptom>
        get() = symptoms.mapNotNull { runCatching { UtiSymptom.valueOf(it) }.getOrNull() }
    val palpationFinding: PalpationFinding?
        get() = runCatching { PalpationFinding.valueOf(palpation) }.getOrNull()
    val adSignList: List<AdSign>
        get() = adSigns.mapNotNull { runCatching { AdSign.valueOf(it) }.getOrNull() }
    val stoolAmountValue: StoolAmount?
        get() = runCatching { StoolAmount.valueOf(stoolAmount) }.getOrNull()

    val dateTime: LocalDateTime
        get() = LocalDateTime.parse(timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
}

@Serializable
data class AppSettings(
    val reminderEnabled: Boolean = true,
    val intervalMinutes: Int = 210,
    val quickValues: List<Int> = listOf(100, 200, 300, 400, 500),
    val quietHoursEnabled: Boolean = true,
    val quietFrom: Int = 22,
    val quietTo: Int = 6
) {
    fun isInQuietHours(): Boolean {
        val hour = LocalDateTime.now().hour
        return if (quietFrom < quietTo) {
            hour in quietFrom until quietTo
        } else {
            hour >= quietFrom || hour < quietTo
        }
    }
}
