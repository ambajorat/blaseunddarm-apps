package de.bajorat.blaseunddarm.ui

import android.app.Activity
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
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
import de.bajorat.blaseunddarm.data.BillingManager

@Composable
fun PaywallDialog(billingManager: BillingManager, onDismiss: () -> Unit) {
    val monthlyPrice by billingManager.monthlyPrice.collectAsState()
    val yearlyPrice by billingManager.yearlyPrice.collectAsState()
    val trialDays by billingManager.trialDaysLeft.collectAsState()
    val isTrialActive by billingManager.isTrialActive.collectAsState()
    var selectedPlan by remember { mutableStateOf("yearly") }
    val context = LocalContext.current

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text("⭐", fontSize = 36.sp)
                Text("Premium freischalten", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("Alle Funktionen für dein Blasen-\nund Darmmanagement", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            }
        },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // Features
                listOf(
                    "📊" to "Volle Statistiken (30/90 Tage)",
                    "📤" to "CSV-Export & Import",
                    "📋" to "Bristol-Stuhlformen-Skala",
                    "💧" to "Urinfarbe dokumentieren",
                    "✏️" to "Einträge bearbeiten",
                    "🌙" to "Ruhezeit für die Nacht",
                    "⚙️" to "Individuelle Schnellwahl-Werte"
                ).forEach { (icon, text) ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(icon)
                        Text(text, fontSize = 13.sp)
                    }
                }

                Spacer(Modifier.height(8.dp))

                // Yearly plan
                OutlinedCard(
                    onClick = { selectedPlan = "yearly" },
                    modifier = Modifier.fillMaxWidth(),
                    border = BorderStroke(if (selectedPlan == "yearly") 2.dp else 1.dp, if (selectedPlan == "yearly") Orange else MaterialTheme.colorScheme.outline)
                ) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = selectedPlan == "yearly", onClick = { selectedPlan = "yearly" })
                        Column {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Jahresabo", fontWeight = FontWeight.SemiBold)
                                Text("Spare 17%", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Orange)
                            }
                            Text(if (yearlyPrice.isNotEmpty()) "$yearlyPrice / Jahr" else "Laden...", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }

                // Monthly plan
                OutlinedCard(
                    onClick = { selectedPlan = "monthly" },
                    modifier = Modifier.fillMaxWidth(),
                    border = BorderStroke(if (selectedPlan == "monthly") 2.dp else 1.dp, if (selectedPlan == "monthly") Orange else MaterialTheme.colorScheme.outline)
                ) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = selectedPlan == "monthly", onClick = { selectedPlan = "monthly" })
                        Column {
                            Text("Monatsabo", fontWeight = FontWeight.SemiBold)
                            Text(if (monthlyPrice.isNotEmpty()) "$monthlyPrice / Monat" else "Laden...", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }

                if (isTrialActive) {
                    Text("Noch $trialDays Tage kostenlos testen", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                }

                Text("Das Abo verlängert sich automatisch. Kündigung jederzeit über Google Play.", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val activity = context as? Activity ?: return@Button
                    if (selectedPlan == "yearly") billingManager.purchaseYearly(activity)
                    else billingManager.purchaseMonthly(activity)
                },
                colors = ButtonDefaults.buttonColors(containerColor = Orange)
            ) {
                Text("Jetzt abonnieren", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Abbrechen") }
        }
    )
}
