import Foundation

/// Optionaler Katheterbestand (ISK).
/// Bewusst EIGENER Speicher-Schlüssel (nicht AppSettings erweitern):
/// So bleibt das Decoding der bestehenden Einstellungen von
/// Bestandsnutzern beim Update unangetastet.
///
/// Zähl-Prinzip: Es wird NICHT bei jedem Eintrag dekrementiert.
/// Stattdessen merken wir uns Bestand + Zeitpunkt der letzten Korrektur
/// und rechnen: aktueller Bestand = Korrekturwert − Blaseneinträge seither.
/// Das ist selbstheilend (Korrektur überschreibt alles) und immun gegen
/// doppelte Zustellungen, weil es auf den bereits deduplizierten
/// Einträgen im DataStore basiert.
/// Eine Kathetersorte (4.11). Einträge referenzieren die Sorte über ihren NAMEN
/// (menschenlesbar in CSV, robust bei Sorten-Löschung: unbekannter Name → Standardsorte).
struct CatheterSort: Codable, Equatable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = "Sorte 1"
    var sizeCharriere: Int? = nil
    var material: String? = nil
    var stockAtAdjustment: Int = 0
    var adjustmentDate: Date = .now
}

struct CatheterStock: Codable, Equatable {
    var enabled: Bool = false
    /// Bestand zum Zeitpunkt der letzten Korrektur/Auffüllung.
    var stockAtAdjustment: Int = 0
    /// Zeitpunkt der letzten Korrektur/Auffüllung.
    var adjustmentDate: Date = .now
    /// Stück pro Packung (für den "+1 Packung"-Knopf).
    var packSize: Int = 30
    /// Warnen, wenn die Reichweite unter diese Tageszahl fällt.
    var warnDays: Int = 10
    /// Optional (4.10, decoding-sicher): Charrière-Größe, Material, Rezept-Ablaufdatum.
    var sizeCharriere: Int? = nil
    var material: String? = nil
    var prescriptionDate: Date? = nil
    /// Sortenliste (4.11, decoding-sicher). nil/leer = Alt-Daten → eine Sorte aus den Legacy-Feldern.
    var sorts: [CatheterSort]? = nil
    /// Zuletzt beim Erfassen gewählte Sorte (Vorbelegung der Chips).
    var lastUsedSortId: UUID? = nil
    /// Standardsorte (4.14): wird bei jedem Blaseneintrag automatisch hinterlegt,
    /// auch bei nur einer Sorte — so bleibt der Bestand immer sauber zugeordnet.
    var defaultSortId: UUID? = nil

    static let storageKey = "bb_catheter_stock"

