//
//  WatchSessionManager.swift
//  Blase & Darm — Watch
//
//  Einziger WCSession-Delegate auf der Uhr. Protokoll wie der
//  ConnectivityManager auf dem iPhone:
//    Uhr -> iPhone : ["newEntry": <codierter ToiletEntry>]
//    iPhone -> Uhr : ["entries": Data, "settings": Data]  (applicationContext)
//
//  Zusätzlich: eigene, ruhezeitbewusste Erinnerung am Handgelenk.
//  Nach jedem Eintrag plant die Uhr selbst eine lokale Benachrichtigung
//  aufs Intervall — funktioniert auch, wenn das iPhone nicht dabei ist.
//

import Foundation
import WatchConnectivity
import WidgetKit
import UserNotifications
import WatchKit

final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    enum SendState {
        case idle
        case sent(String, Date)     // direkt angekommen
        case queued(String)         // wird nachgeliefert
    }

    // UI-Status
    @Published var lastSendState: SendState = .idle

    // Vom iPhone gespiegelter Stand
    @Published var todayMl: Int = 0
    @Published var todayCount: Int = 0
    @Published var todayBowel: Int = 0
    @Published var quickValues: [Int] = [100, 200, 300, 400, 500]
    @Published var intervalMinutes: Int = 210
    @Published var quietHoursEnabled: Bool = false
    @Published var quietFrom: Int = 22
    @Published var quietTo: Int = 6
    @Published var lastEntryDate: Date? = nil

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let reminderID = "watch_toilet_reminder"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        // Benachrichtigungs-Erlaubnis für die eigene Watch-Erinnerung
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Senden (Uhr -> iPhone)

    func send(_ entry: ToiletEntry, label: String) {
        guard let data = try? encoder.encode(entry) else { return }
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(["newEntry": data], replyHandler: { _ in
                DispatchQueue.main.async { self.lastSendState = .sent(label, .now) }
            }, errorHandler: { _ in
                session.transferUserInfo(["newEntry": data])
                DispatchQueue.main.async { self.lastSendState = .queued(label) }
            })
        } else {
            session.transferUserInfo(["newEntry": data])
            DispatchQueue.main.async { self.lastSendState = .queued(label) }
        }

        // Eigene Watch-Erinnerung ab diesem Eintrag neu planen
        scheduleWatchReminder(from: entry.timestamp)
    }

    /// Sofortige lokale Anzeige, wird vom iPhone-Kontext gleich überschrieben.
    func applyLocally(_ entry: ToiletEntry) {
        todayMl += entry.urineMl
        todayCount += 1
        if entry.bowel { todayBowel += 1 }
        // Nur Blasen-Einträge takten Timer/Erinnerung neu
        if entry.urineMl > 0 { lastEntryDate = entry.timestamp }
        writeWidgetData()
    }

    // MARK: - Eigene Watch-Erinnerung (ruhezeitbewusst)

    /// Plant eine lokale Benachrichtigung aufs Intervall ab dem Eintrag.
    /// Fällt die Fälligkeit in die Ruhezeit, wird ans Ruhezeitende verschoben.
    func scheduleWatchReminder(from start: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        var fireDate = start.addingTimeInterval(TimeInterval(intervalMinutes * 60))

        if quietHoursEnabled {
            let cal = Calendar.current
            let fireHour = cal.component(.hour, from: fireDate)

            let inQuiet: Bool
            if quietFrom < quietTo {
                inQuiet = fireHour >= quietFrom && fireHour < quietTo
            } else {
                inQuiet = fireHour >= quietFrom || fireHour < quietTo
            }

            if inQuiet {
                var components = cal.dateComponents([.year, .month, .day], from: fireDate)
                components.hour = quietTo
                components.minute = 0
                if let quietEnd = cal.date(from: components) {
                    fireDate = quietEnd < fireDate
                        ? cal.date(byAdding: .day, value: 1, to: quietEnd)!
                        : quietEnd
                }
            }
        }

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Toiletten-Erinnerung"
        content.body = "Zeit für den nächsten Toilettengang!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Fälligkeit (gleiche Logik wie iPhone-Header/Live Activity)

    /// Körperliche Fälligkeit + optionales Ruhezeitende (wenn die Fälligkeit
    /// in die Ruhezeit fällt). nil, solange kein Eintrag bekannt ist.
    func currentDue() -> (due: Date, quietEnd: Date?)? {
        guard let last = lastEntryDate else { return nil }
        let due = last.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        guard quietHoursEnabled else { return (due, nil) }

        let cal = Calendar.current
        let dueHour = cal.component(.hour, from: due)
        let inQuiet: Bool
        if quietFrom < quietTo {
            inQuiet = dueHour >= quietFrom && dueHour < quietTo
        } else {
            inQuiet = dueHour >= quietFrom || dueHour < quietTo
        }
        guard inQuiet else { return (due, nil) }

        var components = cal.dateComponents([.year, .month, .day], from: due)
        components.hour = quietTo
        components.minute = 0
        components.second = 0
        if let quietEnd = cal.date(from: components) {
            let shifted = quietEnd <= due
                ? cal.date(byAdding: .day, value: 1, to: quietEnd)!
                : quietEnd
            return (due, shifted)
        }
        return (due, nil)
    }

    // MARK: - Empfangenen Stand übernehmen

    private func apply(entries: [ToiletEntry]) {
        let cal = Calendar.current
        let today = entries.filter { cal.isDateInToday($0.timestamp) }
        todayMl = today.reduce(0) { $0 + $1.urineMl }
        todayCount = today.count
        todayBowel = today.filter(\.bowel).count
        writeWidgetData()

        // iPhone-Eintrag verschiebt auch die Watch-Erinnerung nach hinten
        if let last = entries.first(where: { $0.urineMl > 0 }) {
            lastEntryDate = last.timestamp
            scheduleWatchReminder(from: last.timestamp)
        }
    }

    private func apply(settings: AppSettings) {
        quickValues = settings.quickValues
        intervalMinutes = settings.intervalMinutes
        quietHoursEnabled = settings.quietHoursEnabled
        quietFrom = settings.quietFrom
        quietTo = settings.quietTo
        writeWidgetData()
    }

    private func writeWidgetData() {
        let data = WidgetData(
            todayMl: todayMl,
            todayBowel: todayBowel,
            todayCount: todayCount,
            lastEntryDate: lastEntryDate ?? Date(),
            intervalMinutes: intervalMinutes,
            reminderEnabled: true,
            quietHoursEnabled: quietHoursEnabled,
            quietFrom: quietFrom,
            quietTo: quietTo,
            updatedAt: .now
        )
        data.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        handle(context)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    private func handle(_ dict: [String: Any]) {
        DispatchQueue.main.async {
            if let d = dict["settings"] as? Data,
               let settings = try? self.decoder.decode(AppSettings.self, from: d) {
                self.apply(settings: settings)
            }
            if let d = dict["entries"] as? Data,
               let entries = try? self.decoder.decode([ToiletEntry].self, from: d) {
                self.apply(entries: entries)
            }
        }
    }
}
