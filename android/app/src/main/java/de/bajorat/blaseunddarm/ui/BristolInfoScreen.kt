package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.Image
import androidx.compose.ui.Alignment
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.painterResource
import de.bajorat.blaseunddarm.R

data class BristolInfo(
    val type: String,
    val desc: String,
    val detail: String,
    val category: String,
    val color: Color
)

val bristolInfoList = listOf(
    BristolInfo("Typ 1", "Einzelne harte Klumpen", "Einzelne, harte Klumpen wie Nüsse. Schwer auszuscheiden. Zeichen für starke Verstopfung.", "Verstopfung", Orange),
    BristolInfo("Typ 2", "Wurstartig, klumpig", "Wurstartig, aber klumpig zusammengesetzt. Zeichen für leichte Verstopfung.", "Verstopfung", Orange),
    BristolInfo("Typ 3", "Wurstartig, rissig", "Wie eine Wurst mit Rissen an der Oberfläche. Normal.", "Normal", Color(0xFF5A9A6E)),
    BristolInfo("Typ 4", "Glatt und weich", "Wie eine Wurst oder Schlange, glatt und weich. Ideale Form.", "Normal — Ideal", Color(0xFF5A9A6E)),
    BristolInfo("Typ 5", "Weiche Klümpchen", "Weiche Klümpchen mit klaren Rändern. Neigung zu Durchfall.", "Durchfall", Color(0xFFC0392B)),
    BristolInfo("Typ 6", "Breiig, aufgelöst", "Breiige Konsistenz mit unscharfen Rändern. Leichter Durchfall.", "Durchfall", Color(0xFFC0392B)),
    BristolInfo("Typ 7", "Wässrig, flüssig", "Wässrig, keine festen Bestandteile. Starker Durchfall.", "Durchfall", Color(0xFFC0392B)),
)

@Composable
fun BristolInfoDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Bristol-Stuhlformen-Skala", fontWeight = FontWeight.Bold) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "Die Bristol-Skala wurde 1997 an der Universität Bristol entwickelt und ist ein medizinisches Hilfsmittel zur Klassifikation der Stuhlform.",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(Modifier.height(8.dp))

                bristolInfoList.forEach { info ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, info.color.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                val imgId = when(info.type) {
                                    "Typ 1" -> R.drawable.bristol_type1
                                    "Typ 2" -> R.drawable.bristol_type2
                                    "Typ 3" -> R.drawable.bristol_type3
                                    "Typ 4" -> R.drawable.bristol_type4
                                    "Typ 5" -> R.drawable.bristol_type5
                                    "Typ 6" -> R.drawable.bristol_type6
                                    "Typ 7" -> R.drawable.bristol_type7
                                    else -> R.drawable.bristol_type4
                                }
                                Image(painter = painterResource(imgId), contentDescription = info.type, modifier = Modifier.size(48.dp))
                                Column {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(info.type, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text(
                                    info.category,
                                    fontSize = 11.sp,
                                    color = info.color,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                            Spacer(Modifier.height(4.dp))
                            Text(info.detail, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                            }
                        }
                    }
                }

                Spacer(Modifier.height(8.dp))

                Text("Bedeutung", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                BristolLegendRow(Orange, "Typ 1–2", "Verstopfung — zu wenig Flüssigkeit oder Ballaststoffe")
                BristolLegendRow(Color(0xFF5A9A6E), "Typ 3–4", "Normal — ideale Stuhlform, gesunde Verdauung")
                BristolLegendRow(Color(0xFFC0392B), "Typ 5–7", "Durchfall — zu schnelle Passage")

                Spacer(Modifier.height(8.dp))

                Text(
                    "Diese Informationen dienen der Selbstbeobachtung und ersetzen keine ärztliche Beratung.",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Fertig") }
        }
    )
}

@Composable
private fun BristolLegendRow(color: Color, label: String, desc: String) {
    Row(Modifier.padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("●", color = color, fontSize = 12.sp)
        Column {
            Text(label, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            Text(desc, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
