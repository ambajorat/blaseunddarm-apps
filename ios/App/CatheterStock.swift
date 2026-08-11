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

    // MARK: - Bestandslogik

    /// Blaseneinträge (Katheterisierungen) seit der letzten Korrektur.
    func usedSince(entries: [ToiletEntry]) -> Int {
        entries.filter { $0.urineMl > 0 && $0.timestamp > adjustmentDate }.count
    }

    /// Aktueller rechnerischer Bestand, nie negativ.
    func currentStock(entries: [ToiletEntry]) -> Int {
        max(0, stockAtAdjustment - usedSince(entries: entries))
    }

    /// Ø Katheterisierungen pro Tag über die letzten 14 vollen Tage
    /// (ohne heute, nur Tage mit Blaseneinträgen). Mindestens 3 Datentage,
    /// sonst nil — gleiche Denkweise wie die Baseline der Hinweise.
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

    /// Reichweite in Tagen, abgerundet. nil ohne belastbaren Verbrauch.
    func daysRemaining(entries: [ToiletEntry]) -> Int? {
        guard let usage = dailyUsage(entries: entries), usage > 0 else { return nil }
        return Int(Double(currentStock(entries: entries)) / usage)
    }

    /// Voraussichtliches "leer"-Datum. nil ohne belastbaren Verbrauch.
    func estimatedEmptyDate(entries: [ToiletEntry]) -> Date? {
        guard let days = daysRemaining(entries: entries) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: .now)
    }

    // MARK: - Änderungen

    /// Bestand von Hand setzen (Korrektur). Setzt den Zählpunkt auf jetzt.
    mutating func setStock(_ value: Int) {
        stockAtAdjustment = max(0, value)
        adjustmentDate = .now
    }

    /// Eine Packung auffüllen — auf Basis des aktuellen rechnerischen Bestands.
    mutating func addPack(entries: [ToiletEntry]) {
        setStock(currentStock(entries: entries) + packSize)
    }
}
