package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.ceil
import kotlin.math.floor

// ==================== NACHBESTELLUNG (2.9, Parität zu iOS 4.21) ====================

private const val SUPPLY_PREFS = "bb_data"
private val supplyJson = Json { ignoreUnknownKeys = true }
private fun supplyNowIso(): String = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

/**
 * Optionaler Bestand steriler Kompressen. Gezählt wird in 2er-Packs:
 * jede Blasenentleerung verbraucht genau ein 2er-Pack. Gleiches selbstheilendes
 * Zählprinzip wie beim Katheterbestand: Bestand = Korrekturwert − Entleerungen seither.
 */
@Serializable
data class CompressStock(
    val enabled: Boolean = false,
    /** Bezeichnung, wie sie in der Bestellung steht; leer = Standardbezeichnung. */
    val name: String = "",
    val stockAtAdjustment: Int = 0,
    val adjustmentDate: String = supplyNowIso(),
    /** 2er-Packs je Packung/Karton (für die Bestellmenge). */
    val packSize: Int = 50
) {
    companion object {
        private const val KEY = "compress_stock"
        const val DEFAULT_NAME = "Sterile Kompressen 10 × 10 cm, 2er-Pack"

        fun load(context: Context): CompressStock {
            val data = context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return CompressStock()
            return try { supplyJson.decodeFromString(data) } catch (_: Exception) { CompressStock() }
        }
    }

    fun save(context: Context) {
        context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).edit().putString(KEY, Json.encodeToString(this)).apply()
    }

    val displayName: String get() = name.trim().ifEmpty { tr(DEFAULT_NAME) }

    private val adjustment: LocalDateTime
        get() = runCatching { LocalDateTime.parse(adjustmentDate, DateTimeFormatter.ISO_LOCAL_DATE_TIME) }.getOrDefault(LocalDateTime.MIN)

    fun usedSince(entries: List<ToiletEntry>): Int {
        val adj = adjustment
        return entries.count { it.urineMl > 0 && it.dateTime.isAfter(adj) }
    }

    /** Aktueller rechnerischer Bestand in 2er-Packs, nie negativ. */
    fun currentStock(entries: List<ToiletEntry>): Int = maxOf(0, stockAtAdjustment - usedSince(entries))

    fun daysRemaining(entries: List<ToiletEntry>, today: LocalDate = LocalDate.now()): Int? {
        val usage = SupplyUsage.dailyVoids(entries, today) ?: return null
        if (usage <= 0) return null
        return (currentStock(entries) / usage).toInt()
    }

    fun withStock(value: Int): CompressStock = copy(stockAtAdjustment = maxOf(0, value), adjustmentDate = supplyNowIso())

    fun withDelivery(packs: Int, entries: List<ToiletEntry>): CompressStock = withStock(currentStock(entries) + maxOf(0, packs))
}

object SupplyUsage {
    /** Ø Blasenentleerungen pro Tag (letzte 14 volle Tage, nur Tage mit Einträgen, min. 3 Datentage). */
    fun dailyVoids(entries: List<ToiletEntry>, today: LocalDate = LocalDate.now()): Double? {
        val perDay = entries.filter { it.urineMl > 0 }.groupingBy { it.dateTime.toLocalDate() }.eachCount()
        val counts = (1..14).mapNotNull { i -> perDay[today.minusDays(i.toLong())] }
        if (counts.size < 3) return null
        return counts.sum().toDouble() / counts.size
    }
}

enum class OrderRecipient(val label: String) {
    SUPPLIER("Versorger"),
    PRACTICE("Praxis"),
    BOTH("Beide")
}

/** Adressen und Angaben für die Bestell-Mail. */
@Serializable
data class OrderSettings(
    val supplierEmail: String = "",
    val customerNumber: String = "",
    val practiceEmail: String = "",
    val patientName: String = "",
    val birthDate: String = "",
    /** Für wie viele Tage bestellt wird. */
    val orderDays: Int = 30,
    /** Zuletzt gewählter Empfänger (Name von OrderRecipient). */
    val lastRecipient: String = OrderRecipient.SUPPLIER.name
) {
    companion object {
        private const val KEY = "order_settings"

        fun load(context: Context): OrderSettings {
            val data = context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return OrderSettings()
            return try { supplyJson.decodeFromString(data) } catch (_: Exception) { OrderSettings() }
        }
    }

    fun save(context: Context) {
        context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).edit().putString(KEY, Json.encodeToString(this)).apply()
    }

    val recipient: OrderRecipient
        get() = runCatching { OrderRecipient.valueOf(lastRecipient) }.getOrDefault(OrderRecipient.SUPPLIER)
}

