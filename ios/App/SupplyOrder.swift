import Foundation

// MARK: - Kompressenbestand (4.21)

/// Optionaler Bestand steriler Kompressen. Gezählt wird in 2er-Packs:
/// jede Blasenentleerung verbraucht genau ein 2er-Pack.
/// Gleiches Zählprinzip wie beim Katheterbestand (selbstheilend):
/// aktueller Bestand = Korrekturwert − Entleerungen seither.
/// Eigener Speicher-Schlüssel; neue Felder später nur als Optionals ergänzen.
struct CompressStock: Codable, Equatable {
    var enabled: Bool = false
    /// Bezeichnung, wie sie in der Bestellung steht.
    var name: String = CompressStock.defaultName
    /// Bestand (2er-Packs) zum Zeitpunkt der letzten Korrektur/Lieferung.
    var stockAtAdjustment: Int = 0
    var adjustmentDate: Date = .now
    /// 2er-Packs je Packung/Karton (für die Bestellmenge).
    var packSize: Int = 50

    static var defaultName: String { String(localized: "Sterile Kompressen 10 × 10 cm, 2er-Pack") }
    static let storageKey = "bb_compress_stock"

    static func load() -> CompressStock {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CompressStock.self, from: data) else {
            return .init()
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func usedSince(entries: [ToiletEntry]) -> Int {
        entries.filter { $0.urineMl > 0 && $0.timestamp > adjustmentDate }.count
    }

    /// Aktueller rechnerischer Bestand in 2er-Packs, nie negativ.
    func currentStock(entries: [ToiletEntry]) -> Int {
        max(0, stockAtAdjustment - usedSince(entries: entries))
    }

    func daysRemaining(entries: [ToiletEntry], now: Date = .now) -> Int? {
        guard let usage = SupplyUsage.dailyVoids(entries: entries, now: now), usage > 0 else { return nil }
        return Int(Double(currentStock(entries: entries)) / usage)
    }

    mutating func setStock(_ value: Int) {
        stockAtAdjustment = max(0, value)
        adjustmentDate = .now
    }

    mutating func addDelivery(_ packs: Int, entries: [ToiletEntry]) {
        stockAtAdjustment = currentStock(entries: entries) + packs
        adjustmentDate = .now
    }
}

// MARK: - Verbrauch

enum SupplyUsage {
    /// Ø Blasenentleerungen pro Tag (letzte 14 volle Tage, nur Tage mit
    /// Einträgen, mindestens 3 Datentage) — gleiche Regel wie beim Katheterbestand.
    static func dailyVoids(entries: [ToiletEntry], now: Date = .now) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var counts: [Int] = []
        for i in 1...14 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let n = entries.filter { $0.urineMl > 0 && cal.isDate($0.timestamp, inSameDayAs: day) }.count
            if n > 0 { counts.append(n) }
        }
        guard counts.count >= 3 else { return nil }
        return Double(counts.reduce(0, +)) / Double(counts.count)
    }
}

// MARK: - Bestell-Einstellungen

enum OrderRecipient: String, CaseIterable, Identifiable {
    case supplier, practice, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .supplier: String(localized: "Versorger")
        case .practice: String(localized: "Praxis")
        case .both: String(localized: "Beide")
        }
    }
}

/// Adressen und Angaben für die Bestell-Mail. Eigener Speicher-Schlüssel;
/// neue Felder später nur als Optionals ergänzen.
struct OrderSettings: Codable, Equatable {
    var supplierEmail: String = ""
    var customerNumber: String = ""
    var practiceEmail: String = ""
    var patientName: String = ""
    var birthDate: String = ""
    /// Für wie viele Tage bestellt wird.
    var orderDays: Int = 30
    /// Zuletzt gewählter Empfänger (rawValue von OrderRecipient).
    var lastRecipient: String = OrderRecipient.supplier.rawValue

    static let storageKey = "bb_order_settings"

