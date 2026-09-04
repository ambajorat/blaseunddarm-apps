import Foundation

/// Ein Medikament mit optionalen festen Einnahmezeiten.
/// Leere times = Bedarfsmedikament (nur Doku, keine Erinnerung).
struct Medication: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var times: [Int] = []            // Minuten seit Mitternacht
    var remindersEnabled: Bool = true
}

/// Einstellungen für das optionale Medikamenten-Modul.
/// Eigener Speicher-Schlüssel wie bei allen Zusatzmodulen — das Decoding
/// der Bestands-Einstellungen bleibt bei Updates unangetastet.
struct MedicationSettings: Codable, Equatable {
    var enabled: Bool = false
    var medications: [Medication] = []

    static let storageKey = "bb_medication_settings"

    static func load() -> MedicationSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(MedicationSettings.self, from: data) else {
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
