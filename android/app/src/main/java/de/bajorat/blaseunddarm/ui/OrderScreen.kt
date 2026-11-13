package de.bajorat.blaseunddarm.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import de.bajorat.blaseunddarm.data.CatheterStock
import de.bajorat.blaseunddarm.data.CompressStock
import de.bajorat.blaseunddarm.data.OrderLine
import de.bajorat.blaseunddarm.data.OrderMail
import de.bajorat.blaseunddarm.data.OrderPlan
import de.bajorat.blaseunddarm.data.OrderRecipient
import de.bajorat.blaseunddarm.data.OrderSettings
import de.bajorat.blaseunddarm.data.OrderState
import de.bajorat.blaseunddarm.data.SupplyStatus
import de.bajorat.blaseunddarm.data.SupplyUsage
import de.bajorat.blaseunddarm.data.ToiletEntry
import de.bajorat.blaseunddarm.data.tr
import de.bajorat.blaseunddarm.data.trf
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ==================== NACHBESTELLUNG (2.9, Parität zu iOS 4.21) ====================

private val orderDate: DateTimeFormatter = DateTimeFormatter.ofPattern("dd.MM.uuuu")

private fun statusText(status: SupplyStatus): String? {
    val c = status.catheterDays
    val k = status.compressDays
    return when {
        c != null && k != null -> trf("Katheter reichen noch etwa {0} Tage, Kompressen etwa {1} Tage.", c, k)
        c != null -> trf("Katheter reichen noch etwa {0} Tage.", c)
        k != null -> trf("Kompressen reichen noch etwa {0} Tage.", k)
        else -> null
    }
}

/** Kleiner −/+-Zähler in der Art der übrigen Einstellungen. */
@Composable
private fun StepRow(label: String, canDec: Boolean, canInc: Boolean, onDec: () -> Unit, onInc: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 14.sp, modifier = Modifier.weight(1f))
        OutlinedButton(onClick = onDec, enabled = canDec, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
        Spacer(Modifier.width(8.dp))
        OutlinedButton(onClick = onInc, enabled = canInc, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
    }
}

