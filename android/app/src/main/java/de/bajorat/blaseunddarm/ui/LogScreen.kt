package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.ui.platform.LocalContext
import de.bajorat.blaseunddarm.data.*
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.LocalDateTime

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LogScreen(dataStore: BDMDataStore, onScheduleReminder: () -> Unit) {
    val entries by dataStore.entries.collectAsState()
    val settings by dataStore.settings.collectAsState()

    var urineMl by remember { mutableStateOf("") }
    var urineColor by remember { mutableStateOf(UrineColor.NONE) }
    var bowel by remember { mutableStateOf(false) }
    var bristolType by remember { mutableStateOf(BristolType.NONE) }
    var note by remember { mutableStateOf("") }
    var drinkText by remember { mutableStateOf("") }
    var showSaved by remember { mutableStateOf(false) }
    var showBristolInfo by remember { mutableStateOf(false) }
    var alarmTriggered by remember { mutableStateOf(false) }
    var showAlarm by remember { mutableStateOf(false) }
    val alarmContext = LocalContext.current
    val drinkSettings = DrinkSettings.load(alarmContext)
    val utiSettings = UtiSettings.load(alarmContext)
    var symptoms by remember { mutableStateOf(setOf<UtiSymptom>()) }
    val palpSettings = PalpationSettings.load(alarmContext)
    var palpation by remember { mutableStateOf<PalpationFinding?>(null) }
    val adSettings = AdSettings.load(alarmContext)
    var adSigns by remember { mutableStateOf(setOf<AdSign>()) }
    var bpText by remember { mutableStateOf("") }
    var stoolAmount by remember { mutableStateOf<StoolAmount?>(null) }
    var showPaywall by remember { mutableStateOf(false) }
    val hasAccess = true
    val isTrialActive = false
    val trialDaysLeft = 0
    val isPremium = true
    var timeRemaining by remember { mutableLongStateOf(0L) }

    LaunchedEffect(entries, settings) {
        while (true) {
            val last = dataStore.lastEntry
            if (last != null && settings.reminderEnabled) {
                val elapsed = Duration.between(last.dateTime, LocalDateTime.now()).seconds
                timeRemaining = (settings.intervalMinutes * 60L) - elapsed
            }
            // Trigger alarm when timer hits zero
            if (timeRemaining <= 0 && !alarmTriggered && dataStore.lastEntry != null) {
                alarmTriggered = true
                showAlarm = true
                // Vibrate
                val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val manager = alarmContext.getSystemService(VibratorManager::class.java)
                    manager?.defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    alarmContext.getSystemService(Vibrator::class.java)
                }
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), -1))
                // Play alarm sound
                try {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    RingtoneManager.getRingtone(alarmContext, uri)?.play()
                } catch (_: Exception) {}
            } else if (timeRemaining > 0) {
                alarmTriggered = false
            }
            delay(1000)
        }
    }

    fun formatTime(seconds: Long): String {
        val total = kotlin.math.abs(seconds).toInt()
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        // Header with timer
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text("Blase & Darm Manager", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("Dein tägliches Protokoll", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
            }
            if (settings.reminderEnabled && dataStore.lastEntry != null) {
                if (settings.quietHoursEnabled && settings.isInQuietHours()) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text("🌙", fontSize = 16.sp)
                        Text("Ruhezeit", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else if (timeRemaining <= 0) {
                    val overdue = (-timeRemaining).toInt()
                    Column(horizontalAlignment = Alignment.End) {
                        Text(formatTime(-timeRemaining), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.error)
                        Text("überfällig", fontSize = 9.sp, color = MaterialTheme.colorScheme.error)
                    }
                } else {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(formatTime(timeRemaining), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Orange)
                        Text("nächste Erinnerung", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // Overdue alert
        if (settings.reminderEnabled && timeRemaining <= 0 && dataStore.lastEntry != null) {
            Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.12f)), border = BorderStroke(1.dp, Orange.copy(alpha = 0.3f))) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("⚠️", fontSize = 16.sp)
                    Text("Zeit für den Toilettengang!", fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Orange)
                }
            }
            Spacer(Modifier.height(14.dp))
        }

        // Trial banner
        if (!isPremium) {
            Card(onClick = { showPaywall = true }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.08f)), border = BorderStroke(1.dp, Orange.copy(alpha = 0.15f))) {
                Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("⭐", fontSize = 14.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(if (isTrialActive) "Testphase: noch $trialDaysLeft Tage" else "Testphase abgelaufen", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    Text("Premium", fontSize = 10.sp, color = Orange, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(14.dp))
        }

        // Today summary
        Text("Heute", fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(6.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Row(Modifier.padding(vertical = 12.dp)) {
                SummaryItem("${dataStore.todayMl}", "ml", "Urin", Orange, Modifier.weight(1f))
                Box(Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outline))
                SummaryItem("${dataStore.todayBowel}×", null, "Stuhl", Purple, Modifier.weight(1f))
                Box(Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outline))
                if (drinkSettings.enabled) {
                    SummaryItem("${dataStore.todayDrink}", "ml", "Getrunken", androidx.compose.ui.graphics.Color(0xFF2A9D8F), Modifier.weight(1f))
                    Box(Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outline))
                }
                SummaryItem("${dataStore.todayCount}", null, "Einträge", MaterialTheme.colorScheme.onSurfaceVariant, Modifier.weight(1f))
            }
        }

        Spacer(Modifier.height(14.dp))

        // Entry form
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("Neuer Eintrag", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(12.dp))

                // Urine ml
                Text("Urin-Menge (ml)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(value = urineMl, onValueChange = { urineMl = it.filter { c -> c.isDigit() } }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("ml eingeben") }, singleLine = true)
                Spacer(Modifier.height(6.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    settings.quickValues.forEach { v ->
                        FilterChip(selected = urineMl == v.toString(), onClick = { urineMl = v.toString() }, label = { Text("$v", fontWeight = FontWeight.SemiBold) })
                    }
                }

                Spacer(Modifier.height(14.dp))

                // Urine color
                if (hasAccess) {
                Text("Urinfarbe", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(6.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    UrineColor.displayValues().forEach { color ->
                        FilterChip(selected = urineColor == color, onClick = { urineColor = if (urineColor == color) UrineColor.NONE else color }, label = { Text("${color.emoji} ${color.label}", fontSize = 11.sp) })
                    }
                }

                } else {
                    Card(onClick = { showPaywall = true }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.06f))) {
                        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("💧 Urinfarbe", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.weight(1f))
                            Text("Premium", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Orange)
                        }
                    }
                }

                Spacer(Modifier.height(14.dp))

                // Tastbefund (optional)
                if (palpSettings.enabled) {
                    Text("Tastbefund", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        PalpationFinding.entries.forEach { f ->
                            FilterChip(
                                selected = palpation == f,
                                onClick = { palpation = if (palpation == f) null else f },
                                label = { Text(f.label, fontSize = 12.sp) }
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }

                // Auffälligkeiten (HWI-Frühwarnung, optional)
                if (utiSettings.enabled) {
                    Text("Auffälligkeiten", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        UtiSymptom.entries.forEach { sym ->
                            FilterChip(
                                selected = symptoms.contains(sym),
                                onClick = { symptoms = if (symptoms.contains(sym)) symptoms - sym else symptoms + sym },
                                label = { Text(sym.label, fontSize = 12.sp) }
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }

                // Vegetative Zeichen / AD (optional)
                if (adSettings.enabled) {
                    Text("Vegetative Zeichen", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        AdSign.entries.forEach { z ->
                            FilterChip(
                                selected = adSigns.contains(z),
                                onClick = { adSigns = if (adSigns.contains(z)) adSigns - z else adSigns + z },
                                label = { Text(z.label, fontSize = 12.sp) }
                            )
                        }
                    }
                    if (adSettings.bpEnabled) {
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(
                            value = bpText,
                            onValueChange = { bpText = it.filter { c -> c.isDigit() } },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("RR systolisch (mmHg)") },
                            singleLine = true
                        )
                    }
                    Spacer(Modifier.height(14.dp))
                }

                // Getrunken (optional)
                if (drinkSettings.enabled) {
                    Text("Getrunken (ml)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    OutlinedTextField(value = drinkText, onValueChange = { drinkText = it.filter { c -> c.isDigit() } }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("ml eingeben") }, singleLine = true)
                    Spacer(Modifier.height(6.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        drinkSettings.presets.forEach { v ->
                            FilterChip(selected = drinkText == v.toString(), onClick = { drinkText = v.toString() }, label = { Text("$v", fontWeight = FontWeight.SemiBold) })
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }

                // Bowel
                OutlinedButton(onClick = { bowel = !bowel; if (!bowel) { bristolType = BristolType.NONE; stoolAmount = null } }, modifier = Modifier.fillMaxWidth().height(48.dp), colors = if (bowel) ButtonDefaults.outlinedButtonColors(containerColor = Purple.copy(alpha = 0.12f)) else ButtonDefaults.outlinedButtonColors(), border = BorderStroke(1.dp, if (bowel) Purple else MaterialTheme.colorScheme.outline)) {
                    Text(if (bowel) "✅ Stuhlgang" else "⬜ Stuhlgang", color = if (bowel) Purple else MaterialTheme.colorScheme.onSurfaceVariant)
                }

                // Stuhlmenge (nur wenn Stuhlgang aktiv)
                if (bowel) {
                    Spacer(Modifier.height(10.dp))
                    Text("Stuhlmenge", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        StoolAmount.entries.forEach { a ->
                            FilterChip(
                                selected = stoolAmount == a,
                                onClick = { stoolAmount = if (stoolAmount == a) null else a },
                                label = { Text("${a.emoji} ${a.label}", fontSize = 12.sp) }
                            )
                        }
                    }
                }

                // Bristol
                if (bowel) {
                    Spacer(Modifier.height(10.dp))
                    if (hasAccess) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("Bristol-Skala", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        TextButton(onClick = { showBristolInfo = true }) {
                            Text("Was ist das?", fontSize = 11.sp, color = Orange)
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        BristolType.displayValues().chunked(4).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                                row.forEach { type ->
                                    FilterChip(selected = bristolType == type, onClick = { bristolType = if (bristolType == type) BristolType.NONE else type }, label = { Text(type.label, fontSize = 10.sp) }, modifier = Modifier.weight(1f))
                                }
                                // Fill empty slots
                                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                    } else {
                        Card(onClick = { showPaywall = true }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.06f))) {
                            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text("📋 Bristol-Skala", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Spacer(Modifier.weight(1f))
                                Text("Premium", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Orange)
                            }
                        }
                    }
                }

                Spacer(Modifier.height(14.dp))

                // Note
                OutlinedTextField(value = note, onValueChange = { note = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("Notiz (optional)") }, singleLine = true)

                Spacer(Modifier.height(14.dp))

                // Save
                val canSave = (urineMl.toIntOrNull() ?: 0) > 0 || bowel || (drinkText.toIntOrNull() ?: 0) > 0
                Button(onClick = {
                    dataStore.addEntry(ToiletEntry(urineMl = urineMl.toIntOrNull() ?: 0, bowel = bowel, bristolType = bristolType.name, urineColor = urineColor.name, note = note, drinkMl = drinkText.toIntOrNull() ?: 0, symptoms = symptoms.map { it.name },
                        palpation = palpation?.name ?: "",
                        adSigns = adSigns.map { it.name },
                        systolicBp = bpText.toIntOrNull()?.takeIf { adSettings.enabled && adSettings.bpEnabled && it in 60..300 } ?: 0,
                        stoolAmount = if (bowel) stoolAmount?.name ?: "" else ""))
                    onScheduleReminder()
                    urineMl = ""; urineColor = UrineColor.NONE; bowel = false; bristolType = BristolType.NONE; note = ""; symptoms = setOf(); palpation = null; adSigns = setOf(); bpText = ""; stoolAmount = null; drinkText = ""; showSaved = true
                }, modifier = Modifier.fillMaxWidth().height(48.dp), enabled = canSave, colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                    Text(if (showSaved) "✓ Gespeichert" else "Speichern", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                }
                LaunchedEffect(showSaved) { if (showSaved) { delay(2000); showSaved = false } }
            }
        }
        Spacer(Modifier.height(100.dp))
    }

    if (showBristolInfo) {
        BristolInfoDialog(onDismiss = { showBristolInfo = false })
    }

    if (showAlarm) {
        AlertDialog(
            onDismissRequest = { showAlarm = false },
            title = {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Text("⚠️", fontSize = 48.sp)
                    Text("Toiletten-Erinnerung", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                }
            },
            text = {
                Text("Zeit für den nächsten Toilettengang!", textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.fillMaxWidth())
            },
            confirmButton = {
                Button(onClick = { showAlarm = false }, colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                    Text("OK", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                }
            }
        )
    }
}

@Composable
private fun SummaryItem(value: String, unit: String?, label: String, color: androidx.compose.ui.graphics.Color, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = color)
            if (unit != null) Text(" $unit", fontSize = 10.sp, color = color.copy(alpha = 0.7f))
        }
        Text(label, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
