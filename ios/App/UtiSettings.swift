import Foundation

/// Einstellungen für die optionale HWI-Frühwarnung (ISK).
/// Bewusst EIGENER Speicher-Schlüssel (nicht AppSettings erweitern):
/// So bleibt das Decoding der bestehenden Einstellungen von
/// Bestandsnutzern beim Update unangetastet.
struct UtiSettings: Codable, Equatable {
    var enabled: Bool = false

    static let storageKey = "bb_uti_settings"

    static func load() -> UtiSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(UtiSettings.self, from: data) else {
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
