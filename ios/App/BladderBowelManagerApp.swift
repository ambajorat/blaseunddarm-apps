import SwiftUI

@main
struct BladderBowelManagerApp: App {
    @State private var store: DataStore
    @State private var notificationManager = NotificationManager()
    @State private var cloudBackup = CloudBackupManager()
    @State private var storeManager = StoreManager()

    init() {
        _store = State(initialValue: DataStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    store.reload()
                    store.syncToWatch()
                    AlertEngine.checkDay(entries: store.entries)
                    // Kein Timer-NEUSTART beim Öffnen — nur Wiederaufnahme,
                    // falls gar keine Activity läuft (z. B. von iOS beendet).
                    if let last = store.lastEntry {
                        Task { await LiveActivityManager.shared.ensureRunning(
                            from: last.timestamp,
                            intervalMinutes: store.settings.intervalMinutes,
                            todayMl: store.todayMl,
                            todayCount: store.todayCount,
                            settings: store.settings
                        ) }
                    }
                }
                .environment(store)
                .environment(notificationManager)
                .environment(cloudBackup)
                .environment(storeManager)
                .onAppear {
                    notificationManager.requestPermission()
                    notificationManager.scheduleQuietHoursNotifications(settings: store.settings)
                    storeManager.startTrialIfNeeded()
                }
        }
    }
}
