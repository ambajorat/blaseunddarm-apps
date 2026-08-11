import Foundation

/// Einstellungen für den optionalen Tastbefund (ISK).
/// Eigener Speicher-Schlüssel — Decoding von Bestandsnutzern bleibt unberührt.
struct PalpationSettings: Codable, Equatable {
    var enabled: Bool = false

    static let storageKey = "bb_palpation_settings"

    static func load() -> PalpationSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(PalpationSettings.self, from: data) else {
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