/** Merker „bestellt am“ — bewusst getrennt von OrderSettings gespeichert. */
object OrderState {
    private const val KEY = "order_ordered_on"
    /** So lange gilt eine Bestellung als unterwegs; danach erinnert die App wieder. */
    const val PENDING_DAYS = 21

    fun orderedOn(context: Context): LocalDate? =
        context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

    fun markOrdered(context: Context, date: LocalDate = LocalDate.now()) {
        context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).edit().putString(KEY, date.toString()).apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(SUPPLY_PREFS, Context.MODE_PRIVATE).edit().putString(KEY, "").apply()
    }

    fun isPending(orderedOn: LocalDate?, today: LocalDate): Boolean =
        orderedOn != null && today.isBefore(orderedOn.plusDays(PENDING_DAYS.toLong()))

    fun isPending(context: Context, today: LocalDate = LocalDate.now()): Boolean = isPending(orderedOn(context), today)
}

enum class OrderLineKind { CATHETER, COMPRESS }

data class OrderLine(
    val id: String,
    val kind: OrderLineKind,
    val name: String,
    /** Stück (Katheter) bzw. 2er-Packs (Kompressen) je Packung. */
    val packSize: Int,
    val packs: Int
) {
    val pieces: Int get() = packs * packSize
}

data class SupplyStatus(val catheterDays: Int?, val compressDays: Int?, val warnDays: Int) {
    val catheterLow: Boolean get() = catheterDays?.let { it <= warnDays } ?: false
    val compressLow: Boolean get() = compressDays?.let { it <= warnDays } ?: false
    val isDue: Boolean get() = catheterLow || compressLow
}

object OrderPlan {
    /** Zeitraum, aus dem der Sortenmix abgeleitet wird. */
    const val MIX_DAYS = 30

    /** Reichweiten gegen die gemeinsame Warnschwelle. Kompressen zählen nur bei aktivem Katheterbestand. */
    fun status(catheter: CatheterStock, compress: CompressStock, entries: List<ToiletEntry>): SupplyStatus {
        if (!catheter.enabled) return SupplyStatus(null, null, catheter.warnDays)
        return SupplyStatus(
            catheterDays = catheter.daysRemaining(entries),
            compressDays = if (compress.enabled) compress.daysRemaining(entries) else null,
            warnDays = catheter.warnDays
        )
    }

    /** Entleerungen je Sorte in den letzten 30 Tagen. Ohne Daten bekommt die Standardsorte alles. */
    fun mixCounts(catheter: CatheterStock, entries: List<ToiletEntry>, now: LocalDateTime = LocalDateTime.now()): List<Pair<CatheterSort, Int>> {
        val sorts = catheter.effectiveSorts
        val from = now.minusDays(MIX_DAYS.toLong())
        val window = entries.filter { it.urineMl > 0 }.filter { val t = it.dateTime; t.isAfter(from) && !t.isAfter(now) }
        val result = sorts.map { sort -> sort to window.count { catheter.belongs(it, sort) } }
        if (result.sumOf { it.second } == 0 && result.isNotEmpty()) {
            val defaultId = catheter.defaultSort.id
            return result.map { (sort, _) -> sort to (if (sort.id == defaultId) 1 else 0) }
        }
        return result
    }

    /** Verteilt total Stück im Verhältnis der Gewichte (größter Rest), Summe exakt total. */
    fun distribute(total: Int, weights: List<Int>): List<Int> {
        val sum = weights.sum()
        if (sum <= 0 || total <= 0) return weights.map { 0 }
        val exact = weights.map { total.toDouble() * it / sum }
        val parts = exact.map { floor(it).toInt() }.toMutableList()
        var rest = total - parts.sum()
        val order = exact.indices.sortedByDescending { exact[it] - floor(exact[it]) }
        for (i in order) {
            if (rest <= 0) break
            parts[i] += 1
            rest -= 1
        }
        return parts
    }

