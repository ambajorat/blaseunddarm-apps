import Foundation
import WidgetKit

/// Lightweight data access for AppIntents and Widgets (no @Observable needed)
final class SharedDataStore {
    static let shared = SharedDataStore()

    private let entriesKey = "bb_entries"
    private let settingsKey = "bb_settings"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var entries: [ToiletEntry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? decoder.decode([ToiletEntry].self, from: data) else { return [] }
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    var settings: AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? decoder.decode(AppSettings.self, from: data) else { return .init() }
        return decoded
    }

    var todayEntries: [ToiletEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.timestamp) }
    }

    var todayMl: Int { todayEntries.reduce(0) { $0 + $1.urineMl } }
    var todayBowel: Int { todayEntries.filter(\.bowel).count }
    var todayCount: Int { todayEntries.count }
    var lastEntry: ToiletEntry? { entries.first }
    var lastBladderEntry: ToiletEntry? { entries.first(where: { $0.urineMl > 0 }) }

    func addEntry(_ entry: ToiletEntry) {
        var current = entries
        current.insert(entry, at: 0)
        if let data = try? encoder.encode(current) {
            UserDefaults.standard.set(data, forKey: entriesKey)
            UserDefaults.standard.synchronize()
        }

        // WidgetData in die App-Group schreiben — sonst liest das Widget
        // nach einem Siri-Eintrag weiterhin den alten Stand und aktualisiert
        // erst beim nächsten App-Öffnen.
        let s = settings
        let widgetData = WidgetData(
            todayMl: todayMl,
            todayBowel: todayBowel,
            todayCount: todayCount,
            lastEntryDate: lastBladderEntry?.timestamp,
            intervalMinutes: s.intervalMinutes,
            reminderEnabled: s.reminderEnabled,
            quietHoursEnabled: s.quietHoursEnabled,
            quietFrom: s.quietFrom,
            quietTo: s.quietTo,
            updatedAt: .now,
            useFixedTimes: s.useFixedTimes,
            fixedTimes: s.fixedTimes
        )
        widgetData.save()

        // Notify widget to refresh
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
    }
}
