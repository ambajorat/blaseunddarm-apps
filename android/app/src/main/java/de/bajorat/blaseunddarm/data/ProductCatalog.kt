package de.bajorat.blaseunddarm.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID

// MARK: - Gescanntes Produkt (Medikament oder Katheter)

enum class ProductCategory { medication, catheter }

@Serializable
data class ScannedProduct(
    val id: String = UUID.randomUUID().toString(),
    val barcode: String? = null,
    val name: String,
    val category: String, // "medication" / "catheter"
    val charriere: Int? = null,
    val material: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

// MARK: - Katalog (lokaler Speicher)

@Serializable
data class ProductCatalog(
    val products: MutableList<ScannedProduct> = mutableListOf()
) {
    companion object {
        private const val PREFS = "bb_data"
        private const val KEY = "bb_product_catalog"
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context): ProductCatalog {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = prefs.getString(KEY, null) ?: return ProductCatalog()
            return try { json.decodeFromString(data) } catch (_: Exception) { ProductCatalog() }
        }
    }

    fun save(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY, Json.encodeToString(this)).apply()
    }

    // Barcode-Suche
    fun find(barcode: String): ScannedProduct? =
        products.firstOrNull { it.barcode == barcode }

    // Kategorie-Filter
    fun products(category: ProductCategory): List<ScannedProduct> =
        products.filter { it.category == category.name }
            .sortedByDescending { it.createdAt }

    // Upsert: gleicher Barcode → Update, sonst Insert
    fun upsert(
        context: Context,
        barcode: String?, name: String,
        category: ProductCategory,
        charriere: Int? = null,
        material: String? = null
    ): ScannedProduct {
        if (barcode != null) {
            val idx = products.indexOfFirst { it.barcode == barcode }
            if (idx >= 0) {
                products[idx] = products[idx].copy(
                    name = name,
                    charriere = charriere ?: products[idx].charriere,
                    material = material ?: products[idx].material
                )
                save(context)
                return products[idx]
            }
        }
        val product = ScannedProduct(
            barcode = barcode, name = name,
            category = category.name,
            charriere = charriere, material = material
        )
        products.add(product)
        save(context)
        return product
    }

    fun remove(context: Context, id: String) {
        products.removeAll { it.id == id }
        save(context)
    }
}

// MARK: - OCR-Helfer: Charrière aus Text

fun extractCharriere(text: String): Int? {
    val patterns = listOf(
        Regex("""(?i)\b(?:ch|charrière|charriere|fr)[.\s]*(\d{1,2})\b"""),
        Regex("""(?i)\b(\d{1,2})\s*(?:ch|charrière|charriere|fr)\b""")
    )
    for (pattern in patterns) {
        val match = pattern.find(text) ?: continue
        val value = match.groupValues[1].toIntOrNull() ?: continue
        if (value in 6..24) return value
    }
    return null
}

// MARK: - OCR-Helfer: Material aus Text

fun extractMaterial(text: String): String? {
    val lower = text.lowercase()
    val keywords = listOf(
        "hydrophil" to "hydrophil beschichtet",
        "hydrophilic" to "hydrophil beschichtet",
        "nelaton" to "Nelaton",
        "tiemann" to "Tiemann",
        "pvc" to "PVC",
        "silikon" to "Silikon",
        "silicon" to "Silikon",
        "latex" to "Latex"
    )
    for ((search, label) in keywords) {
        if (lower.contains(search)) return label
    }
    return null
}
