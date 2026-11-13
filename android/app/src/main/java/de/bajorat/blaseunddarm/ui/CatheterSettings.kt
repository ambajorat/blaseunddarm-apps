package de.bajorat.blaseunddarm.ui

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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.bajorat.blaseunddarm.data.BDMDataStore
import de.bajorat.blaseunddarm.data.CatheterSort
import de.bajorat.blaseunddarm.data.CatheterStock
import de.bajorat.blaseunddarm.data.ProductCategory
import de.bajorat.blaseunddarm.data.ToiletEntry
import de.bajorat.blaseunddarm.data.tr
import de.bajorat.blaseunddarm.data.trf
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ==================== KATHETERBESTAND MIT SORTEN (2.8, Parität zu iOS 4.10/4.11/4.14) ====================

private val prescriptionInput: DateTimeFormatter = DateTimeFormatter.ofPattern("d.M.uuuu")
private val prescriptionShow: DateTimeFormatter = DateTimeFormatter.ofPattern("dd.MM.uuuu")

@Composable
fun CatheterSettingsCard(entries: List<ToiletEntry>, dataStore: BDMDataStore) {
    val context = LocalContext.current
    var catheter by remember { mutableStateOf(CatheterStock.load(context)) }
    fun update(c: CatheterStock) { catheter = c; c.save(context) }
    val muted = MaterialTheme.colorScheme.onSurfaceVariant

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("Katheterbestand"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                if (catheter.enabled) {
                    ScanButton(category = ProductCategory.catheter) { /* Katalog füllen */ }
                }
                Switch(checked = catheter.enabled, onCheckedChange = { update(catheter.copy(enabled = it)) })
            }
            if (catheter.enabled) {
                val sorts = catheter.effectiveSorts
                val multi = sorts.size > 1
                Spacer(Modifier.height(8.dp))
                val current = catheter.currentStock(entries)
                Text(trf("Aktueller Bestand: {0} Stück", current), fontSize = 14.sp)
                val days = catheter.daysRemaining(entries)
                val empty = catheter.estimatedEmptyDate(entries)
                if (days != null && empty != null) {
                    Text(
                        trf("Reicht etwa {0} Tage — bis ca. {1}", days, empty.format(DateTimeFormatter.ofPattern("d.M."))),
                        fontSize = 12.sp,
                        color = if (days <= catheter.warnDays) MaterialTheme.colorScheme.error else muted
                    )
                } else if (current == 0 && sorts.all { it.stockAtAdjustment == 0 }) {
                    Text(tr("Trage deinen aktuellen Bestand ein, um zu starten."), fontSize = 12.sp, color = muted)
                } else {
                    Text(tr("Reichweite erscheint nach ein paar Tagen mit Einträgen."), fontSize = 12.sp, color = muted)
                }

                sorts.forEach { sort ->
                    key(sort.id) {
                        Spacer(Modifier.height(10.dp))
                        HorizontalDivider()
                        Spacer(Modifier.height(10.dp))
                        SortBlock(
                            sort = sort,
                            stock = catheter.stock(sort, entries),
                            multi = multi,
                            isDefault = catheter.defaultSort.id == sort.id,
                            packSize = catheter.packSize,
                            isNameFree = { catheter.isNameFree(it, sort.id) },
                            onRename = { newName ->
                                val oldName = sort.name
                                update(catheter.withSortUpdated(sort.copy(name = newName)))
                                dataStore.renameCatheterSort(oldName, newName)
                            },
                            onChange = { update(catheter.withSortUpdated(it)) },
                            onSetStock = { update(catheter.withStock(it, sort.id)) },
                            onAddPack = { update(catheter.withPackAdded(entries, sort.id)) },
                            onDelivery = { update(catheter.withDelivery(it, entries, sort.id)) },
                            onDefault = { update(catheter.ensureSorts().copy(defaultSortId = sort.id)) },
                            onRemove = { update(catheter.withSortRemoved(sort.id)) }
                        )
                    }
                }

                Spacer(Modifier.height(10.dp))
                HorizontalDivider()
                Spacer(Modifier.height(6.dp))
                TextButton(onClick = { update(catheter.withSortAdded()) }) { Text(tr("+ Sorte hinzufügen")) }
                if (multi) {
                    Text(tr("Bei mehreren Sorten wählst du die Sorte beim Erfassen. Vorbelegt ist die Standardsorte."), fontSize = 11.sp, color = muted)
                }

                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(trf("Warnen unter {0} Tagen", catheter.warnDays), fontSize = 14.sp, modifier = Modifier.weight(1f))
                    OutlinedButton(onClick = {
                        if (catheter.warnDays > 3) update(catheter.copy(warnDays = catheter.warnDays - 1))
                    }, enabled = catheter.warnDays > 3, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
                    Spacer(Modifier.width(8.dp))
                    OutlinedButton(onClick = {
                        if (catheter.warnDays < 30) update(catheter.copy(warnDays = catheter.warnDays + 1))
                    }, enabled = catheter.warnDays < 30, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
                }

                // Rezept (ein gemeinsames Rezept für alle Sorten)
                Spacer(Modifier.height(8.dp))
                val rxDate = catheter.prescriptionLocalDate
                var rxInput by remember { mutableStateOf("") }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Rezept-Erinnerung"), fontSize = 14.sp, modifier = Modifier.weight(1f))
                    Switch(checked = rxDate != null, onCheckedChange = { on ->
                        update(catheter.copy(prescriptionDate = if (on) LocalDate.now().plusMonths(3).toString() else ""))
                    })
                }
                if (rxDate != null) {
                    val left = catheter.prescriptionDaysLeft() ?: 0
                    Text(
                        if (left >= 0) trf("Rezept: noch {0} Tage (bis {1})", left, rxDate.format(prescriptionShow))
                        else trf("Rezept abgelaufen am {0}", rxDate.format(prescriptionShow)),
                        fontSize = 12.sp,
                        color = if (left <= 14) MaterialTheme.colorScheme.error else muted
                    )
                    Spacer(Modifier.height(6.dp))
                    val parsed = runCatching { LocalDate.parse(rxInput.trim(), prescriptionInput) }.getOrNull()
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = rxInput,
                            onValueChange = { rxInput = it.filter { c -> c.isDigit() || c == '.' } },
                            modifier = Modifier.weight(1f),
                            placeholder = { Text(tr("Rezept läuft aus (TT.MM.JJJJ)")) },
                            singleLine = true
                        )
                        Button(onClick = {
                            parsed?.let { update(catheter.copy(prescriptionDate = it.toString())); rxInput = "" }
                        }, enabled = parsed != null) { Text(tr("OK")) }
                    }
                }

                Spacer(Modifier.height(8.dp))
                Text(tr("Jeder Blaseneintrag zählt als eine Katheterisierung."), fontSize = 11.sp, color = muted)
            }
        }
    }
}