    static func load() -> OrderSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OrderSettings.self, from: data) else {
            return .init()
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

/// Merker "bestellt am". Bewusst getrennt von OrderSettings gespeichert,
/// damit ihn keine veraltete @State-Kopie der Einstellungen überschreibt.
enum OrderState {
    static let key = "bb_order_ordered_on"
    /// So lange gilt eine Bestellung als unterwegs; danach erinnert die App wieder.
    static let pendingDays = 21

    static var orderedOn: Date? {
        UserDefaults.standard.object(forKey: key) as? Date
    }

    static func markOrdered(_ date: Date = .now) {
        UserDefaults.standard.set(date, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func isPending(orderedOn: Date?, now: Date) -> Bool {
        guard let orderedOn else { return false }
        guard let until = Calendar.current.date(byAdding: .day, value: pendingDays, to: orderedOn) else { return false }
        return now < until
    }

    static func isPending(now: Date = .now) -> Bool {
        isPending(orderedOn: orderedOn, now: now)
    }
}

// MARK: - Bestellvorschlag

struct OrderLine: Identifiable, Equatable {
    enum Kind: Equatable { case catheter, compress }
    let id: String
    let kind: Kind
    let name: String
    /// Stück (Katheter) bzw. 2er-Packs (Kompressen) je Packung.
    let packSize: Int
    var packs: Int

    var pieces: Int { packs * packSize }
}

struct SupplyStatus: Equatable {
    let catheterDays: Int?
    let compressDays: Int?
    let warnDays: Int

    var catheterLow: Bool { catheterDays.map { $0 <= warnDays } ?? false }
    var compressLow: Bool { compressDays.map { $0 <= warnDays } ?? false }
    var isDue: Bool { catheterLow || compressLow }
}

enum OrderPlan {
    /// Zeitraum, aus dem der Sortenmix abgeleitet wird.
    static let mixDays = 30

    /// Reichweiten von Kathetern und Kompressen gegen die gemeinsame Warnschwelle.
    /// Kompressen zählen nur, wenn der Katheterbestand aktiv ist (dort liegt die Schwelle).
    static func status(catheter: CatheterStock, compress: CompressStock,
                       entries: [ToiletEntry]) -> SupplyStatus {
        guard catheter.enabled else {
            return SupplyStatus(catheterDays: nil, compressDays: nil, warnDays: catheter.warnDays)
        }
        return SupplyStatus(
            catheterDays: catheter.daysRemaining(entries: entries),
            compressDays: compress.enabled ? compress.daysRemaining(entries: entries) : nil,
            warnDays: catheter.warnDays)
    }

    /// Entleerungen je Sorte in den letzten 30 Tagen. Ohne Daten bekommt
    /// die Standardsorte alles.
    static func mixCounts(catheter: CatheterStock, entries: [ToiletEntry],
                          now: Date = .now) -> [(sort: CatheterSort, count: Int)] {
        let sorts = catheter.effectiveSorts
        let from = Calendar.current.date(byAdding: .day, value: -mixDays, to: now) ?? now
        let window = entries.filter { $0.urineMl > 0 && $0.timestamp > from && $0.timestamp <= now }
        var result = sorts.map { sort in
            (sort: sort, count: window.filter { catheter.belongs($0, to: sort) }.count)
        }
        if result.reduce(0, { $0 + $1.count }) == 0, !result.isEmpty {
            let defaultIndex = sorts.firstIndex { $0.id == catheter.defaultSortId } ?? 0
            result[defaultIndex].count = 1
        }
        return result
    }

    /// Verteilt `total` Stück im Verhältnis der Gewichte (größter Rest),
    /// sodass die Summe exakt `total` ergibt.
    static func distribute(_ total: Int, weights: [Int]) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0, total > 0 else { return weights.map { _ in 0 } }
        let exact = weights.map { Double(total) * Double($0) / Double(sum) }
        var parts = exact.map { Int($0.rounded(.down)) }
        var rest = total - parts.reduce(0, +)
        let order = exact.indices.sorted {
            (exact[$0] - exact[$0].rounded(.down)) > (exact[$1] - exact[$1].rounded(.down))
        }
        for i in order where rest > 0 {
            parts[i] += 1
            rest -= 1
        }
        return parts
    }

    /// Bestellvorschlag: Bedarf für `orderDays` Tage aus dem Ø-Verbrauch,
    /// Katheter im Sortenmix der letzten 30 Tage, je Position auf ganze
    /// Packungen aufgerundet. Ohne Verbrauchsdaten: eine Packung je Position.
    static func lines(catheter: CatheterStock, compress: CompressStock, orderDays: Int,
                      entries: [ToiletEntry], now: Date = .now) -> [OrderLine] {
        guard catheter.enabled else { return [] }
        let usage = SupplyUsage.dailyVoids(entries: entries, now: now)
        let need = usage.map { Int(($0 * Double(orderDays)).rounded(.up)) }
        let mix = mixCounts(catheter: catheter, entries: entries, now: now)
        let cathPack = max(1, catheter.packSize)
        var result: [OrderLine] = []

        let shares: [Int]
        if let need {
            shares = distribute(need, weights: mix.map { $0.count })
        } else {
            shares = mix.map { $0.count > 0 ? 1 : 0 }
        }
        for (i, item) in mix.enumerated() where shares[i] > 0 {
            let packs = need == nil ? 1 : Int((Double(shares[i]) / Double(cathPack)).rounded(.up))
            var title = item.sort.name
            if let ch = item.sort.sizeCharriere { title += ", Ch \(ch)" }
            if let material = item.sort.material, !material.isEmpty { title += ", \(material)" }
            result.append(OrderLine(id: item.sort.id.uuidString, kind: .catheter,
                                    name: title, packSize: cathPack, packs: packs))
        }

        if compress.enabled {
            let compPack = max(1, compress.packSize)
            let packs = need.map { Int((Double($0) / Double(compPack)).rounded(.up)) } ?? 1
            result.append(OrderLine(id: "compress", kind: .compress,
                                    name: compress.name, packSize: compPack, packs: max(1, packs)))
        }
        return result
    }
}

// MARK: - Mailtext

enum OrderMail {
    static func subject(settings: OrderSettings) -> String {
        let base = String(localized: "Nachbestellung Hilfsmittel")
        let name = settings.patientName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : "\(base) – \(name)"
    }

    static func recipients(_ recipient: OrderRecipient, settings: OrderSettings) -> [String] {
        let supplier = settings.supplierEmail.trimmingCharacters(in: .whitespaces)
        let practice = settings.practiceEmail.trimmingCharacters(in: .whitespaces)
        let list: [String]
        switch recipient {
        case .supplier: list = [supplier]
        case .practice: list = [practice]
        case .both: list = [supplier, practice]
        }
        return list.filter { !$0.isEmpty }
    }

    static func lineText(_ line: OrderLine) -> String {
        let format = line.packs == 1
            ? String(localized: "– %lld Packung %@ (je %lld Stück, zusammen %lld)")
            : String(localized: "– %lld Packungen %@ (je %lld Stück, zusammen %lld)")
        return String(format: format, line.packs, line.name, line.packSize, line.pieces)
    }

    static func body(lines: [OrderLine], recipient: OrderRecipient, settings: OrderSettings) -> String {
        let intro: String
        let closing: String
        switch recipient {
        case .supplier:
            intro = String(localized: "ich möchte folgende Hilfsmittel nachbestellen:")
            closing = String(localized: "Bitte liefern Sie an die bekannte Adresse.")
        case .practice:
            intro = String(localized: "ich bitte um eine Folgeverordnung über folgende Hilfsmittel:")
            closing = String(localized: "Bitte geben Sie mir kurz Bescheid, sobald die Verordnung bereitliegt.")
        case .both:
            intro = String(localized: "ich benötige Nachschub an folgenden Hilfsmitteln:")
            closing = String(localized: "An die Praxis: Bitte stellen Sie die Folgeverordnung aus. An den Versorger: Bitte liefern Sie an die bekannte Adresse, sobald die Verordnung vorliegt.")
        }

        var parts: [String] = [String(localized: "Guten Tag,"), "", intro, ""]
        parts.append(contentsOf: lines.map(lineText))
        parts.append("")
        parts.append(closing)

        var facts: [String] = []
        let name = settings.patientName.trimmingCharacters(in: .whitespaces)
        let birth = settings.birthDate.trimmingCharacters(in: .whitespaces)
        let customer = settings.customerNumber.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { facts.append(String(format: String(localized: "Name: %@"), name)) }
        if !birth.isEmpty { facts.append(String(format: String(localized: "Geburtsdatum: %@"), birth)) }
        if !customer.isEmpty, recipient != .practice {
            facts.append(String(format: String(localized: "Kundennummer: %@"), customer))
        }
        if !facts.isEmpty {
            parts.append("")
            parts.append(contentsOf: facts)
        }

        parts.append("")
        parts.append(String(localized: "Vielen Dank und freundliche Grüße"))
        if !name.isEmpty { parts.append(name) }
        return parts.joined(separator: "\n")
    }
}
