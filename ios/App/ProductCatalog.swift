import Foundation

// MARK: - Gescanntes Produkt (Medikament oder Katheter)

/// Ein vom Nutzer gescanntes Produkt — Barcode-Zuordnung und/oder
/// OCR-Texterkennungs-Ergebnis. Wird lokal gespeichert, damit
/// dieselbe Packung beim nächsten Scan sofort erkannt wird.
struct ScannedProduct: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// EAN/GTIN/PZN-Barcode. nil wenn nur per OCR erkannt.
    var barcode: String?
    /// Produktname (vom Nutzer bestätigt oder angetippt).
    var name: String
    /// Kategorie: Medikament oder Katheter.
    var category: ProductCategory
    /// Charrière-Größe (nur Katheter, aus OCR oder manuell).
    var charriere: Int?
    /// Material (nur Katheter, z. B. "hydrophil beschichtet").
    var material: String?
    /// Wann zuerst gescannt.
    var createdAt: Date = .now
}

enum ProductCategory: String, Codable {
    case medication
    case catheter
}

// MARK: - Katalog (lokaler Speicher)

/// Persönlicher Produktkatalog — füllt sich mit der Zeit selbst.
/// Komplett offline, kein Server, kein Abo.
struct ProductCatalog: Codable, Equatable {
    var products: [ScannedProduct] = []

    static let storageKey = "bb_product_catalog"

    static func load() -> ProductCatalog {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ProductCatalog.self, from: data) else {
            return .init()
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Suche

    /// Produkt anhand des Barcodes finden (exakter Treffer).
    func find(barcode: String) -> ScannedProduct? {
        products.first { $0.barcode == barcode }
    }

    /// Alle Produkte einer Kategorie, neueste zuerst.
    func products(for category: ProductCategory) -> [ScannedProduct] {
        products.filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Pflege

    /// Neues Produkt speichern. Wenn der Barcode schon existiert,
    /// wird der Name/Details aktualisiert (gleiche Packung, neuer Scan).
    @discardableResult
    mutating func upsert(barcode: String?, name: String,
                         category: ProductCategory,
                         charriere: Int? = nil,
                         material: String? = nil) -> ScannedProduct {
        if let bc = barcode, let idx = products.firstIndex(where: { $0.barcode == bc }) {
            products[idx].name = name
            products[idx].charriere = charriere ?? products[idx].charriere
            products[idx].material = material ?? products[idx].material
            save()
            return products[idx]
        }
        let product = ScannedProduct(barcode: barcode, name: name,
                                     category: category,
                                     charriere: charriere,
                                     material: material)
        products.append(product)
        save()
        return product
    }

    /// Einzelnes Produkt löschen.
    mutating func remove(id: UUID) {
        products.removeAll { $0.id == id }
        save()
    }
}

// MARK: - OCR-Helfer: Charrière aus Text erkennen

/// Versucht, eine Charrière-Angabe aus einem OCR-Text zu extrahieren.
/// Erkennt Muster wie "CH 12", "Ch.14", "Fr 16", "Charrière 10", "12 Ch", "14Ch".
func extractCharriere(from text: String) -> Int? {
    let patterns = [
        #"(?i)\b(?:ch|charrière|charriere|fr)[.\s]*(\d{1,2})\b"#,
        #"(?i)\b(\d{1,2})\s*(?:ch|charrière|charriere|fr)\b"#
    ]
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let value = Int(text[range]),
              (6...24).contains(value) else { continue }
        return value
    }
    return nil
}

/// Versucht, Materialangaben aus einem OCR-Text zu extrahieren.
/// Erkennt gängige Katheter-Material-Begriffe.
func extractMaterial(from text: String) -> String? {
    let lower = text.lowercased()
    let keywords: [(search: String, label: String)] = [
        ("hydrophil", "hydrophil beschichtet"),
        ("hydrophilic", "hydrophil beschichtet"),
        ("nelaton", "Nelaton"),
        ("tiemann", "Tiemann"),
        ("pvc", "PVC"),
        ("silikon", "Silikon"),
        ("silicon", "Silikon"),
        ("latex", "Latex"),
    ]
    for kw in keywords {
        if lower.contains(kw.search) { return kw.label }
    }
    return nil
}
