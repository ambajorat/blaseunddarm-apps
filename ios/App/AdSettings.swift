import Foundation

/// Einstellungen für die optionalen vegetativen Zeichen (autonome Dysreflexie)
/// samt optionalem Blutdruckfeld. Eigener Speicher-Schlüssel.
struct AdSettings: Codable, Equatable {
    var enabled: Bool = false
    /// Zusätzliches Feld für den systolischen Blutdruck beim Eintrag.
    var bpEnabled: Bool = false

    static let storageKey = "bb_ad_settings"

    static func load() -> AdSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AdSettings.self, from: data) else {
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
