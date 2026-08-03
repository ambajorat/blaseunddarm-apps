import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationManager {
    var permissionGranted = false

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "TOILET_REMINDER"

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
        }
    }

    func scheduleReminder(afterMinutes minutes: Int, settings: AppSettings? = nil) {
        cancelAll()

        var fireDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))

        // Skip quiet hours
        if let settings, settings.quietHoursEnabled {
            let cal = Calendar.current
            let fireHour = cal.component(.hour, from: fireDate)

            let inQuiet: Bool
            if settings.quietFrom < settings.quietTo {
                inQuiet = fireHour >= settings.quietFrom && fireHour < settings.quietTo
            } else {
                inQuiet = fireHour >= settings.quietFrom || fireHour < settings.quietTo
            }

            if inQuiet {
                // Push to quietTo hour
                var components = cal.dateComponents([.year, .month, .day], from: fireDate)
                components.hour = settings.quietTo
                components.minute = 0
                if let quietEnd = cal.date(from: components) {
                    fireDate = quietEnd < fireDate ? cal.date(byAdding: .day, value: 1, to: quietEnd)! : quietEnd
                }
            }
        }

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Toiletten-Erinnerung"
        content.body = "Zeit für den nächsten Toilettengang!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("toilet_reminder.wav"))
        content.categoryIdentifier = categoryID
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "toilet_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