/** Einstellungen: Karten „Kompressen“ und „Nachbestellung“, direkt unter dem Katheterbestand. */
@Composable
fun SupplySettingsCards(entries: List<ToiletEntry>) {
    val context = LocalContext.current
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    var compress by remember { mutableStateOf(CompressStock.load(context)) }
    var order by remember { mutableStateOf(OrderSettings.load(context)) }
    var showOrder by remember { mutableStateOf(false) }
    fun updateCompress(c: CompressStock) { compress = c; c.save(context) }
    fun updateOrder(o: OrderSettings) { order = o; o.save(context) }

    // ---- Kompressen ----
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("Kompressen"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Switch(checked = compress.enabled, onCheckedChange = { updateCompress(compress.copy(enabled = it)) })
            }
            if (!compress.enabled) {
                Text(tr("Optional: Zählt deine sterilen Kompressen mit — jede Blasenentleerung verbraucht ein 2er-Pack."), fontSize = 12.sp, color = muted)
            } else {
                var stockInput by remember { mutableStateOf("") }
                var deliveryInput by remember { mutableStateOf("") }
                var nameInput by remember { mutableStateOf(compress.name) }
                val current = compress.currentStock(entries)
                val days = compress.daysRemaining(entries)
                Spacer(Modifier.height(8.dp))
                Text(trf("{0} 2er-Packs Kompressen im Bestand", current), fontSize = 14.sp)
                Text(
                    when {
                        days != null -> trf("Ein 2er-Pack je Entleerung — reicht noch etwa {0} Tage.", days)
                        current == 0 && compress.stockAtAdjustment == 0 -> tr("Trage deinen aktuellen Bestand in 2er-Packs ein, um zu starten.")
                        else -> tr("Ein 2er-Pack je Entleerung. Die Reichweite erscheint nach ein paar Tagen mit Einträgen.")
                    },
                    fontSize = 12.sp, color = muted
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = nameInput,
                    onValueChange = { nameInput = it.take(60); updateCompress(compress.copy(name = nameInput.trim())) },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(tr("Bezeichnung")) },
                    placeholder = { Text(tr(CompressStock.DEFAULT_NAME)) },
                    singleLine = true
                )
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
                        stockInput.toIntOrNull()?.let { updateCompress(compress.withStock(it)); stockInput = "" }
                    }, enabled = stockInput.toIntOrNull() != null) { Text(tr("OK")) }
                }
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = deliveryInput,
                        onValueChange = { deliveryInput = it.filter { c -> c.isDigit() } },
                        modifier = Modifier.weight(1f),
                        placeholder = { Text(tr("Lieferung erfassen (2er-Packs)")) },
                        singleLine = true
                    )
                    Button(onClick = {
                        deliveryInput.toIntOrNull()?.let { updateCompress(compress.withDelivery(it, entries)); deliveryInput = "" }
                    }, enabled = (deliveryInput.toIntOrNull() ?: 0) > 0) { Text(tr("OK")) }
                }
                Spacer(Modifier.height(8.dp))
                StepRow(
                    trf("2er-Packs je Packung: {0}", compress.packSize),
                    canDec = compress.packSize > 5, canInc = compress.packSize < 500,
                    onDec = { updateCompress(compress.copy(packSize = maxOf(5, compress.packSize - 5))) },
                    onInc = { updateCompress(compress.copy(packSize = minOf(500, compress.packSize + 5))) }
                )
            }
        }
    }
    Spacer(Modifier.height(12.dp))

    // ---- Nachbestellung ----
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(tr("Nachbestellung"), fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(value = order.supplierEmail, onValueChange = { updateOrder(order.copy(supplierEmail = it.trim())) },
                modifier = Modifier.fillMaxWidth(), label = { Text(tr("Versorger") + " – " + tr("E-Mail")) }, singleLine = true)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(value = order.customerNumber, onValueChange = { updateOrder(order.copy(customerNumber = it)) },
                modifier = Modifier.fillMaxWidth(), label = { Text(tr("Kundennummer")) }, singleLine = true)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(value = order.practiceEmail, onValueChange = { updateOrder(order.copy(practiceEmail = it.trim())) },
                modifier = Modifier.fillMaxWidth(), label = { Text(tr("Praxis") + " – " + tr("E-Mail")) }, singleLine = true)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(value = order.patientName, onValueChange = { updateOrder(order.copy(patientName = it)) },
                modifier = Modifier.fillMaxWidth(), label = { Text(tr("Dein Name")) }, singleLine = true)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(value = order.birthDate, onValueChange = { updateOrder(order.copy(birthDate = it)) },
                modifier = Modifier.fillMaxWidth(), label = { Text(tr("Geburtsdatum")) }, singleLine = true)
            Spacer(Modifier.height(8.dp))
            StepRow(
                trf("Bestellen für {0} Tage", order.orderDays),
                canDec = order.orderDays > 10, canInc = order.orderDays < 90,
                onDec = { updateOrder(order.copy(orderDays = maxOf(10, order.orderDays - 5))) },
                onInc = { updateOrder(order.copy(orderDays = minOf(90, order.orderDays + 5))) }
            )
            Spacer(Modifier.height(8.dp))
            Button(onClick = { showOrder = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                Text(tr("Jetzt nachbestellen"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                trf("Reichen Katheter oder Kompressen für weniger als {0} Tage, erinnert dich die App ans Nachbestellen. Die Mail ist vorbereitet — abschicken tust du sie selbst.", CatheterStock.load(context).warnDays),
                fontSize = 11.sp, color = muted
            )
        }
    }

    if (showOrder) OrderDialog(entries) { showOrder = false; order = OrderSettings.load(context) }
}

private fun sendMail(context: Context, to: List<String>, subject: String, body: String) {
    val mail = Intent(Intent.ACTION_SENDTO).apply {
        data = Uri.parse("mailto:")
        putExtra(Intent.EXTRA_EMAIL, to.toTypedArray())
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, body)
    }
    try {
        context.startActivity(mail)
    } catch (_: Exception) {
        // Keine Mail-App eingerichtet → allgemeines Teilen
        shareText(context, subject, body)
    }
}

private fun shareText(context: Context, subject: String, body: String) {
    val share = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, body)
    }
    try {
        context.startActivity(Intent.createChooser(share, tr("Senden über …")))
    } catch (_: Exception) {
    }
}

