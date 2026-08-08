package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import de.bajorat.blaseunddarm.data.*

@Composable
fun AlertsScreen(store: BDMDataStore) {
    val context = LocalContext.current
    var settings by remember { mutableStateOf(AlertSettings.load(context)) }
    val entries by store.entries.collectAsState()

    fun update(new: AlertSettings) {
        settings = new
        new.save(context)
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Heute-Ampel
        item {
            SectionCard(title = "Heute") {
                val statuses = AlertEngine.statusList(entries, settings)
                if (statuses.isEmpty()) {
                    Text(
                        "Keine Regel aktiv. Schalte unten ein, worauf die App achten soll.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    statuses.forEach { status ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(vertical = 4.dp)
                        ) {
                            val (icon, tint) = when (status.state) {
                                RuleState.OK -> Icons.Filled.CheckCircle to Color(0xFF4CAF50)
                                RuleState.WARN -> Icons.Filled.Warning to Color(0xFFFF9800)
                                RuleState.WAITING -> Icons.Filled.Schedule to MaterialTheme.colorScheme.onSurfaceVariant
                                RuleState.NO_DATA -> Icons.Filled.Info to MaterialTheme.colorScheme.onSurfaceVariant
                            }
                            Icon(icon, contentDescription = null, tint = tint)
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text(status.title, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    status.detail,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }

        // Einzelmenge
        item {
            SectionCard(title = "Einzelmenge") {
                ToggleRow("Einzelmenge über Grenze", settings.singleOverEnabled) {
                    update(settings.copy(singleOverEnabled = it))
                }
                if (settings.singleOverEnabled) {
                    StepperRow("Grenze", "${settings.singleOverMl} ml",
                        onMinus = { if (settings.singleOverMl > 100) update(settings.copy(singleOverMl = settings.singleOverMl - 25)) },
                        onPlus = { if (settings.singleOverMl < 1000) update(settings.copy(singleOverMl = settings.singleOverMl + 25)) })
                }
                FooterText("Warnt sofort beim Speichern, wenn ein einzelner Eintrag die Grenze erreicht.")
            }
        }

        // Tagesmenge
        item {
            SectionCard(title = "Tagesmenge") {
                ToggleRow("Tagesmenge über Grenze", settings.dayOverEnabled) {
                    update(settings.copy(dayOverEnabled = it))
                }
                if (settings.dayOverEnabled) {
                    StepperRow("Grenze", "${settings.dayOverMl} ml",
                        onMinus = { if (settings.dayOverMl > 1000) update(settings.copy(dayOverMl = settings.dayOverMl - 100)) },
                        onPlus = { if (settings.dayOverMl < 5000) update(settings.copy(dayOverMl = settings.dayOverMl + 100)) })
                }
                ToggleRow("Tagesmenge unter Grenze", settings.dayUnderEnabled) {
                    update(settings.copy(dayUnderEnabled = it))
                }
                if (settings.dayUnderEnabled) {
                    StepperRow("Grenze", "${settings.dayUnderMl} ml",
                        onMinus = { if (settings.dayUnderMl > 250) update(settings.copy(dayUnderMl = settings.dayUnderMl - 100)) },
                        onPlus = { if (settings.dayUnderMl < 3000) update(settings.copy(dayUnderMl = settings.dayUnderMl + 100)) })
                }
            }
        }

        // Häufigkeit
        item {
            SectionCard(title = "Häufigkeit") {
                ToggleRow("Mehr Gänge als Grenze", settings.countOverEnabled) {
                    update(settings.copy(countOverEnabled = it))
                }
                if (settings.countOverEnabled) {
                    StepperRow("Grenze", "${settings.countOverLimit} Gänge",
                        onMinus = { if (settings.countOverLimit > 2) update(settings.copy(countOverLimit = settings.countOverLimit - 1)) },
                        onPlus = { if (settings.countOverLimit < 30) update(settings.copy(countOverLimit = settings.countOverLimit + 1)) })
                }
                ToggleRow("Weniger Gänge als Grenze", settings.countUnderEnabled) {
                    update(settings.copy(countUnderEnabled = it))
                }
                if (settings.countUnderEnabled) {
                    StepperRow("Grenze", "${settings.countUnderLimit} Gänge",
                        onMinus = { if (settings.countUnderLimit > 1) update(settings.copy(countUnderLimit = settings.countUnderLimit - 1)) },
                        onPlus = { if (settings.countUnderLimit < 15) update(settings.copy(countUnderLimit = settings.countUnderLimit + 1)) })
                }
            }
        }

        // Persönliche Baseline
        item {
            SectionCard(title = "Persönlicher Schnitt") {
                ToggleRow("Abweichung vom eigenen Schnitt", settings.baselineEnabled) {
                    update(settings.copy(baselineEnabled = it))
                }
                if (settings.baselineEnabled) {
                    StepperRow("Ab Abweichung von", "±${settings.baselineDeviationPercent} %",
                        onMinus = { if (settings.baselineDeviationPercent > 10) update(settings.copy(baselineDeviationPercent = settings.baselineDeviationPercent - 5)) },
                        onPlus = { if (settings.baselineDeviationPercent < 100) update(settings.copy(baselineDeviationPercent = settings.baselineDeviationPercent + 5)) })
                    val base = AlertEngine.baseline(entries)
                    if (base != null) {
                        Text(
                            "Dein Schnitt (${base.days} Tage): ${base.avgMl} ml · ${"%.0f".format(base.avgCount)} Gänge",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    } else {
                        Text(
                            "Noch nicht genug Daten — es braucht mindestens 5 Tage mit Einträgen in den letzten 14 Tagen.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
                FooterText("Vergleicht den heutigen Tag mit dem Durchschnitt deiner letzten 14 Tage — ganz ohne feste Grenzwerte.")
            }
        }

        // Fußnote
        item {
            Text(
                "Grenzen nach unten und Abweichungen unter den Schnitt prüft die App ab ${AlertEngine.UNDER_CHECK_HOUR} Uhr — der tägliche Abend-Check läuft automatisch im Hintergrund.\n\nDiese Hinweise ersetzen keine ärztliche Beratung.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp)
            )
        }
    }
}

// MARK: - Bausteine

@Composable
private fun SectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(8.dp))
            content()
        }
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun StepperRow(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        IconButton(onClick = onMinus) { Icon(Icons.Filled.Remove, contentDescription = "weniger") }
        Text(value, style = MaterialTheme.typography.bodyMedium)
        IconButton(onClick = onPlus) { Icon(Icons.Filled.Add, contentDescription = "mehr") }
    }
}

@Composable
private fun FooterText(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 4.dp)
    )
}
