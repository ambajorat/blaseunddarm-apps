package de.bajorat.blaseunddarm.ui

import de.bajorat.blaseunddarm.data.tr

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
    BristolInfo(tr("Typ 1"), tr("Einzelne harte Klumpen"), tr("Einzelne, harte Klumpen wie Nüsse. Schwer auszuscheiden. Zeichen für starke Verstopfung."), tr("Verstopfung"), Orange),
    BristolInfo(tr("Typ 2"), tr("Wurstartig, klumpig"), tr("Wurstartig, aber klumpig zusammengesetzt. Zeichen für leichte Verstopfung."), tr("Verstopfung"), Orange),
    BristolInfo(tr("Typ 3"), tr("Wurstartig, rissig"), tr("Wie eine Wurst mit Rissen an der Oberfläche. Normal."), tr("Normal"), Color(0xFF5A9A6E)),
    BristolInfo(tr("Typ 4"), tr("Glatt und weich"), tr("Wie eine Wurst oder Schlange, glatt und weich. Ideale Form."), tr("Normal — Ideal"), Color(0xFF5A9A6E)),
    BristolInfo(tr("Typ 5"), tr("Weiche Klümpchen"), tr("Weiche Klümpchen mit klaren Rändern. Neigung zu Durchfall."), tr("Durchfall"), Color(0xFFC0392B)),
    BristolInfo(tr("Typ 6"), tr("Breiig, aufgelöst"), tr("Breiige Konsistenz mit unscharfen Rändern. Leichter Durchfall."), tr("Durchfall"), Color(0xFFC0392B)),
    BristolInfo(tr("Typ 7"), tr("Wässrig, flüssig"), tr("Wässrig, keine festen Bestandteile. Starker Durchfall."), tr("Durchfall"), Color(0xFFC0392B)),
)

@Composable
fun BristolInfoDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(tr("Bristol-Stuhlformen-Skala"), fontWeight = FontWeight.Bold) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    tr("Die Bristol-Skala wurde 1997 an der Universität Bristol entwickelt und ist ein medizinisches Hilfsmittel zur Klassifikation der Stuhlform."),
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
                                    tr("Typ 1") -> R.drawable.bristol_type1
                                    tr("Typ 2") -> R.drawable.bristol_type2
                                    tr("Typ 3") -> R.drawable.bristol_type3
                                    tr("Typ 4") -> R.drawable.bristol_type4
                                    tr("Typ 5") -> R.drawable.bristol_type5
                                    tr("Typ 6") -> R.drawable.bristol_type6
                                    tr("Typ 7") -> R.drawable.bristol_type7
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

                Text(tr("Bedeutung"), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                BristolLegendRow(Orange, tr("Typ 1–2"), tr("Verstopfung — zu wenig Flüssigkeit oder Ballaststoffe"))
                BristolLegendRow(Color(0xFF5A9A6E), tr("Typ 3–4"), tr("Normal — ideale Stuhlform, gesunde Verdauung"))
                BristolLegendRow(Color(0xFFC0392B), tr("Typ 5–7"), tr("Durchfall — zu schnelle Passage"))

                Spacer(Modifier.height(8.dp))

                Text(
                    tr("Diese Informationen dienen der Selbstbeobachtung und ersetzen keine ärztliche Beratung."),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(tr("Fertig")) }
        }
    )
}

@Composable
private fun BristolLegendRow(color: Color, label: String, desc: String) {
    Row(Modifier.padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("●"), color = color, fontSize = 12.sp)
        Column {
            Text(label, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            Text(desc, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