/** Bestellvorschlag mit Empfängerwahl, Mengen, Nachrichtenvorschau und Versand. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OrderDialog(entries: List<ToiletEntry>, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val catheter = remember { CatheterStock.load(context) }
    val compress = remember { CompressStock.load(context) }
    var settings by remember { mutableStateOf(OrderSettings.load(context)) }
    var recipient by remember { mutableStateOf(settings.recipient) }
    var orderedOn by remember { mutableStateOf(OrderState.orderedOn(context)) }
    val baseLines = remember { OrderPlan.lines(catheter, compress, settings.orderDays, entries) }
    var packs by remember { mutableStateOf(baseLines.associate { it.id to it.packs }) }
    val usage = remember { SupplyUsage.dailyVoids(entries) }
    val status = remember { OrderPlan.status(catheter, compress, entries) }

    val lines: List<OrderLine> = baseLines.map { it.copy(packs = packs[it.id] ?: it.packs) }
    val mailLines = lines.filter { it.packs > 0 }
    val to = OrderMail.recipients(recipient, settings)
    val subject = OrderMail.subject(settings)
    val body = OrderMail.body(mailLines, recipient, settings)

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Nachbestellung"), fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
                    TextButton(onClick = onDismiss) { Text(tr("Schließen")) }
                }
                if (!catheter.enabled) {
                    Spacer(Modifier.height(12.dp))
                    Text(tr("Kein Bestand aktiv — schalte den Katheterbestand in den Einstellungen ein."), fontSize = 14.sp, color = muted)
                } else {
                    // Vorrat
                    Spacer(Modifier.height(8.dp))
                    Text(tr("Vorrat"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted)
                    Text(statusText(status) ?: tr("Reichweite folgt nach ein paar Tagen mit Einträgen"), fontSize = 14.sp,
                        color = if (status.isDue) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
                    val ordered = orderedOn
                    if (ordered != null) {
                        Text(trf("Bestellt am {0} — wartet auf Lieferung", ordered.format(orderDate)), fontSize = 12.sp, color = muted)
                    }

                    // Empfänger
                    Spacer(Modifier.height(14.dp))
                    Text(tr("Empfänger"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        OrderRecipient.entries.forEach { r ->
                            FilterChip(selected = recipient == r, onClick = {
                                recipient = r
                                settings = settings.copy(lastRecipient = r.name)
                                settings.save(context)
                            }, label = { Text(tr(r.label)) })
                        }
                    }
                    if (to.size < (if (recipient == OrderRecipient.BOTH) 2 else 1)) {
                        Text(tr("Für diese Auswahl fehlt eine E-Mail-Adresse — eintragen unter Einstellungen › Nachbestellung. Du kannst die Adresse auch direkt in der Mail ergänzen."),
                            fontSize = 12.sp, color = MaterialTheme.colorScheme.error)
                    }

                    // Bestellung
                    Spacer(Modifier.height(14.dp))
                    Text(tr("Bestellung"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted)
                    lines.forEach { line ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(line.name, fontSize = 14.sp)
                                Text(
                                    if (line.packs == 1) trf("{0} Packung · {1} Stück", line.packs, line.pieces)
                                    else trf("{0} Packungen · {1} Stück", line.packs, line.pieces),
                                    fontSize = 12.sp, color = muted
                                )
                            }
                            OutlinedButton(onClick = { packs = packs + (line.id to maxOf(0, line.packs - 1)) }, enabled = line.packs > 0,
                                contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
                            Spacer(Modifier.width(8.dp))
                            OutlinedButton(onClick = { packs = packs + (line.id to minOf(99, line.packs + 1)) }, enabled = line.packs < 99,
                                contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
                        }
                        HorizontalDivider()
                    }
                    Text(
                        if (usage != null) trf("Bedarf für {0} Tage bei Ø {1} Entleerungen pro Tag, auf ganze Packungen aufgerundet. Sortenmix nach deinem Verbrauch der letzten 30 Tage.", settings.orderDays, "%.1f".format(usage))
                        else tr("Noch zu wenige Einträge für eine Bedarfsrechnung — vorgeschlagen ist je eine Packung. Passe die Mengen an."),
                        fontSize = 11.sp, color = muted, modifier = Modifier.padding(top = 6.dp)
                    )

                    // Nachricht
                    Spacer(Modifier.height(14.dp))
                    Text(tr("Nachricht"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted)
                    Card(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                        Text(body, fontSize = 12.sp, modifier = Modifier.padding(12.dp))
                    }

                    // Versand
                    Spacer(Modifier.height(14.dp))
                    Button(onClick = { sendMail(context, to, subject, body) }, enabled = mailLines.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                        Text(tr("Als E-Mail senden"), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                    }
                    Spacer(Modifier.height(6.dp))
                    OutlinedButton(onClick = { shareText(context, subject, body) }, enabled = mailLines.isNotEmpty(), modifier = Modifier.fillMaxWidth()) {
                        Text(tr("Senden über …"))
                    }
                    Spacer(Modifier.height(6.dp))
                    if (ordered == null) {
                        OutlinedButton(onClick = { OrderState.markOrdered(context); orderedOn = LocalDate.now() }, modifier = Modifier.fillMaxWidth()) {
                            Text(tr("Als bestellt markieren"))
                        }
                    } else {
                        TextButton(onClick = { OrderState.clear(context); orderedOn = null }) { Text(tr("Zurücksetzen")) }
                    }
                    Text(tr("Tippe nach dem Absenden auf „Als bestellt markieren“. Bis die Lieferung eingebucht ist, erinnert die App dann nicht erneut."),
                        fontSize = 11.sp, color = muted, modifier = Modifier.padding(top = 6.dp))
                }
                Spacer(Modifier.height(40.dp))
            }
        }
    }
}

/** Statistik: Kompressenbestand + Bestellstatus, unter der Katheter-Karte. */
@Composable
fun SupplyStatusCard(entries: List<ToiletEntry>) {
    val context = LocalContext.current
    val catheter = CatheterStock.load(context)
    if (!catheter.enabled) return
    val compress = CompressStock.load(context)
    val status = OrderPlan.status(catheter, compress, entries)
    var orderedOn by remember { mutableStateOf(OrderState.orderedOn(context)) }
    var showOrder by remember { mutableStateOf(false) }
    val pending = OrderState.isPending(orderedOn, LocalDate.now())
    if (!compress.enabled && !status.isDue && !pending) return
    val muted = MaterialTheme.colorScheme.onSurfaceVariant

    Spacer(Modifier.height(12.dp))
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            if (compress.enabled) {
                Text(trf("{0} 2er-Packs Kompressen im Bestand", compress.currentStock(entries)), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                val days = status.compressDays
                Text(
                    if (days != null) trf("Reicht etwa {0} Tage", days) else tr("Reichweite folgt nach ein paar Tagen mit Einträgen"),
                    fontSize = 12.sp, color = if (status.compressLow) MaterialTheme.colorScheme.error else muted
                )
            } else {
                Text(tr("Nachbestellung"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            }
            val ordered = orderedOn
            if (pending && ordered != null) {
                Text(trf("Bestellt am {0} — wartet auf Lieferung", ordered.format(orderDate)), fontSize = 12.sp, color = muted, modifier = Modifier.padding(top = 4.dp))
            } else if (status.isDue) {
                statusText(status)?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 4.dp)) }
                TextButton(onClick = { showOrder = true }, contentPadding = PaddingValues(0.dp)) { Text(tr("Jetzt nachbestellen")) }
            }
        }
    }
    if (showOrder) OrderDialog(entries) { showOrder = false; orderedOn = OrderState.orderedOn(context) }
}

