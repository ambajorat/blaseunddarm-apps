package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.bajorat.blaseunddarm.data.AppSettings
import de.bajorat.blaseunddarm.data.BDMDataStore
import de.bajorat.blaseunddarm.data.FixedPlan
import de.bajorat.blaseunddarm.data.I18n
import de.bajorat.blaseunddarm.data.IntervalPlanner
import de.bajorat.blaseunddarm.data.ToiletEntry
import de.bajorat.blaseunddarm.data.tr
import de.bajorat.blaseunddarm.data.trf
import de.bajorat.blaseunddarm.notification.ReminderManager
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// ==================== WECKER-MODUS (2.10, Parität zu iOS 4.13–4.20) ====================

private fun clocks(times: List<Int>): String = times.joinToString(" · ") { FixedPlan.clock(it) }

private fun shortDate(iso: String): String? = runCatching {
    LocalDate.parse(iso).format(DateTimeFormatter.ofPattern("d. MMM", if (I18n.isGerman) Locale.GERMAN else Locale.ENGLISH))
}.getOrNull()

private fun intervalText(minutes: Int): String =
    if (minutes % 60 == 0) trf("{0} Std", minutes / 60) else trf("{0} Std {1} Min", minutes / 60, minutes % 60)

/** Einstellungen im Wecker-Modus: Grundplan, Ausrichten, lernender Grundplan, Zielmenge, Vorschlag. */
@Composable
fun FixedTimesSettings(settings: AppSettings, entries: List<ToiletEntry>, dataStore: BDMDataStore, reminderManager: ReminderManager) {
    val context = LocalContext.current
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val template = settings.fixedTemplate
    val target = settings.targetMl
    fun reschedule() {
        val s = dataStore.settings.value
        if (s.reminderEnabled && s.useFixedTimes) reminderManager.scheduleFixedPlan(s)
    }
    fun setTemplate(times: List<Int>) { dataStore.setFixedTemplate(times); reschedule() }

    // ---- Grundplan ----
    template.forEach { minutes ->
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(FixedPlan.clock(minutes), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            if (template.size > 1) {
                IconButton(onClick = { setTemplate(template - minutes) }) { Icon(Icons.Filled.Close, tr("Entfernen"), Modifier.size(16.dp)) }
            }
        }
    }
    TextButton(onClick = {
        val now = java.util.Calendar.getInstance()
        android.app.TimePickerDialog(context, { _, h, m ->
            setTemplate(template + (h * 60 + m))
        }, now.get(java.util.Calendar.HOUR_OF_DAY), 0, true).show()
    }) { Text(tr("Zeit hinzufügen"), fontSize = 13.sp) }
    Text(tr("Abstände über 4 Stunden füllt die App automatisch mit einer Zwischenzeit auf."), fontSize = 11.sp, color = muted)

    // ---- An Entleerungen ausrichten ----
    Spacer(Modifier.height(10.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(tr("An Entleerungen ausrichten"), fontSize = 14.sp, modifier = Modifier.weight(1f))
        Switch(checked = settings.anchorToFirstVoid, onCheckedChange = { dataStore.setAnchorToFirstVoid(it); reschedule() })
    }
    Text(
        tr("Die erste Zeit gilt als Aufwachzeit: Die erste Entleerung am Morgen verschiebt den ganzen Tag. Danach startet jede Entleerung den Abstand neu — gehst du früher, kommt auch die nächste Erinnerung früher."),
        fontSize = 11.sp, color = muted
    )
    if (settings.anchorToFirstVoid) {
        if (settings.anchorDayKey == LocalDate.now().toString()) {
            Text(trf("Heute: {0}", clocks(settings.sortedFixedTimes)), fontSize = 12.sp, color = Orange, modifier = Modifier.padding(top = 4.dp))
        }

        // ---- Lernender Grundplan ----
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tr("Grundplan automatisch anpassen"), fontSize = 14.sp, modifier = Modifier.weight(1f))
            Switch(checked = settings.autoLearnTemplate, onCheckedChange = { dataStore.updateSettings(settings.copy(autoLearnTemplate = it)) })
        }
        Text(
            trf("Die App leitet den Grundplan täglich aus deiner Füllrate der letzten 14 Tage ab, damit du möglichst nie über {0} ml kommst. Zeiten ändern sich erst ab 15 Minuten Unterschied und nie mitten am Tag.", target),
            fontSize = 11.sp, color = muted
        )
        val learnedOn = shortDate(settings.templateLearnedAt)
        if (settings.autoLearnTemplate && learnedOn != null && settings.templateLearnedFrom.isNotEmpty()) {
            Text(trf("Zuletzt angepasst am {0}: {1} → {2}", learnedOn, clocks(settings.templateLearnedFrom), clocks(template)),
                fontSize = 10.sp, color = muted, modifier = Modifier.padding(top = 4.dp))
        }
    }

    // ---- Zielmenge + Vorschlag „Abstände nach Tageszeit“ ----
    Spacer(Modifier.height(10.dp))
    HorizontalDivider()
    Spacer(Modifier.height(10.dp))
    Text(tr("Abstände nach Tageszeit"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(trf("Zielmenge je Entleerung: {0} ml", target), fontSize = 14.sp, modifier = Modifier.weight(1f))
        OutlinedButton(onClick = { dataStore.updateSettings(settings.copy(targetVolumeMl = maxOf(200, target - 25))) },
            enabled = target > 200, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
        Spacer(Modifier.width(8.dp))
        OutlinedButton(onClick = { dataStore.updateSettings(settings.copy(targetVolumeMl = minOf(600, target + 25))) },
            enabled = target < 600, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
    }
    val plan = remember(entries, target) { IntervalPlanner.intervalPlan(entries, target) }
    if (plan == null) {
        Text(tr("Für einen Vorschlag braucht es Urin-Einträge an mindestens 7 Tagen in den letzten 30 Tagen."), fontSize = 11.sp, color = muted)
    } else {
        Spacer(Modifier.height(4.dp))
        plan.slots.forEach { slot ->
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                Text(tr(slot.label) + " (" + slot.rangeText + ")", fontSize = 12.sp, modifier = Modifier.weight(1f))
                Text(trf("bis {0} ml/Std", slot.rateMlPerHour), fontSize = 12.sp, color = muted)
                Spacer(Modifier.width(12.dp))
                Text(intervalText(slot.suggestedMinutes), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(trf("Vorgeschlagene Zeiten: {0}", clocks(plan.times)), fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
        Spacer(Modifier.height(6.dp))
        val adopted = FixedPlan.filledFixedTimes(plan.times) == template
        Button(onClick = { setTemplate(plan.times) }, enabled = !adopted, modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
            Text(if (adopted) tr("Übernommen") else tr("Als feste Zeiten übernehmen"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
        }
        Text(trf("Vorgeschlagene Abstände für höchstens {0} ml — aus deinen letzten 30 Tagen.", plan.targetMl) + " " +
            tr("Beschreibt nur deine eigenen Einträge — keine medizinische Empfehlung."), fontSize = 10.sp, color = muted, modifier = Modifier.padding(top = 4.dp))
    }
}

/** Wurde der Grundplan in den letzten 7 Tagen automatisch angepasst? */
fun learnedTemplateRecent(settings: AppSettings, today: LocalDate = LocalDate.now()): Boolean {
    if (!settings.autoLearnTemplate || !settings.anchorToFirstVoid || settings.templateLearnedFrom.isEmpty()) return false
    val at = runCatching { LocalDate.parse(settings.templateLearnedAt) }.getOrNull() ?: return false
    return !at.isBefore(today.minusDays(6)) && !at.isAfter(today)
}

/** Hinweise-Reiter: „Grundplan angepasst am …“ mit Vorher/Jetzt. */
@Composable
fun LearnedTemplateCard(settings: AppSettings) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("Grundplan"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(8.dp))
            Text(trf("Grundplan angepasst am {0}", shortDate(settings.templateLearnedAt) ?: ""), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            Text(trf("Vorher: {0}", clocks(settings.templateLearnedFrom)), style = MaterialTheme.typography.bodySmall, color = muted)
            Text(trf("Jetzt: {0}", clocks(settings.fixedTemplate)), style = MaterialTheme.typography.bodySmall, color = Orange)
            Spacer(Modifier.height(6.dp))
            Text(trf("Aus deiner Füllrate der letzten 14 Tage, Ziel {0} ml je Entleerung. Abschaltbar in den Einstellungen unter „Feste Uhrzeiten“.", settings.targetMl),
                style = MaterialTheme.typography.bodySmall, color = muted)
        }
    }
}

/** Statistik: Anteil der Entleerungen bis zur Zielmenge (ab 5 Entleerungen im Zeitraum). */
@Composable
fun TargetVolumeCard(entries: List<ToiletEntry>, targetMl: Int) {
    val d = remember(entries, targetMl) { IntervalPlanner.targetStats(entries, targetMl) } ?: return
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Spacer(Modifier.height(12.dp))
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(trf("Zielmenge {0} ml eingehalten", d.target), fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                color = if (d.pct >= 90) Green else MaterialTheme.colorScheme.onSurface)
            Text(trf("{0} % der Entleerungen · {1} von {2} darüber", d.pct, d.over, d.total), fontSize = 12.sp, color = muted)
            val w = d.worstSlot
            if (w != null && d.worstCount > 0) {
                Text(trf("Am häufigsten {0} ({1}×)", tr(IntervalPlanner.slotName(w)), d.worstCount), fontSize = 10.sp, color = muted)
            }
        }
    }
}

/** Statistik: eigene Füllrate je Tagesfenster mit dem daraus abgeleiteten Abstand. */
@Composable
fun FillRateCard(entries: List<ToiletEntry>, targetMl: Int) {
    val plan = remember(entries, targetMl) { IntervalPlanner.intervalPlan(entries, targetMl) } ?: return
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val track = muted.copy(alpha = 0.2f)
    val maxRate = maxOf(plan.slots.maxOf { it.rateMlPerHour }, 1)
    Spacer(Modifier.height(12.dp))
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("Füllrate nach Tageszeit"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.height(6.dp))
            plan.slots.forEach { slot ->
                Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(tr(slot.label), fontSize = 12.sp, modifier = Modifier.width(92.dp), maxLines = 1)
                    Canvas(Modifier.weight(1f).height(8.dp)) {
                        val r = CornerRadius(size.height / 2f, size.height / 2f)
                        drawRoundRect(track, Offset.Zero, Size(size.width, size.height), r)
                        val f = (slot.rateMlPerHour.toFloat() / maxRate).coerceIn(0f, 1f)
                        if (f > 0f) drawRoundRect(Orange, Offset.Zero, Size(maxOf(size.width * f, size.height), size.height), r)
                    }
                    Text(intervalText(slot.suggestedMinutes), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp))
                }
            }
            Text(trf("Vorgeschlagene Abstände für höchstens {0} ml — aus deinen letzten 30 Tagen.", plan.targetMl), fontSize = 10.sp, color = muted, modifier = Modifier.padding(top = 4.dp))
        }
    }
}
