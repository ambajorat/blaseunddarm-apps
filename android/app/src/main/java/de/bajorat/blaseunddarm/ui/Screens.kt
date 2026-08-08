package de.bajorat.blaseunddarm.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
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
            Text("Noch keine Einträge", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    } else {
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            grouped.forEach { (date, dayEntries) ->
                item {
                    Spacer(Modifier.height(16.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(when {
                            date == LocalDate.now() -> "Heute"
                            date == LocalDate.now().minusDays(1) -> "Gestern"
                            else -> date.format(DateTimeFormatter.ofPattern("EE dd.MM"))
                        }, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        val totalMl = dayEntries.sumOf { it.urineMl }
                        val bowelCount = dayEntries.count { it.bowel }
                        Text("$totalMl ml · ${bowelCount}× Stuhl", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(entry.dateTime.format(DateTimeFormatter.ofPattern("HH:mm")), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            if (entry.urineMl > 0) Text("${entry.urineMl} ml", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Orange)
                            val color = try { UrineColor.valueOf(entry.urineColor) } catch (_: Exception) { UrineColor.NONE }
                            if (color != UrineColor.NONE) Text(color.emoji, fontSize = 12.sp)
                            if (entry.bowel) {
                                val bristol = try { BristolType.valueOf(entry.bristolType) } catch (_: Exception) { BristolType.NONE }
                                Text("Stuhl${if (bristol != BristolType.NONE) " ${bristol.label}" else ""}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Purple)
                            }
                            if (entry.note.isNotEmpty()) Text(entry.note, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.weight(1f))
                            Spacer(Modifier.weight(1f))
                            Text("✏️", fontSize = 12.sp)
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
        AlertDialog(onDismissRequest = { deleteEntry = null }, title = { Text("Eintrag löschen?") },
            confirmButton = { TextButton(onClick = { dataStore.deleteEntry(entry); deleteEntry = null }) { Text("Löschen", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { deleteEntry = null }) { Text("Abbrechen") } })
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EditEntryDialog(entry: ToiletEntry, dataStore: BDMDataStore, onDismiss: () -> Unit, onDelete: () -> Unit) {
    var urineMl by remember { mutableStateOf(if (entry.urineMl > 0) entry.urineMl.toString() else "") }
    var urineColor by remember { mutableStateOf(try { UrineColor.valueOf(entry.urineColor) } catch (_: Exception) { UrineColor.NONE }) }
    var bowel by remember { mutableStateOf(entry.bowel) }
    var bristolType by remember { mutableStateOf(try { BristolType.valueOf(entry.bristolType) } catch (_: Exception) { BristolType.NONE }) }
    var note by remember { mutableStateOf(entry.note) }

    AlertDialog(onDismissRequest = onDismiss, title = { Text("Eintrag bearbeiten") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(entry.dateTime.format(DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm")), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(value = urineMl, onValueChange = { urineMl = it.filter { c -> c.isDigit() } }, label = { Text("Urin (ml)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Text("Urinfarbe", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    UrineColor.displayValues().forEach { color ->
                        FilterChip(selected = urineColor == color, onClick = { urineColor = if (urineColor == color) UrineColor.NONE else color }, label = { Text(color.emoji, fontSize = 14.sp) })
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = bowel, onCheckedChange = { bowel = it; if (!it) bristolType = BristolType.NONE })
                    Text("Stuhlgang")
                }
                if (bowel) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        BristolType.displayValues().forEach { type ->
                            FilterChip(selected = bristolType == type, onClick = { bristolType = if (bristolType == type) BristolType.NONE else type }, label = { Text(type.label, fontSize = 10.sp) })
                        }
                    }
                }
                OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("Notiz") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                TextButton(onClick = onDelete) { Text("Eintrag löschen", color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                dataStore.updateEntry(entry.copy(urineMl = urineMl.toIntOrNull() ?: 0, urineColor = urineColor.name, bowel = bowel, bristolType = bristolType.name, note = note))
                onDismiss()
            }) { Text("Sichern") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Abbrechen") } })
}

// ==================== STATS ====================

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun StatsScreen(dataStore: BDMDataStore) {
    val entries by dataStore.entries.collectAsState()
    var range by remember { mutableIntStateOf(7) }
    val ranges = listOf(7 to "7 Tage", 30 to "30 Tage", 90 to "3 Monate", 365 to "1 Jahr")
    val context = LocalContext.current

    if (entries.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Noch keine Daten", color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                        Text("⌀ Urin", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("$avgMl ml", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Orange)
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("⌀ Gänge", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("%.1f".format(avgCount), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("⌀ Stuhl", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("%.1f".format(avgBowel), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Purple)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Tagesübersicht", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    activeDays.forEach { date ->
                        val dayEntries = filtered.filter { it.dateTime.toLocalDate() == date }
                        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Text(date.format(DateTimeFormatter.ofPattern("dd.MM")), Modifier.weight(1f), fontSize = 12.sp)
                            Text("${dayEntries.sumOf { it.urineMl }} ml", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Orange)
                            Spacer(Modifier.width(16.dp))
                            Text("${dayEntries.size}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.width(16.dp))
                            Text("${dayEntries.count { it.bowel }}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Purple)
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
                            appendLine("Datum;Uhrzeit;Urin_ml;Urinfarbe;Stuhlgang;Bristol;Notiz")
                            filtered.sortedByDescending { it.timestamp }.forEach { e ->
                                appendLine("${e.dateTime.format(tf)};${e.urineMl};${e.urineColor};${if (e.bowel) "Ja" else "Nein"};${e.bristolType};${e.note}")
                            }
                        }
                        val file = File(context.cacheDir, "Blase_Darm_Export.csv")
                        file.writeText(csv)
                        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                        val intent = Intent(Intent.ACTION_SEND).apply { type = "text/csv"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                        context.startActivity(Intent.createChooser(intent, "CSV exportieren"))
                    }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                        Text("CSV", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
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
                        context.startActivity(Intent.createChooser(intent, "PDF exportieren"))
                    }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                        Text("PDF", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
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
                        Text("📤 Export (CSV / PDF)", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
        Text("Einstellungen", fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(24.dp))

        // Reminders
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Erinnerungen", fontWeight = FontWeight.SemiBold)
                    Switch(checked = settings.reminderEnabled, onCheckedChange = { dataStore.updateSettings(settings.copy(reminderEnabled = it)) })
                }
                if (settings.reminderEnabled) {
                    Spacer(Modifier.height(12.dp))
                    val hours = settings.intervalMinutes / 60
                    val mins = settings.intervalMinutes % 60
                    Text("Intervall: $hours Std $mins Min", fontSize = 14.sp, color = Orange, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Slider(value = settings.intervalMinutes.toFloat(), onValueChange = { dataStore.updateSettings(settings.copy(intervalMinutes = (it / 15).toInt() * 15)) }, valueRange = 15f..480f, steps = 30)
                    Spacer(Modifier.height(16.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("Ruhezeit", fontSize = 14.sp)
                        Switch(checked = settings.quietHoursEnabled, onCheckedChange = { dataStore.updateSettings(settings.copy(quietHoursEnabled = it)) })
                    }
                    if (settings.quietHoursEnabled) {
                        Spacer(Modifier.height(8.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column {
                                Text("Von", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(onClick = { if (settings.quietFrom > 0) dataStore.updateSettings(settings.copy(quietFrom = settings.quietFrom - 1)) }) { Text("−", fontSize = 20.sp) }
                                    Text("${settings.quietFrom}:00", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Orange)
                                    IconButton(onClick = { if (settings.quietFrom < 23) dataStore.updateSettings(settings.copy(quietFrom = settings.quietFrom + 1)) }) { Text("+", fontSize = 20.sp) }
                                }
                            }
                            Column {
                                Text("Bis", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(onClick = { if (settings.quietTo > 0) dataStore.updateSettings(settings.copy(quietTo = settings.quietTo - 1)) }) { Text("−", fontSize = 20.sp) }
                                    Text("${settings.quietTo}:00", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Orange)
                                    IconButton(onClick = { if (settings.quietTo < 23) dataStore.updateSettings(settings.copy(quietTo = settings.quietTo + 1)) }) { Text("+", fontSize = 20.sp) }
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
                    Text("Schnellwahl-Mengen (ml)", fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    settings.quickValues.forEach { v ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text("$v ml", fontSize = 14.sp)
                            IconButton(onClick = { dataStore.updateSettings(settings.copy(quickValues = settings.quickValues.filter { it != v })) }) { Text("✕", color = MaterialTheme.colorScheme.error) }
                        }
                        HorizontalDivider()
                    }
                    var newVal by remember { mutableStateOf("") }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(value = newVal, onValueChange = { newVal = it.filter { c -> c.isDigit() } }, placeholder = { Text("Neuer Wert") }, singleLine = true, modifier = Modifier.weight(1f))
                        Spacer(Modifier.width(8.dp))
                        IconButton(onClick = { val v = newVal.toIntOrNull(); if (v != null && v > 0) { dataStore.updateSettings(settings.copy(quickValues = (settings.quickValues + v).sorted())); newVal = "" } }) { Text("+", fontSize = 24.sp, color = Orange) }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        Spacer(Modifier.height(16.dp))

        // Backup
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("Backup", fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text("Sichere deine Daten und stelle sie bei Bedarf wieder her.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                                            note = p.getOrNull(6)?.trim() ?: ""
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
                    context.startActivity(Intent.createChooser(intent, "Backup speichern"))
                }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                    Text("Backup erstellen", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = { restoreLauncher.launch("application/json") }, modifier = Modifier.fillMaxWidth()) {
                    Text("Backup wiederherstellen")
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = { csvImportLauncher.launch("text/*") }, modifier = Modifier.fillMaxWidth()) {
                    Text("CSV importieren")
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Data
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("Daten", fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text("${entries.size} Einträge gespeichert", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                OutlinedButton(onClick = { showDeleteConfirm = true }) {
                    Text("Alle Daten löschen", color = MaterialTheme.colorScheme.error)
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Info
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("Info", fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text("Version ${de.bajorat.blaseunddarm.BuildConfig.VERSION_NAME}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Alle Daten werden lokal gespeichert.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Diese App ist kein Medizinprodukt.", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                Text("© André M. Bajorat · blaseunddarm.de", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                val uriHandler = androidx.compose.ui.platform.LocalUriHandler.current
                OutlinedButton(onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, "Blase & Darm Manager – die App für dein Toiletten-Management: https://blaseunddarm.de") }
                    context.startActivity(Intent.createChooser(intent, "App empfehlen"))
                }, modifier = Modifier.fillMaxWidth()) { Text("App empfehlen", color = Orange) }
                OutlinedButton(onClick = { uriHandler.openUri("https://buymeacoffee.com/ploetzlichquerschnitt") }, modifier = Modifier.fillMaxWidth()) { Text("☕ Buy me a coffee", color = Orange) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de/datenschutz.html") }, modifier = Modifier.fillMaxWidth()) { Text("Datenschutzerklärung", fontSize = 12.sp) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de") }, modifier = Modifier.fillMaxWidth()) { Text("blaseunddarm.de", fontSize = 12.sp) }
                OutlinedButton(onClick = { uriHandler.openUri("https://blaseunddarm.de") }, modifier = Modifier.fillMaxWidth()) { Text("⭐ Feedback geben", color = Orange) }
            }
        }
        Spacer(Modifier.height(100.dp))
    }

    if (showDeleteConfirm) {
        AlertDialog(onDismissRequest = { showDeleteConfirm = false }, title = { Text("Alle Daten löschen?") },
            text = { Text("${entries.size} Einträge werden unwiderruflich gelöscht.") },
            confirmButton = { TextButton(onClick = { dataStore.deleteAll(); showDeleteConfirm = false }) { Text("Löschen", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text("Abbrechen") } })
    }
}