/** Ist der Vorrat knapp und keine Bestellung unterwegs? (für den Hinweise-Reiter) */
fun supplyOrderDue(context: Context, entries: List<ToiletEntry>): Boolean {
    val catheter = CatheterStock.load(context)
    if (!catheter.enabled) return false
    return OrderPlan.status(catheter, CompressStock.load(context), entries).isDue && !OrderState.isPending(context)
}

/** Hinweise-Reiter: nur sichtbar, wenn der Vorrat knapp ist und keine Bestellung läuft. */
@Composable
fun SupplyOrderAlertCard(entries: List<ToiletEntry>) {
    val context = LocalContext.current
    val catheter = CatheterStock.load(context)
    if (!catheter.enabled) return
    val status = OrderPlan.status(catheter, CompressStock.load(context), entries)
    var orderedOn by remember { mutableStateOf(OrderState.orderedOn(context)) }
    var showOrder by remember { mutableStateOf(false) }
    if (!status.isDue || OrderState.isPending(orderedOn, LocalDate.now())) return

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("Nachbestellung"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(8.dp))
            statusText(status)?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error) }
            Spacer(Modifier.height(8.dp))
            Button(onClick = { showOrder = true }, colors = ButtonDefaults.buttonColors(containerColor = Orange)) {
                Text(tr("Jetzt nachbestellen"), color = MaterialTheme.colorScheme.onPrimary)
            }
        }
    }
    if (showOrder) OrderDialog(entries) { showOrder = false; orderedOn = OrderState.orderedOn(context) }
}