    static func load() -> CatheterStock {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CatheterStock.self, from: data) else {
            return .init()
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Sorten (4.11)

    /// Gültige Sortenliste. Alt-Daten (ohne sorts) erscheinen als EINE Sorte
    /// mit den Legacy-Werten — Migration passiert lesend, gespeichert wird
    /// sie erst, wenn die Einstellungen die Liste anfassen (ensureSorts).
    var effectiveSorts: [CatheterSort] {
        if let s = sorts, !s.isEmpty { return s }
        return [CatheterSort(name: "Sorte 1",
                             sizeCharriere: sizeCharriere,
                             material: material,
                             stockAtAdjustment: stockAtAdjustment,
                             adjustmentDate: adjustmentDate)]
    }

    /// Name der Standardsorte. Fallback: erste Sorte der Liste.
    var defaultSortName: String? {
        guard enabled else { return nil }
        let list = effectiveSorts
        if let id = defaultSortId, let s = list.first(where: { $0.id == id }) { return s.name }
        return list.first?.name
    }

    /// Standardsorte setzen (genau eine; nil = Automatik = erste Sorte).
    mutating func setDefault(_ id: UUID?) {
        defaultSortId = id
    }

    /// Migration festschreiben (vor UI-Bearbeitung der Liste aufrufen).
    mutating func ensureSorts() {
        if sorts == nil || sorts!.isEmpty { sorts = effectiveSorts }
    }

    /// Gehört ein Eintrag zu dieser Sorte? Ohne (oder mit unbekanntem)
    /// Sortennamen zählt er auf die Standardsorte (erste der Liste).
    func belongs(_ entry: ToiletEntry, to sort: CatheterSort) -> Bool {
        let list = effectiveSorts
        if let n = entry.catheterSort, !n.isEmpty, list.contains(where: { $0.name == n }) {
            return n == sort.name
        }
        return sort.id == list.first?.id
    }

    func usedSince(entries: [ToiletEntry], sort: CatheterSort) -> Int {
        entries.filter { $0.urineMl > 0 && $0.timestamp > sort.adjustmentDate && belongs($0, to: sort) }.count
    }

    func stock(of sort: CatheterSort, entries: [ToiletEntry]) -> Int {
        max(0, sort.stockAtAdjustment - usedSince(entries: entries, sort: sort))
    }

    /// Ø tägliche Katheterisierungen dieser Sorte (14 Tage, min. 3 Datentage).
    func dailyUsage(of sort: CatheterSort, entries: [ToiletEntry]) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var counts: [Int] = []
        for i in 1...14 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let n = entries.filter { $0.urineMl > 0 && cal.isDate($0.timestamp, inSameDayAs: day) && belongs($0, to: sort) }.count
            if n > 0 { counts.append(n) }
        }
        guard counts.count >= 3 else { return nil }
        return Double(counts.reduce(0, +)) / Double(counts.count)
    }

    func daysRemaining(of sort: CatheterSort, entries: [ToiletEntry]) -> Int? {
        guard let usage = dailyUsage(of: sort, entries: entries), usage > 0 else { return nil }
        return Int(Double(stock(of: sort, entries: entries)) / usage)
    }

    func estimatedEmptyDate(of sort: CatheterSort, entries: [ToiletEntry]) -> Date? {
        guard let days = daysRemaining(of: sort, entries: entries) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: .now)
    }

    /// Sortenbezogene Änderungen (selbstheilendes Prinzip je Sorte).
    mutating func setStock(_ value: Int, forSort id: UUID) {
        ensureSorts()
        guard let i = sorts!.firstIndex(where: { $0.id == id }) else { return }
        sorts![i].stockAtAdjustment = max(0, value)
        sorts![i].adjustmentDate = .now
    }

    mutating func addPack(forSort id: UUID, entries: [ToiletEntry]) {
        ensureSorts()
        guard let i = sorts!.firstIndex(where: { $0.id == id }) else { return }
        let current = stock(of: sorts![i], entries: entries)
        sorts![i].stockAtAdjustment = current + packSize
        sorts![i].adjustmentDate = .now
    }

    mutating func addDelivery(_ pieces: Int, forSort id: UUID, entries: [ToiletEntry]) {
        ensureSorts()
        guard let i = sorts!.firstIndex(where: { $0.id == id }) else { return }
        let current = stock(of: sorts![i], entries: entries)
        sorts![i].stockAtAdjustment = current + pieces
        sorts![i].adjustmentDate = .now
    }

    // MARK: - Bestandslogik (Gesamtsicht über alle Sorten)

    /// Aktueller rechnerischer Gesamtbestand über alle Sorten, nie negativ.
    func currentStock(entries: [ToiletEntry]) -> Int {
        effectiveSorts.reduce(0) { $0 + stock(of: $1, entries: entries) }
    }

    /// Ø Katheterisierungen pro Tag über ALLE Sorten (14 Tage, min. 3 Datentage) —
    /// Gesamtsicht für den Einstellungs-Footer.
    func dailyUsage(entries: [ToiletEntry]) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var counts: [Int] = []
        for i in 1...14 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let n = entries.filter { $0.urineMl > 0 && cal.isDate($0.timestamp, inSameDayAs: day) }.count
            if n > 0 { counts.append(n) }
        }
        guard counts.count >= 3 else { return nil }
        return Double(counts.reduce(0, +)) / Double(counts.count)
    }

    /// Resttage bis zum Rezept-Ablauf (negativ = abgelaufen). nil ohne Datum.
    var prescriptionDaysLeft: Int? {
        guard let date = prescriptionDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day
    }

    /// Gesamtreichweite: Gesamtbestand aller Sorten ÷ Gesamt-Verbrauch/Tag.
    /// Vor 4.14 wurde hier die KLEINSTE Sorten-Reichweite genommen — das war
    /// falsch, weil `belongs()` Einträge ohne Sortenname der ersten Sorte
    /// zuordnet und die dadurch den gesamten Verbrauch abbekommt, während die
    /// anderen Sorten rechnerisch nie leer werden.
    func daysRemaining(entries: [ToiletEntry]) -> Int? {
        guard let usage = dailyUsage(entries: entries), usage > 0 else { return nil }
        return Int(Double(currentStock(entries: entries)) / usage)
    }

    func estimatedEmptyDate(entries: [ToiletEntry]) -> Date? {
        guard let days = daysRemaining(entries: entries) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: .now)
    }
}
