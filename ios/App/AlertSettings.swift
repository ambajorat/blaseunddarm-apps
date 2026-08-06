import Foundation

/// Einstellungen für den "Hinweise"-Reiter.
/// Bewusst EIGENER Speicher-Schlüssel (nicht AppSettings erweitern):
/// So bleibt das Decoding der bestehenden Einstellungen von
/// Bestandsnutzern beim Update unangetastet.
struct AlertSettings: Codable, Equatable {
    // Einzelmenge (wichtigste Warnung — Überdehnungsrisiko)
    var singleOverEnabled: Bool = true
    var singleOverMl: Int = 450

    // Tagesmenge
    var dayOverEnabled: Bool = false
    var dayOverMl: Int = 2500
    var dayUnderEnabled: Bool = false
    var dayUnderMl: Int = 1000

    // Häufigkeit (Toilettengänge pro Tag)
    var countOverEnabled: Bool = false
    var countOverLimit: Int = 10
    var countUnderEnabled: Bool = false
    var countUnderLimit: Int = 4

    // Persönliche Baseline (Ø der letzten 14 Tage)
    var baselineEnabled: Bool = true
    var baselineDeviationPercent: Int = 30

    static let storageKey = "bb_alert_settings"

    static func load() -> AlertSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AlertSettings.self, from: data) else {
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
