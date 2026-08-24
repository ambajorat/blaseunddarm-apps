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
                    // WICHTIG: ab dem letzten BLASENEINTRAG — Trink-/Stuhl-/
                    // Symptom-Einträge takten den Timer nicht (Fix13).
                    if let last = store.lastBladderEntry {
                        Task { await LiveActivityManager.shared.ensureRunning(
                            from: last.timestamp,
                            intervalMinutes: store.settings.intervalMinutes,
                            todayMl: store.todayMl,
                            todayCount: store.todayCount,
                            settings: store.settings
                        ) }
                        // Fix17: Verlorene Erinnerungen selbst heilen — nach
                        // Neuinstallation (Xcode-Build!) oder Backup-Restore sind
                        // anstehende Mitteilungen weg, geplant wird sonst aber nur
                        // beim Eintrag. Idempotent: fester Identifier ersetzt die
                        // bestehende Planung mit derselben Zeit; überfällig bleibt
                        // still (Guard interval > 0); Wecker-Modus plant seine
                        // festen Zeiten über die eingebaute Weiche neu.
                        if store.settings.reminderEnabled {
                            let elapsed = Int(Date.now.timeIntervalSince(last.timestamp)) / 60
                            NotificationManager.rescheduleReminder(
                                afterMinutes: store.settings.intervalMinutes - elapsed,
                                settings: store.settings
                            )
                        }
                    }
                }
                .modifier(ReviewRequester())
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