/** Bedienzeilen für EINE Kathetersorte: Name, Bestand, Korrektur, Packung, Lieferung, Ch, Material. */
@Composable
private fun SortBlock(
    sort: CatheterSort,
    stock: Int,
    multi: Boolean,
    isDefault: Boolean,
    packSize: Int,
    isNameFree: (String) -> Boolean,
    onRename: (String) -> Unit,
    onChange: (CatheterSort) -> Unit,
    onSetStock: (Int) -> Unit,
    onAddPack: () -> Unit,
    onDelivery: (Int) -> Unit,
    onDefault: () -> Unit,
    onRemove: () -> Unit
) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    var nameInput by remember(sort.name) { mutableStateOf(sort.name) }
    var stockInput by remember { mutableStateOf("") }
    var deliveryInput by remember { mutableStateOf("") }
    var materialInput by remember { mutableStateOf(sort.material) }

    if (multi) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(sort.name, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, modifier = Modifier.weight(1f), maxLines = 1)
            Text(trf("{0} Stück", stock), fontSize = 13.sp, color = muted)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            FilterChip(selected = isDefault, onClick = onDefault, label = { Text(tr("Standardsorte"), fontSize = 11.sp) })
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onRemove) { Text(tr("Sorte entfernen"), color = MaterialTheme.colorScheme.error, fontSize = 12.sp) }
        }
        val newName = nameInput.trim()
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = nameInput,
                onValueChange = { nameInput = it.replace(";", "").take(30) },
                modifier = Modifier.weight(1f),
                label = { Text(tr("Name der Sorte")) },
                singleLine = true
            )
            Button(onClick = { onRename(newName) }, enabled = newName != sort.name && isNameFree(newName)) { Text(tr("OK")) }
        }
        Spacer(Modifier.height(8.dp))
    }

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = stockInput,
            onValueChange = { stockInput = it.filter { c -> c.isDigit() } },
            modifier = Modifier.weight(1f),
            placeholder = { Text(tr("Bestand eintragen")) },
            singleLine = true
        )
        Button(onClick = {
            stockInput.toIntOrNull()?.let { onSetStock(it); stockInput = "" }
        }, enabled = stockInput.toIntOrNull() != null) { Text(tr("OK")) }
    }
    Spacer(Modifier.height(8.dp))
    OutlinedButton(onClick = onAddPack, modifier = Modifier.fillMaxWidth()) {
        Text(trf("+1 Packung ({0} Stück)", packSize))
    }
    Spacer(Modifier.height(8.dp))
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = deliveryInput,
            onValueChange = { deliveryInput = it.filter { c -> c.isDigit() } },
            modifier = Modifier.weight(1f),
            placeholder = { Text(tr("Lieferung erfassen (Stück)")) },
            singleLine = true
        )
        Button(onClick = {
            deliveryInput.toIntOrNull()?.let { onDelivery(it); deliveryInput = "" }
        }, enabled = (deliveryInput.toIntOrNull() ?: 0) > 0) { Text(tr("OK")) }
    }
    Spacer(Modifier.height(8.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            tr("Charrière (Ch)") + ": " + (if (sort.sizeCharriere > 0) "Ch ${sort.sizeCharriere}" else "—"),
            fontSize = 14.sp, modifier = Modifier.weight(1f)
        )
        // 0 = nicht angegeben; gültig sind 6–24
        OutlinedButton(onClick = {
            onChange(sort.copy(sizeCharriere = if (sort.sizeCharriere <= 6) 0 else sort.sizeCharriere - 1))
        }, enabled = sort.sizeCharriere > 0, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("−")) }
        Spacer(Modifier.width(8.dp))
        OutlinedButton(onClick = {
            onChange(sort.copy(sizeCharriere = if (sort.sizeCharriere == 0) 12 else sort.sizeCharriere + 1))
        }, enabled = sort.sizeCharriere < 24, contentPadding = PaddingValues(0.dp), modifier = Modifier.size(40.dp)) { Text(tr("+")) }
    }
    Spacer(Modifier.height(8.dp))
    OutlinedTextField(
        value = materialInput,
        onValueChange = {
            materialInput = it.take(40)
            onChange(sort.copy(material = materialInput.trim()))
        },
        modifier = Modifier.fillMaxWidth(),
        label = { Text(tr("Material (optional)")) },
        singleLine = true
    )
}
