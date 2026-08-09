import Foundation

/// Einstellungen für die optionale Trinkmengen-Erfassung.
/// Bewusst EIGENER Speicher-Schlüssel (nicht AppSettings erweitern):
/// So bleibt das Decoding der bestehenden Einstellungen von
/// Bestandsnutzern beim Update unangetastet.
struct DrinkSettings: Codable, Equatable {
    var enabled: Bool = false
    var presets: [Int] = [150, 200, 300, 500]

    static let storageKey = "bb_drink_settings"

    static func load() -> DrinkSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(DrinkSettings.self, from: data) else {
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