    /**
     * Bestellvorschlag: Bedarf für orderDays Tage aus dem Ø-Verbrauch, Katheter im Sortenmix
     * der letzten 30 Tage, je Position auf ganze Packungen aufgerundet.
     * Ohne Verbrauchsdaten: eine Packung je Position.
     */
    fun lines(catheter: CatheterStock, compress: CompressStock, orderDays: Int, entries: List<ToiletEntry>,
              now: LocalDateTime = LocalDateTime.now()): List<OrderLine> {
        if (!catheter.enabled) return emptyList()
        val usage = SupplyUsage.dailyVoids(entries, now.toLocalDate())
        val need: Int? = usage?.let { ceil(it * orderDays).toInt() }
        val mix = mixCounts(catheter, entries, now)
        val cathPack = maxOf(1, catheter.packSize)
        val shares = if (need != null) distribute(need, mix.map { it.second }) else mix.map { if (it.second > 0) 1 else 0 }
        val result = mutableListOf<OrderLine>()
        mix.forEachIndexed { i, (sort, _) ->
            if (shares[i] > 0) {
                val packs = if (need == null) 1 else ceil(shares[i].toDouble() / cathPack).toInt()
                var title = sort.name
                if (sort.sizeCharriere > 0) title += ", Ch ${sort.sizeCharriere}"
                if (sort.material.isNotBlank()) title += ", ${sort.material.trim()}"
                result.add(OrderLine(sort.id, OrderLineKind.CATHETER, title, cathPack, packs))
            }
        }
        if (compress.enabled) {
            val compPack = maxOf(1, compress.packSize)
            val packs = need?.let { ceil(it.toDouble() / compPack).toInt() } ?: 1
            result.add(OrderLine("compress", OrderLineKind.COMPRESS, compress.displayName, compPack, maxOf(1, packs)))
        }
        return result
    }
}

object OrderMail {
    fun subject(settings: OrderSettings): String {
        val base = tr("Nachbestellung Hilfsmittel")
        val name = settings.patientName.trim()
        return if (name.isEmpty()) base else "$base – $name"
    }

    fun recipients(recipient: OrderRecipient, settings: OrderSettings): List<String> {
        val supplier = settings.supplierEmail.trim()
        val practice = settings.practiceEmail.trim()
        return when (recipient) {
            OrderRecipient.SUPPLIER -> listOf(supplier)
            OrderRecipient.PRACTICE -> listOf(practice)
            OrderRecipient.BOTH -> listOf(supplier, practice)
        }.filter { it.isNotEmpty() }
    }

    fun lineText(line: OrderLine): String =
        if (line.packs == 1) trf("– {0} Packung {1} (je {2} Stück, zusammen {3})", line.packs, line.name, line.packSize, line.pieces)
        else trf("– {0} Packungen {1} (je {2} Stück, zusammen {3})", line.packs, line.name, line.packSize, line.pieces)

    fun body(lines: List<OrderLine>, recipient: OrderRecipient, settings: OrderSettings): String {
        val (intro, closing) = when (recipient) {
            OrderRecipient.SUPPLIER -> tr("ich möchte folgende Hilfsmittel nachbestellen:") to
                tr("Bitte liefern Sie an die bekannte Adresse.")
            OrderRecipient.PRACTICE -> tr("ich bitte um eine Folgeverordnung über folgende Hilfsmittel:") to
                tr("Bitte geben Sie mir kurz Bescheid, sobald die Verordnung bereitliegt.")
            OrderRecipient.BOTH -> tr("ich benötige Nachschub an folgenden Hilfsmitteln:") to
                tr("An die Praxis: Bitte stellen Sie die Folgeverordnung aus. An den Versorger: Bitte liefern Sie an die bekannte Adresse, sobald die Verordnung vorliegt.")
        }
        val parts = mutableListOf(tr("Guten Tag,"), "", intro, "")
        parts.addAll(lines.map { lineText(it) })
        parts.add("")
        parts.add(closing)

        val name = settings.patientName.trim()
        val birth = settings.birthDate.trim()
        val customer = settings.customerNumber.trim()
        val facts = mutableListOf<String>()
        if (name.isNotEmpty()) facts.add(trf("Name: {0}", name))
        if (birth.isNotEmpty()) facts.add(trf("Geburtsdatum: {0}", birth))
        // Die Kundennummer geht nur an den Versorger, nie allein an die Praxis.
        if (customer.isNotEmpty() && recipient != OrderRecipient.PRACTICE) facts.add(trf("Kundennummer: {0}", customer))
        if (facts.isNotEmpty()) {
            parts.add("")
            parts.addAll(facts)
        }
        parts.add("")
        parts.add(tr("Vielen Dank und freundliche Grüße"))
        if (name.isNotEmpty()) parts.add(name)
        return parts.joinToString("\n")
    }
}
