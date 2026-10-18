import Foundation

struct WidgetData: Codable {
    let todayMl: Int
    let todayBowel: Int
    let todayCount: Int
    let lastEntryDate: Date?
    let intervalMinutes: Int
    let reminderEnabled: Bool
    let quietHoursEnabled: Bool
    let quietFrom: Int
    let quietTo: Int
    let updatedAt: Date
    // Wecker-Modus (Optionals: alte Snapshots decodieren sauber)
    var useFixedTimes: Bool? = nil
    var fixedTimes: [Int]? = nil
    var fixedTimesTemplate: [Int]? = nil
    var anchorToFirstVoid: Bool? = nil
    var anchorDayKey: String? = nil

    /// AppSettings-Ausschnitt für die gemeinsame Fälligkeitslogik.
    var fixedSettings: AppSettings {
        var s = AppSettings()
        s.useFixedTimes = useFixedTimes
        s.fixedTimes = fixedTimes
        s.fixedTimesTemplate = fixedTimesTemplate
        s.anchorToFirstVoid = anchorToFirstVoid
        s.anchorDayKey = anchorDayKey
        return s
    }

    static let groupID = "group.blase-und-darm.Blase-und-Darm"
    static let key = "widget_data"

    static func load() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else { return nil }
        return decoded
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: "group.blase-und-darm.Blase-und-Darm"),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
