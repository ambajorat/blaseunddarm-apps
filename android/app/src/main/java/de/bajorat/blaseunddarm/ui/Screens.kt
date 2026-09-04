package de.bajorat.blaseunddarm.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import de.bajorat.blaseunddarm.data.*
import de.bajorat.blaseunddarm.notification.ReminderManager
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter

// ==================== HISTORY ====================

@Composable
fun HistoryScreen(dataStore: BDMDataStore) {
    val entries by dataStore.entries.collectAsState()
    val grouped = entries.groupBy { it.dateTime.toLocalDate() }.toSortedMap(compareByDescending { it })
    var editEntry by remember { mutableStateOf<ToiletEntry?>(null) }
    var deleteEntry by remember { mutableStateOf<ToiletEntry?>(null) }
    var showPaywall by remember { mutableStateOf(false) }

    if (entries.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(tr("Noch keine Einträge"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    } else {
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            grouped.forEach { (date, dayEntries) ->
                item {
                    Spacer(Modifier.height(16.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(when {
                            date == LocalDate.now() -> tr("Heute")
                            date == LocalDate.now().minusDays(1) -> tr("Gestern")
                            else -> date.format(DateTimeFormatter.ofPattern("EE dd.MM.", if (I18n.isGerman) java.util.Locale.GERMAN else java.util.Locale.ENGLISH))
                        }, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        val totalMl = dayEntries.sumOf { it.urineMl }
                        val totalDrink = dayEntries.sumOf { it.drinkMl }
                        val bowelCount = dayEntries.count { it.bowel }
                        Text(if (totalDrink > 0) "$totalMl ml · \uD83E\uDD64 $totalDrink ml · ${bowelCount}× Stuhl" else "$totalMl ml · ${bowelCount}× Stuhl", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(Modifier.height(8.dp))
                }
                items(dayEntries) { entry ->
                    Card(
                        onClick = {
                            if (true) editEntry = entry
                            else showPaywall = true
                        },
                        modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp)
                    ) {
                        Column(Modifier.padding(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(entry.dateTime.format(DateTimeFormatter.ofPattern("HH:mm")), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            if (entry.urineMl > 0) Text(trf("{0} ml", entry.urineMl), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Orange)
                            val color = try { UrineColor.valueOf(entry.urineColor) } catch (_: Exception) { UrineColor.NONE }
                            if (color != UrineColor.NONE) Text(color.emoji, fontSize = 12.sp)
                            if (entry.drinkMl > 0) Text(trf("\uD83E\uDD64 {0} ml", entry.drinkMl), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = androidx.compose.ui.graphics.Color(0xFF2A9D8F))
                            if (entry.bowel) {
                                val bristol = try { BristolType.valueOf(entry.bristolType) } catch (_: Exception) { BristolType.NONE }
                                Text(trf("Stuhl{0}", if (bristol != BristolType.NONE) " ${tr(bristol.label)}" else ""), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Purple)
                            }
                            if (entry.note.isNotEmpty()) Text(entry.note, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.weight(1f))
                            Spacer(Modifier.weight(1f))
                            Text(tr("✏️"), fontSize = 12.sp)
                        }
                        val details = buildList {
                            entry.palpationFinding?.let { add("Tastbefund: ${tr(it.label)}") }
                            if (entry.utiSymptoms.isNotEmpty()) add(tr("Auffällig: ") + entry.utiSymptoms.joinToString(", ") { tr(it.label) })
                            if (entry.adSignList.isNotEmpty()) add(tr("Vegetativ: ") + entry.adSignList.joinToString(", ") { tr(it.label) })
                            if (entry.systolicBp > 0) add("RR ${entry.systolicBp}")
                            if (entry.bowel) entry.stoolAmountValue?.let { add("${it.emoji} ${tr(it.label)}") }
                            if (entry.medications.isNotEmpty()) add("\uD83D\uDC8A " + entry.medications.joinToString(", "))
                        }
                        if (details.isNotEmpty()) {
                            Text(details.joinToString(" · "), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, modifier = Modifier.padding(top = 4.dp))
                        }
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(100.dp)) }
        }
    }

    editEntry?.let { entry ->
        EditEntryDialog(entry = entry, dataStore = dataStore, onDismiss = { editEntry = null }, onDelete = { deleteEntry = entry; editEntry = null })
    }
    deleteEntry?.let { entry ->
        AlertDialog(onDismissRequest = { deleteEntry = null }, title = { Text(tr("Eintrag löschen?")) },
            confirmButton = { TextButton(onClick = { dataStore.deleteEntry(entry); deleteEntry = null }) { Text(tr("Löschen"), color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { deleteEntry = null }) { Text(tr("Abbrechen")) } })
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EditEntryDialog(entry: ToiletEntry, dataStore: BDMDataStore, onDismiss: () -> Unit, onDelete: () -> Unit) {
    var urineMl by remember { mutableStateOf(if (entry.urineMl > 0) entry.urineMl.toString() else "") }
    var drinkMl by remember { mutableStateOf(if (entry.drinkMl > 0) entry.drinkMl.toString() else "") }
    var urineColor by remember { mutableStateOf(try { UrineColor.valueOf(entry.urineColor) } catch (_: Exception) { UrineColor.NONE }) }
    var editMeds by remember { mutableStateOf(entry.medications.toSet()) }
    var bowel by remember { mutableStateOf(entry.bowel) }
    var bristolType by remember { mutableStateOf(try { BristolType.valueOf(entry.bristolType) } catch (_: Exception) { BristolType.NONE }) }
    var note by remember { mutableStateOf(entry.note) }
    var symptoms by remember { mutableStateOf(entry.utiSymptoms.toSet()) }
    var palpation by remember { mutableStateOf(entry.palpationFinding) }
    var adSigns by remember { mutableStateOf(entry.adSignList.toSet()) }
    var bpText by remember { mutableStateOf(if (entry.systolicBp > 0) entry.systolicBp.toString() else "") }
    var stoolAmount by remember { mutableStateOf(entry.stoolAmountValue) }
    val editContext = androidx.compose.ui.platform.LocalContext.current
    val palpOn = PalpationSettings.load(editContext).enabled || palpation != null
    val utiOn = UtiSettings.load(editContext).enabled || symptoms.isNotEmpty()
    val adOn = AdSettings.load(editContext).enabled || adSigns.isNotEmpty() || bpText.isNotEmpty()
    val bpOn = AdSettings.load(editContext).bpEnabled || bpText.isNotEmpty()

    AlertDialog(onDismissRequest = onDismiss, title = { Text(tr("Eintrag bearbeiten")) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(entry.dateTime.format(DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm")), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(value = urineMl, onValueChange = { urineMl = it.filter { c -> c.isDigit() } }, label = { Text(tr("Urin (ml)")) }, singleLine = true, modifier = Modifier.fillMaxWidth())
                if (DrinkSettings.load(androidx.compose.ui.platform.LocalContext.current).enabled || drinkMl.isNotEmpty()) {
                    OutlinedTextField(value = drinkMl, onValueChange = { drinkMl = it.filter { c -> c.isDigit() } }, label = { Text(tr("Getrunken (ml)")) }, singleLine = true, modifier = Modifier.fillMaxWidth())
                }
                Text(tr("Urinfarbe"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    UrineColor.displayValues().forEach { color ->
                        FilterChip(selected = urineColor == color, onClick = { urineColor = if (urineColor == color) UrineColor.NONE else color }, label = { Text(color.emoji, fontSize = 14.sp) })
                    }
                }
                if (palpOn) {
                    Text(tr("Tastbefund"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        PalpationFinding.entries.forEach { f ->
                            FilterChip(selected = palpation == f, onClick = { palpation = if (palpation == f) null else f }, label = { Text(tr(f.label), fontSize = 10.sp) })
                        }
                    }
                }
                run {
                    val medS = MedicationSettings.load(LocalContext.current)
                    val known = (medS.medications.map { it.name }.filter { it.isNotBlank() } + editMeds).distinct().sorted()
                    if (known.isNotEmpty()) {
                        Text(tr("Medikamente"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            known.forEach { name ->
                                FilterChip(selected = editMeds.contains(name), onClick = {
                                    editMeds = if (editMeds.contains(name)) editMeds - name else editMeds + name
                                }, label = { Text(name, fontSize = 10.sp) })
                            }
                        }
                    }
                }
                if (utiOn) {
                    Text(tr("Auffälligkeiten"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        UtiSymptom.entries.forEach { sym ->
                            FilterChip(selected = symptoms.contains(sym), onClick = { symptoms = if (symptoms.contains(sym)) symptoms - sym else symptoms + sym }, label = { Text(tr(sym.label), fontSize = 10.sp) })
                        }
                    }
                }
                if (adOn) {
                    Text(tr("Vegetative Zeichen"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        AdSign.entries.forEach { z ->
                            FilterChip(selected = adSigns.contains(z), onClick = { adSigns = if (adSigns.contains(z)) adSigns - z else adSigns + z }, label = { Text(tr(z.label), fontSize = 10.sp) })
                        }
                    }
                    if (bpOn) {
                    val bpNum = bpText.toIntOrNull()
                    val bpShowErr = bpNum != null && (bpNum > 300 || (bpNum < 60 && bpText.length >= 2))
                    OutlinedTextField(value = bpText, onValueChange = { bpText = it.filter { c -> c.isDigit() } }, label = { Text(tr("RR systolisch (mmHg)")) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                        isError = bpShowErr,
                        supportingText = { if (bpShowErr) Text(tr("Gültig sind 60–300 mmHg — der Wert wird sonst nicht gespeichert.")) })
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = bowel, onCheckedChange = { bowel = it; if (!it) { bristolType = BristolType.NONE; stoolAmount = null } })
                    Text(tr("Stuhlgang"))
                }
                if (bowel) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        BristolType.displayValues().forEach { type ->
                            FilterChip(selected = bristolType == type, onClick = { bristolType = if (bristolType == type) BristolType.NONE else type }, label = { Text(tr(type.label), fontSize = 10.sp) })
                        }
                    }
                    Text(tr("Stuhlmenge"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        StoolAmount.entries.forEach { a ->
                            FilterChip(selected = stoolAmount == a, onClick = { stoolAmount = if (stoolAmount == a) null else a }, label = { Text(trf("{0} {1}", a.emoji, tr(a.label)), fontSize = 10.sp) })
                        }
                    }
                }
                OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text(tr("Notiz")) }, singleLine = true, modifier = Modifier.fillMaxWidth())
                TextButton(onClick = onDelete) { Text(tr("Eintrag löschen"), color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                dataStore.updateEntry(entry.copy(urineMl = urineMl.toIntOrNull() ?: 0, drinkMl = drinkMl.toIntOrNull() ?: 0, urineColor = urineColor.name, bowel = bowel, bristolType = bristolType.name, note = note, symptoms = symptoms.map { it.name }, palpation = palpation?.name ?: "", adSigns = adSigns.map { it.name }, systolicBp = bpText.toIntOrNull()?.takeIf { it in 60..300 } ?: 0, stoolAmount = if (bowel) stoolAmount?.name ?: "" else "", medications = editMeds.toList().sorted()))
                onDismiss()
            }) { Text(tr("Sichern")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(tr("Abbrechen")) } })
}

// ==================== STATS ====================

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun StatsScreen(dataStore: BDMDataStore) {
    val entries by dataStore.entries.collectAsState()
    var range by remember { mutableIntStateOf(7) }
    val ranges = listOf(7 to tr("7 Tage"), 30 to tr("30 Tage"), 90 to tr("3 Monate"), 365 to tr("1 Jahr"))
    val context = LocalContext.current

    if (entries.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(tr("Noch keine Daten"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    } else {
        val today = LocalDate.now()
        val filtered = entries.filter { it.dateTime.toLocalDate().isAfter(today.minusDays(range.toLong())) }
        val days = (1..range).map { today.minusDays(it.toLong() - 1) }
        val activeDays = days.filter { date -> filtered.any { it.dateTime.toLocalDate() == date } }
        val avgMl = if (activeDays.isNotEmpty()) filtered.sumOf { it.urineMl } / activeDays.size else 0
        val avgCount = if (activeDays.isNotEmpty()) filtered.size.toFloat() / activeDays.size else 0f
        val avgBowel = if (activeDays.isNotEmpty()) filtered.count { it.bowel }.toFloat() / activeDays.size else 0f
        val df = DateTimeFormatter.ofPattern("dd.MM.yyyy")

        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ranges.forEach { (d, label) ->
                    FilterChip(selected = range == d, onClick = { range = d }, label = { Text(label, fontSize = 12.sp) })
                }
            }
            Spacer(Modifier.height(16.dp))

            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(vertical = 14.dp)) {
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(tr("⌀ Urin"), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(trf("{0} ml", avgMl), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Orange)
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(tr("⌀ Gänge"), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(tr("%.1f").format(avgCount), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(tr("⌀ Stuhl"), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(tr("%.1f").format(avgBowel), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Purple)
                    }
                }
            }

            // Katheterbestand (nachgeholt aus 2.0)
            val catheterStats = CatheterStock.load(context)
            if (catheterStats.enabled) {
                Spacer(Modifier.height(12.dp))
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(trf("\uD83E\uDDF4 {0} ", catheterStats.currentStock(entries)) + tr("Katheter im Bestand"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        val cDays = catheterStats.daysRemaining(entries)
                        val cEmpty = catheterStats.estimatedEmptyDate(entries)
                        if (cDays != null && cEmpty != null) {
                            Text(trf("Reicht etwa {0} Tage — bis ca. {1}", cDays, cEmpty.format(DateTimeFormatter.ofPattern("d. MMM"))), fontSize = 12.sp,
                                color = if (cDays <= catheterStats.warnDays) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }

            // Tastbefund, kalibriert (Ø ml je Stufe, min. 3 Einträge)
            val palpRows = PalpationFinding.entries.mapNotNull { f ->
                val ml = filtered.filter { it.palpationFinding == f && it.urineMl > 0 }.map { it.urineMl }
                if (ml.size >= 3) Triple(f, ml.sum() / ml.size, ml.size) else null
            }
            if (palpRows.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(tr("Dein Tastbefund, kalibriert"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        Spacer(Modifier.height(6.dp))
                        palpRows.forEach { (f, avg, n) ->
                            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                                Text(tr(f.label), fontSize = 12.sp, modifier = Modifier.weight(1f))
                                Text(trf("Ø {0} ml ({1}×)", avg, n), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Text(tr("Aus deinen eigenen Einträgen."), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            // Auffälligkeiten im Zeitraum
            val symCounts = (UtiSymptom.entries.map { sym -> sym.label to filtered.count { it.utiSymptoms.contains(sym) } } +
                             AdSign.entries.map { z -> z.label to filtered.count { it.adSignList.contains(z) } }).filter { it.second > 0 }
            if (symCounts.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(tr("Auffälligkeiten im Zeitraum"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        Spacer(Modifier.height(6.dp))
                        symCounts.forEach { (label, n) ->
                            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                                Text(label, fontSize = 12.sp, modifier = Modifier.weight(1f))
                                Text(trf("{0}×", n), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        val bps = filtered.mapNotNull { if (it.systolicBp > 0) it.systolicBp else null }
                        if (bps.isNotEmpty()) {
                            Text(trf("RR systolisch: {0}–{1} mmHg", bps.min(), bps.max()), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
                        }
                    }
                }
            }

            // Ein- und Ausfuhr (nur Tage mit Trink-Einträgen, min. 3)
            val balDays = filtered.groupBy { it.dateTime.toLocalDate() }
                .mapValues { (_, l) -> Pair(l.sumOf { it.drinkMl }, l.sumOf { it.urineMl }) }
                .values.filter { it.first > 0 }
            if (balDays.size >= 3) {
                Spacer(Modifier.height(12.dp))
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(tr("Ein- und Ausfuhr"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        Text(trf("Ø getrunken {0} ml · Ø ausgeschieden {1} ml", balDays.sumOf { it.first } / balDays.size, balDays.sumOf { it.second } / balDays.size), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(trf("Tage mit Trink-Einträgen: {0}", balDays.size), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(tr("Tagesübersicht"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    activeDays.forEach { date ->
                        val dayEntries = filtered.filter { it.dateTime.toLocalDate() == date }
                        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Text(date.format(DateTimeFormatter.ofPattern("dd.MM")), Modifier.weight(1f), fontSize = 12.sp)
                            Text(trf("{0} ml", dayEntries.sumOf { it.urineMl }), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Orange)
                            Spacer(Modifier.width(16.dp))
                            Text(trf("{0}", dayEntries.size), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.width(16.dp))
                            Text(trf("{0}", dayEntries.count { it.bowel }), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Purple)
                        }
                        HorizontalDivider()
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            if (true) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    // CSV Export
                    Button(onClick = {
                        val tf = DateTimeFormatter.ofPattern("dd.MM.yyyy;HH:mm")
                        val csv = buildString {
                            appendLine("Datum;Uhrzeit;Urin_ml;Urinfarbe;Stuhlgang;Bristol;Notiz;Getrunken_ml;Symptome;Tastbefund;AD_Zeichen;RR_syst;Stuhlmenge;Medikamente")
                            filtered.sortedByDescending { it.timestamp }.forEach { e ->
                                appendLine("${e.dateTime.format(tf)};${e.urineMl};${e.urineColor};${if (e.bowel) "Ja" else "Nein"};${e.bristolType};${e.note};${e.drinkMl};${e.utiSymptoms.joinToString(", ") { it.label }};${e.palpationFinding?.label ?: ""};${e.adSignList.joinToString(", ") { it.label }};${if (e.systolicBp > 0) e.systolicBp.toString() else ""};${e.stoolAmountValue?.label ?: ""};${e.medications.joinToString(", ")}")
                            }
                        }
                        val file = File(context.cacheDir, "Blase_Darm_Export.csv")
                        file.writeText(csv)
                        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                        val intent = Intent(Intent.ACTION_SEND).apply { type = "text/csv"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                        context.startActivity(Intent.createChooser(intent, tr("CSV exportieren")))
                    }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                        Text(tr("CSV"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                    }

                    // PDF Export
                    Button(onClick = {
                        val pw = 595f; val ph = 842f; val m = 40f
                        val document = android.graphics.pdf.PdfDocument()
                        var pageNum = 1
                        var page = document.startPage(android.graphics.pdf.PdfDocument.PageInfo.Builder(pw.toInt(), ph.toInt(), pageNum).create())
                        var canvas = page.canvas
                        val paint = android.graphics.Paint().apply { isAntiAlias = true; textSize = 11f; color = android.graphics.Color.DKGRAY }
                        val boldPaint = android.graphics.Paint(paint).apply { isFakeBoldText = true; textSize = 20f; color = android.graphics.Color.WHITE }
                        val orangePaint = android.graphics.Paint(paint).apply { isFakeBoldText = true; color = android.graphics.Color.rgb(232, 146, 58) }
                        val purplePaint = android.graphics.Paint(paint).apply { isFakeBoldText = true; color = android.graphics.Color.rgb(155, 126, 200) }

                        canvas.drawRect(0f, 0f, pw, 70f, android.graphics.Paint().apply { color = android.graphics.Color.rgb(232, 146, 58) })
                        canvas.drawText("Blase & Darm Manager — Statistik", m, 40f, boldPaint)
                        var y = 90f
                        canvas.drawText("Zeitraum: ${ranges.first { it.first == range }.second}", m, y, paint); y += 30f
                        val avgP = android.graphics.Paint(orangePaint).apply { textSize = 16f }
                        canvas.drawText("Ø Urin: $avgMl ml   Ø Gänge: ${"%.1f".format(avgCount)}   Ø Stuhl: ${"%.1f".format(avgBowel)}", m, y, avgP); y += 30f
                        val thP = android.graphics.Paint(paint).apply { color = android.graphics.Color.WHITE; isFakeBoldText = true; textSize = 10f }
                        canvas.drawRect(m, y, pw - m, y + 20f, android.graphics.Paint().apply { color = android.graphics.Color.DKGRAY })
                        canvas.drawText("Datum", m + 8, y + 14f, thP); canvas.drawText("Urin", 200f, y + 14f, thP); canvas.drawText("Gänge", 300f, y + 14f, thP); canvas.drawText("Stuhl", 400f, y + 14f, thP)
                        y += 24f
                        activeDays.forEach { date ->
                            if (y > ph - 50) { document.finishPage(page); pageNum++; page = document.startPage(android.graphics.pdf.PdfDocument.PageInfo.Builder(pw.toInt(), ph.toInt(), pageNum).create()); canvas = page.canvas; y = m }
                            val de2 = filtered.filter { it.dateTime.toLocalDate() == date }
                            canvas.drawText(date.format(df), m + 8, y + 12f, paint)
                            canvas.drawText("${de2.sumOf { it.urineMl }}", 200f, y + 12f, orangePaint)
                            canvas.drawText("${de2.size}", 300f, y + 12f, paint)
                            canvas.drawText("${de2.count { it.bowel }}", 400f, y + 12f, purplePaint)
                            y += 18f
                        }
                        document.finishPage(page)
                        val file = File(context.cacheDir, "Blase_Darm_Statistik.pdf")
                        document.writeTo(java.io.FileOutputStream(file)); document.close()
                        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                        val intent = Intent(Intent.ACTION_SEND).apply { type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                        context.startActivity(Intent.createChooser(intent, tr("PDF exportieren")))
                    }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                        Text(tr("PDF"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                    }
                }
            } else {
                var showPaywall by remember { mutableStateOf(false) }
                Card(
                    onClick = { showPaywall = true },
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.06f))
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(tr("📤 Export (CSV / PDF)"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.weight(1f))
                    }
                }
            }

            Spacer(Modifier.height(100.dp))
        }
    }
}

// ==================== SETTINGS ====================

@Composable
fun SettingsScreen(dataStore: BDMDataStore, reminderManager: ReminderManager) {
    val settings by dataStore.settings.collectAsState()
    val entries by dataStore.entries.collectAsState()
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val context = LocalContext.current

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text(tr("Einstellungen"), fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(24.dp))

        // Reminders
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Erinnerungen"), fontWeight = FontWeight.SemiBold)
                    Switch(checked = settings.reminderEnabled, onCheckedChange = { dataStore.updateSettings(settings.copy(reminderEnabled = it)) })
                }
                if (settings.reminderEnabled) {
                    Spacer(Modifier.height(12.dp))
                    // Erinnerungsart (iOS-4.7-Parität): Intervall oder feste Uhrzeiten
                    val remCtx = androidx.compose.ui.platform.LocalContext.current
                    Text(tr("Erinnerungsart"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = !settings.useFixedTimes, onClick = {
                            val s = settings.copy(useFixedTimes = false)
                            dataStore.updateSettings(s)
                            dataStore.lastBladderEntry?.let { last ->
                                val elapsed = java.time.Duration.between(last.dateTime, java.time.LocalDateTime.now()).toMinutes().toInt()
                                val remaining = s.intervalMinutes - elapsed
                                if (remaining > 0) reminderManager.scheduleReminder(remaining, s.quietFrom, s.quietTo, s.quietHoursEnabled)
                            }
                        }, label = { Text(tr("Intervall"), fontSize = 12.sp) })
                        FilterChip(selected = settings.useFixedTimes, onClick = {
                            val s = settings.copy(useFixedTimes = true)
                            dataStore.updateSettings(s)
                            reminderManager.scheduleFixedTimeReminders(s.fixedTimes)
                        }, label = { Text(tr("Feste Uhrzeiten"), fontSize = 12.sp) })
                    }
                    Spacer(Modifier.height(10.dp))
                    if (settings.useFixedTimes) {
                        settings.fixedTimes.sorted().forEach { minutes ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text(String.format("%02d:%02d", minutes / 60, minutes % 60), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                                if (settings.fixedTimes.size > 1) {
                                    IconButton(onClick = {
                                        val s = settings.copy(fixedTimes = settings.fixedTimes - minutes)
                                        dataStore.updateSettings(s)
                                        reminderManager.scheduleFixedTimeReminders(s.fixedTimes)
                                    }) { Icon(Icons.Filled.Close, tr("Entfernen"), Modifier.size(16.dp)) }
                                }
                            }
                        }
                        TextButton(onClick = {
                            val now = java.util.Calendar.getInstance()
                            android.app.TimePickerDialog(remCtx, { _, h, m ->
                                val s = settings.copy(fixedTimes = (settings.fixedTimes + (h * 60 + m)).distinct().sorted())
                                dataStore.updateSettings(s)
                                reminderManager.scheduleFixedTimeReminders(s.fixedTimes)
                            }, now.get(java.util.Calendar.HOUR_OF_DAY), 0, true).show()
                        }) { Text(tr("Zeit hinzufügen"), fontSize = 13.sp) }
                        Text(tr("Feste Zeiten erinnern unabhängig vom letzten Eintrag."), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                    val hours = settings.intervalMinutes / 60
                    val mins = settings.intervalMinutes % 60
                    Text(trf("Intervall: {0} Std {1} Min", hours, mins), fontSize = 14.sp, color = Orange, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Slider(value = settings.intervalMinutes.toFloat(), onValueChange = { dataStore.updateSettings(settings.copy(intervalMinutes = (it / 15).toInt() * 15)) }, valueRange = 15f..480f, steps = 30)
                    val intervalSug = remember(entries) { SuggestionEngine.compute(entries)?.intervalMinutes }
                    if (intervalSug != null && intervalSug != settings.intervalMinutes) {
                        Spacer(Modifier.height(4.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(tr("Vorschlag aus deinen Daten"), fontSize = 13.sp)
                                Text(trf("Median deiner Abstände: {0} Std {1} Min", intervalSug / 60, intervalSug % 60), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            OutlinedButton(onClick = { dataStore.updateSettings(settings.copy(intervalMinutes = intervalSug)) }) { Text(tr("Übernehmen"), fontSize = 12.sp) }
                        }
                    }
                    }
                    Spacer(Modifier.height(16.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(tr("Ruhezeit"), fontSize = 14.sp)
                        Switch(checked = settings.quietHoursEnabled, onCheckedChange = { dataStore.updateSettings(settings.copy(quietHoursEnabled = it)) })
                    }
                    if (settings.quietHoursEnabled) {
                        Spacer(Modifier.height(8.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column {
                                Text(tr("Von"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(onClick = { if (settings.quietFrom > 0) dataStore.updateSettings(settings.copy(quietFrom = settings.quietFrom - 1)) }) { Text(tr("−"), fontSize = 20.sp) }
                                    Text(trf("{0}:00", settings.quietFrom), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Orange)
                                    IconButton(onClick = { if (settings.quietFrom < 23) dataStore.updateSettings(settings.copy(quietFrom = settings.quietFrom + 1)) }) { Text(tr("+"), fontSize = 20.sp) }
                                }
                            }
                            Column {
                                Text(tr("Bis"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(onClick = { if (settings.quietTo > 0) dataStore.updateSettings(settings.copy(quietTo = settings.quietTo - 1)) }) { Text(tr("−"), fontSize = 20.sp) }
                                    Text(trf("{0}:00", settings.quietTo), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Orange)
                                    IconButton(onClick = { if (settings.quietTo < 23) dataStore.updateSettings(settings.copy(quietTo = settings.quietTo + 1)) }) { Text(tr("+"), fontSize = 20.sp) }
                                }
                            }
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Quick values
        if (true) {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(tr("Schnellwahl-Mengen (ml)"), fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    settings.quickValues.forEach { v ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text(trf("{0} ml", v), fontSize = 14.sp)
                            IconButton(onClick = { dataStore.updateSettings(settings.copy(quickValues = settings.quickValues.filter { it != v })) }) { Text(tr("✕"), color = MaterialTheme.colorScheme.error) }
                        }
                        HorizontalDivider()
                    }
                    var newVal by remember { mutableStateOf("") }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(value = newVal, onValueChange = { newVal = it.filter { c -> c.isDigit() } }, placeholder = { Text(tr("Neuer Wert")) }, singleLine = true, modifier = Modifier.weight(1f))
                        Spacer(Modifier.width(8.dp))
                        IconButton(onClick = { val v = newVal.toIntOrNull(); if (v != null && v > 0) { dataStore.updateSettings(settings.copy(quickValues = (settings.quickValues + v).sorted())); newVal = "" } }) { Text(tr("+"), fontSize = 24.sp, color = Orange) }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        Spacer(Modifier.height(16.dp))

        // Trinkmengen (optional)
        run {
            var drink by remember { mutableStateOf(DrinkSettings.load(context)) }
            var newDrinkVal by remember { mutableStateOf("") }
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(tr("Trinkmengen erfassen"), fontWeight = FontWeight.SemiBold)
                        Switch(checked = drink.enabled, onCheckedChange = { drink = drink.copy(enabled = it); drink.save(context) })
                    }
                    if (drink.enabled) {
                        Spacer(Modifier.height(8.dp))
                        drink.presets.forEach { v ->
                            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text(trf("{0} ml", v), fontSize = 14.sp)
                                IconButton(onClick = { drink = drink.copy(presets = drink.presets.filter { it != v }); drink.save(context) }) { Text(tr("\u2715"), color = MaterialTheme.colorScheme.error) }
                            }
                            HorizontalDivider()
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(value = newDrinkVal, onValueChange = { newDrinkVal = it.filter { c -> c.isDigit() } }, placeholder = { Text(tr("Neuer Wert")) }, singleLine = true, modifier = Modifier.weight(1f))
                            Spacer(Modifier.width(8.dp))
                            IconButton(onClick = { val v = newDrinkVal.toIntOrNull(); if (v != null && v > 0) { drink = drink.copy(presets = (drink.presets + v).sorted()); drink.save(context); newDrinkVal = "" } }) { Text(tr("+"), fontSize = 24.sp, color = Orange) }
                        }
                    } else {
                        Spacer(Modifier.height(4.dp))
                        Text(tr("Optional: Erfasse zusätzlich, wie viel du trinkst."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))

        // Katheterbestand (optional)
        var catheter by remember { mutableStateOf(CatheterStock.load(context)) }
        var stockInput by remember { mutableStateOf("") }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Katheterbestand"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Switch(checked = catheter.enabled, onCheckedChange = {
                        catheter = catheter.copy(enabled = it); catheter.save(context)
                    })
                }
                if (catheter.enabled) {
                    Spacer(Modifier.height(8.dp))
                    val current = catheter.currentStock(entries)
                    Text(trf("Aktueller Bestand: {0} Stück", current), fontSize = 14.sp)
                    val days = catheter.daysRemaining(entries)
                    val empty = catheter.estimatedEmptyDate(entries)
                    if (days != null && empty != null) {
                        Text(
                            trf("Reicht etwa {0} Tage — bis ca. {1}", days, empty.format(java.time.format.DateTimeFormatter.ofPattern("d.M."))),
                            fontSize = 12.sp,
                            color = if (days <= catheter.warnDays) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    } else if (current == 0 && catheter.stockAtAdjustment == 0) {
                        Text(tr("Trage deinen aktuellen Bestand ein, um zu starten."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                        Text(tr("Reichweite erscheint nach ein paar Tagen mit Einträgen."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = stockInput,
                            onValueChange = { stockInput = it.filter { c -> c.isDigit() } },
                            modifier = Modifier.weight(1f),
                            placeholder = { Text(tr("Bestand eintragen")) },
                            singleLine = true
                        )
                        Button(onClick = {
                            stockInput.toIntOrNull()?.let {
                                catheter = catheter.withStock(it); catheter.save(context); stockInput = ""
                            }
                        }, enabled = stockInput.toIntOrNull() != null) { Text(tr("OK")) }
                    }
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(onClick = {
                        catheter = catheter.withPackAdded(entries); catheter.save(context)
                    }, modifier = Modifier.fillMaxWidth()) {
                        Text(trf("+1 Packung ({0} Stück)", catheter.packSize))
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(trf("Warnen unter {0} Tagen", catheter.warnDays), fontSize = 14.sp, modifier = Modifier.weight(1f))
                        OutlinedButton(onClick = {
                            if (catheter.warnDays > 3) { catheter = catheter.copy(warnDays = catheter.warnDays - 1); catheter.save(context) }
                        }, enabled = catheter.warnDays > 3, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
                        Spacer(Modifier.width(8.dp))
                        OutlinedButton(onClick = {
                            if (catheter.warnDays < 30) { catheter = catheter.copy(warnDays = catheter.warnDays + 1); catheter.save(context) }
                        }, enabled = catheter.warnDays < 30, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
                    }
                    Text(tr("Jeder Blaseneintrag zählt als eine Katheterisierung."), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // HWI-Frühwarnung (optional)
        var uti by remember { mutableStateOf(UtiSettings.load(context)) }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("HWI-Frühwarnung"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Switch(checked = uti.enabled, onCheckedChange = {
                        uti = uti.copy(enabled = it); uti.save(context)
                    })
                }
                Text(
                    if (uti.enabled)
                        tr("Beim Erfassen erscheint der Abschnitt \u201EAuffälligkeiten\u201C. Bei Blut oder Fieber meldet sich die App sofort, bei Mustern über mehrere Tage mit einem Hinweis. Ersetzt keine ärztliche Diagnose.")
                    else
                        tr("Optional: Erfasse Anzeichen wie Geruch, Brennen oder vermehrte Spastik — die App warnt bei Mustern, die bei ISK auf einen Harnwegsinfekt hindeuten können. Ersetzt keine ärztliche Diagnose."),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // ISK-Erweiterungen (Tastbefund, vegetative Zeichen)
        var palp by remember { mutableStateOf(PalpationSettings.load(context)) }
        var ad by remember { mutableStateOf(AdSettings.load(context)) }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(tr("ISK-Erweiterungen"), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Tastbefund"), fontSize = 14.sp, modifier = Modifier.weight(1f))
                    Switch(checked = palp.enabled, onCheckedChange = {
                        palp = palp.copy(enabled = it); palp.save(context)
                    })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Vegetative Zeichen"), fontSize = 14.sp, modifier = Modifier.weight(1f))
                    Switch(checked = ad.enabled, onCheckedChange = {
                        ad = ad.copy(enabled = it); ad.save(context)
                    })
                }
                if (ad.enabled) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(tr("Blutdruckfeld (RR systolisch)"), fontSize = 14.sp, modifier = Modifier.weight(1f))
                        Switch(checked = ad.bpEnabled, onCheckedChange = {
                            ad = ad.copy(bpEnabled = it); ad.save(context)
                        })
                    }
                }
                Text(
                    tr("Tastbefund: Füllungsgrad oberhalb des Schambeins in drei Stufen. Vegetative Zeichen: Gänsehaut, Schwitzen, Hitzegefühl oder Kopfschmerz als Füllungssignale, optional mit Blutdruck. Ersetzt keine ärztliche Diagnose."),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // Medikamente (2.5): viertes Zusatzmodul — Doku + Einnahme-Erinnerungen
        var medS by remember { mutableStateOf(MedicationSettings.load(context)) }
        fun medUpdate(new: MedicationSettings) {
            medS = new; new.save(context); reminderManager.scheduleMedicationReminders(new)
        }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Medikamente"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Switch(checked = medS.enabled, onCheckedChange = { medUpdate(medS.copy(enabled = it)) })
                }
                if (medS.enabled) {
                    medS.medications.forEach { med ->
                        Spacer(Modifier.height(10.dp))
                        OutlinedTextField(
                            value = med.name,
                            onValueChange = { new ->
                                medUpdate(medS.copy(medications = medS.medications.map { if (it.id == med.id) it.copy(name = new) else it }))
                            },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text(tr("Name des Medikaments")) },
                            singleLine = true
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(tr("Einnahme-Erinnerungen"), fontSize = 12.sp, modifier = Modifier.weight(1f))
                            Switch(checked = med.remindersEnabled, onCheckedChange = { on ->
                                medUpdate(medS.copy(medications = medS.medications.map { if (it.id == med.id) it.copy(remindersEnabled = on) else it }))
                            })
                        }
                        med.times.sorted().forEach { minutes ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text(String.format("%02d:%02d", minutes / 60, minutes % 60), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                                IconButton(onClick = {
                                    medUpdate(medS.copy(medications = medS.medications.map { if (it.id == med.id) it.copy(times = it.times - minutes) else it }))
                                }) { Icon(Icons.Filled.Close, tr("Entfernen"), Modifier.size(16.dp)) }
                            }
                        }
                        Row {
                            TextButton(onClick = {
                                val now = java.util.Calendar.getInstance()
                                android.app.TimePickerDialog(context, { _, h, m ->
                                    val t = h * 60 + m
                                    medUpdate(medS.copy(medications = medS.medications.map { if (it.id == med.id) it.copy(times = (it.times + t).distinct().sorted()) else it }))
                                }, now.get(java.util.Calendar.HOUR_OF_DAY), 0, true).show()
                            }) { Text(tr("Zeit hinzufügen"), fontSize = 12.sp) }
                            Spacer(Modifier.weight(1f))
                            TextButton(onClick = {
                                medUpdate(medS.copy(medications = medS.medications.filter { it.id != med.id }))
                            }) { Text(tr("Entfernen"), fontSize = 12.sp) }
                        }
                        HorizontalDivider()
                    }
                    Spacer(Modifier.height(6.dp))
                    TextButton(onClick = {
                        medUpdate(medS.copy(medications = medS.medications + Medication(times = listOf(480))))
                    }) { Text(tr("Medikament hinzufügen"), fontSize = 13.sp) }
                    Text(
                        tr("Beim Erfassen antippen, was genommen wurde. Erinnerungen kommen täglich zu den festen Zeiten, auch in der Ruhezeit. Ohne Zeiten: Bedarfsmedikament."),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // Backup
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(tr("Backup"), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text(tr("Sichere deine Daten und stelle sie bei Bedarf wieder her."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(10.dp))

                val restoreLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
                    uri?.let {
                        try {
                            val input = context.contentResolver.openInputStream(it)
                            val jsonStr = input?.bufferedReader()?.readText() ?: return@let
                            input.close()
                            val parser = Json { ignoreUnknownKeys = true }
                            val restored = parser.decodeFromString<List<ToiletEntry>>(jsonStr)
                            dataStore.restoreEntries(restored)
                        } catch (_: Exception) {}
                    }
                }

                val csvImportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
                    uri?.let {
                        try {
                            val input = context.contentResolver.openInputStream(it)
                            val lines = input?.bufferedReader()?.readLines() ?: return@let
                            input.close()
                            val importDf = DateTimeFormatter.ofPattern("dd.MM.yyyy")
                            val imported = mutableListOf<ToiletEntry>()
                            lines.drop(1).forEach { line ->
                                val p = line.split(";")
                                if (p.size >= 2) {
                                    val date = try { LocalDate.parse(p[0].trim(), importDf) } catch (_: Exception) { null }
                                    val time = if (p.size > 1 && p[1].contains(":")) p[1].trim() else "12:00"
                                    if (date != null) {
                                        val ts = LocalDateTime.of(date, LocalTime.parse(time))
                                        imported.add(ToiletEntry(
                                            timestamp = ts.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                                            urineMl = p.getOrNull(2)?.trim()?.toIntOrNull() ?: 0,
                                            bowel = p.getOrNull(4)?.trim()?.lowercase() == "ja",
                                            urineColor = p.getOrNull(3)?.trim()?.uppercase()?.replace(" ", "_") ?: "NONE",
                                            bristolType = p.getOrNull(5)?.trim()?.uppercase()?.replace(" ", "") ?: "NONE",
                                            note = p.getOrNull(6)?.trim() ?: "",
                                            drinkMl = p.getOrNull(7)?.trim()?.toIntOrNull() ?: 0,
                                            medications = p.getOrNull(13)?.trim()?.takeIf { it.isNotEmpty() }?.split(", ")?.map { it.trim() } ?: emptyList()
                                        ))
                                    }
                                }
                            }
                            if (imported.isNotEmpty()) dataStore.restoreEntries(imported)
                        } catch (_: Exception) {}
                    }
                }

                Button(onClick = {
                    val json = Json.encodeToString(entries)
                    val file = File(context.cacheDir, "blase_darm_backup.json")
                    file.writeText(json)
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                    val intent = Intent(Intent.ACTION_SEND).apply { type = "application/json"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                    context.startActivity(Intent.createChooser(intent, tr("Backup speichern")))
                }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                    Text(tr("Backup erstellen"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = { restoreLauncher.launch("application/json") }, modifier = Modifier.fillMaxWidth()) {
                    Text(tr("Backup wiederherstellen"))
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = { csvImportLauncher.launch("text/*") }, modifier = Modifier.fillMaxWidth()) {
                    Text(tr("CSV importieren"))
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Data
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(tr("Daten"), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text(trf("{0} Einträge gespeichert", entries.size), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                OutlinedButton(onClick = { showDeleteConfirm = true }) {
                    Text(tr("Alle Daten löschen"), color = MaterialTheme.colorScheme.error)
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Info
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(tr("Info"), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text(trf("Version {0}", de.bajorat.blaseunddarm.BuildConfig.VERSION_NAME), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(tr("Alle Daten werden lokal gespeichert."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(tr("Diese App ist kein Medizinprodukt."), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                Text(tr("© André M. Bajorat · blaseunddarm.de"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                val uriHandler = androidx.compose.ui.platform.LocalUriHandler.current
                OutlinedButton(onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, "Blase & Darm Manager – die App für dein Toiletten-Management: https://blaseunddarm.de") }
                    context.startActivity(Intent.createChooser(intent, tr("App empfehlen")))
                }, modifier = Modifier.fillMaxWidth()) { Text(tr("App empfehlen"), color = Orange) }
                OutlinedButton(onClick = { uriHandler.openUri("https://buymeacoffee.com/ploetzlichquerschnitt") }, modifier = Modifier.fillMaxWidth()) { Text(tr("☕ Buy me a coffee"), color = Orange) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de/datenschutz.html") }, modifier = Modifier.fillMaxWidth()) { Text(tr("Datenschutzerklärung"), fontSize = 12.sp) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de") }, modifier = Modifier.fillMaxWidth()) { Text(tr("blaseunddarm.de"), fontSize = 12.sp) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de") }, modifier = Modifier.fillMaxWidth()) { Text(tr("⭐ Feedback geben"), color = Orange) }
            }
        }
        Spacer(Modifier.height(100.dp))
    }

    if (showDeleteConfirm) {
        AlertDialog(onDismissRequest = { showDeleteConfirm = false }, title = { Text(tr("Alle Daten löschen?")) },
            text = { Text(trf("{0} Einträge werden unwiderruflich gelöscht.", entries.size)) },
            confirmButton = { TextButton(onClick = { dataStore.deleteAll(); showDeleteConfirm = false }) { Text(tr("Löschen"), color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text(tr("Abbrechen")) } })
    }
}
