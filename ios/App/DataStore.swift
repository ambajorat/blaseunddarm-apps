import Foundation
import Observation
import WidgetKit

@Observable
final class DataStore {
    private(set) var entries: [ToiletEntry] = []
    var settings: AppSettings = .init() {
        didSet { saveSettings() }
    }

    private let entriesKey = "bb_entries"
    private let settingsKey = "bb_settings"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        loadEntries()
        loadSettings()
        setupWatchSync()
    }

    // MARK: - Watch Sync

    private func setupWatchSync() {
        let connectivity = ConnectivityManager.shared
        connectivity.onNewEntry = { [weak self] entry in
            self?.add(entry)
        }
        syncToWatch()
    }

    func syncToWatch() {
        ConnectivityManager.shared.sendContext(entries: entries, settings: settings)
    }

    // MARK: - Entries

    func add(_ entry: ToiletEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
        // Hinweise: Sofort-Check des Eintrags + Tages-Checks
        AlertEngine.checkEntry(entry)
        AlertEngine.checkDay(entries: entries)
    }

    func delete(_ entry: ToiletEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func update(_ entry: ToiletEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            entries.sort { $0.timestamp > $1.timestamp }
            saveEntries()
        }
    }

    func reload() {
        loadEntries()
        loadSettings()
    }

    func deleteAll() {
        entries.removeAll()
        saveEntries()
    }

    func restoreFromBackup(entries: [ToiletEntry], settings: AppSettings?) {
        self.entries = entries.sorted { $0.timestamp > $1.timestamp }
        saveEntries()
        if let settings {
            self.settings = settings
        }
    }

    // MARK: - Convenience

    var todayEntries: [ToiletEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.timestamp) }
    }

    var todayMl: Int { todayEntries.reduce(0) { $0 + $1.urineMl } }
    var todayBowel: Int { todayEntries.filter(\.bowel).count }
    var todayCount: Int { todayEntries.count }

    var lastEntry: ToiletEntry? { entries.first }

    // MARK: - Persistence

    private func saveEntries() {
        if let data = try? encoder.encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
        syncToWatch()
        updateWidget()
        updateLiveActivity()
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? decoder.decode([ToiletEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveSettings() {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        syncToWatch()
        updateWidget()
        // Intervall-/Ruhezeitänderung in eine ggf. laufende Live Activity spiegeln
        if let last = lastEntry {
            let snap = settings
            Task { await LiveActivityManager.shared.updateStats(
                startTime: last.timestamp,
                todayMl: self.todayMl,
                todayCount: self.todayCount,
                intervalMinutes: snap.intervalMinutes,
                settings: snap
            ) }
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? decoder.decode(AppSettings.self, from: data) else { return }
        settings = decoded
    }

    private func updateWidget() {
        let data = WidgetData(
            todayMl: todayMl,
            todayBowel: todayBowel,
            todayCount: todayCount,
            lastEntryDate: lastEntry?.timestamp,
            intervalMinutes: settings.intervalMinutes,
            reminderEnabled: settings.reminderEnabled,
            quietHoursEnabled: settings.quietHoursEnabled,
            quietFrom: settings.quietFrom,
            quietTo: settings.quietTo,
            updatedAt: .now
        )
        data.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Live Activity nach jedem Eintrag ab dem letzten Eintragszeitpunkt (neu) starten.
    /// Fälligkeit ruhezeitbewusst. Ohne Einträge wird eine laufende Activity beendet.
    private func updateLiveActivity() {
        if let last = lastEntry {
            let snap = settings
            let ml = todayMl, cnt = todayCount
            Task { await LiveActivityManager.shared.startTimer(
                from: last.timestamp,
                intervalMinutes: snap.intervalMinutes,
                todayMl: ml,
                todayCount: cnt,
                settings: snap
            ) }
        } else {
            Task { await LiveActivityManager.shared.stopTimer() }
        }
    }
}
