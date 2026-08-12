import Foundation
import UserNotifications
import UIKit
import AVFoundation
import Observation

@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var permissionGranted = false
    var alarmFiring = false

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "TOILET_REMINDER"
    static let reminderID = "toilet_reminder"
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
        }
    }

    // MARK: - Show notification even when app is in foreground

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
        DispatchQueue.main.async {
            self.triggerInAppAlarm()
        }
    }

    // MARK: - In-App Alarm (vibration + sound)

    func triggerInAppAlarm() {
        alarmFiring = true

        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }

        if let url = Bundle.main.url(forResource: "toilet_alert", withExtension: "wav") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = 1.0
                audioPlayer?.play()
            } catch {}
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.alarmFiring = false
        }
    }

    func dismissAlarm() {
        alarmFiring = false
        audioPlayer?.stop()
    }

    // MARK: - Schedule

    func scheduleReminder(afterMinutes minutes: Int, settings: AppSettings? = nil) {
        Self.rescheduleReminder(afterMinutes: minutes, settings: settings)
    }

    /// Statisch, damit auch Siri-Intents (ohne NotificationManager-Instanz)
    /// die Erinnerung ab ihrem Eintrag neu planen können.
    static func rescheduleReminder(afterMinutes minutes: Int, settings: AppSettings? = nil) {
        let center = UNUserNotificationCenter.current()

        // Nur die eigene Erinnerung ersetzen — NICHT alles löschen,
        // sonst fliegen die wiederkehrenden Ruhezeit-Benachrichtigungen mit raus.
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        var fireDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))

        // Ruhezeit überspringen
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
        content.title = String(localized: "⚠️ Toiletten-Erinnerung")
        content.body = String(localized: "Zeit für den nächsten Toilettengang!")
        content.categoryIdentifier = "TOILET_REMINDER"
        content.interruptionLevel = .timeSensitive

        content.sound = UNNotificationSound.criticalSoundNamed(
            UNNotificationSoundName("toilet_alert.wav"),
            withAudioVolume: 1.0
        )

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        // Fester Identifier: jede neue Planung ERSETZT die alte.
        let request = UNNotificationRequest(
            identifier: reminderID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func scheduleQuietHoursNotifications(settings: AppSettings) {
        guard settings.quietHoursEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: ["quiet_start", "quiet_end"])
            return
        }

        let startContent = UNMutableNotificationContent()
        startContent.title = String(localized: "Ruhezeit beginnt")
        startContent.body = String(localized: "Erinnerungen sind bis \(settings.quietTo):00 Uhr pausiert. Gute Nacht!")
        startContent.sound = .default
        startContent.interruptionLevel = .passive

        var startComponents = DateComponents()
        startComponents.hour = settings.quietFrom
        startComponents.minute = 0
        let startTrigger = UNCalendarNotificationTrigger(dateMatching: startComponents, repeats: true)
        let startRequest = UNNotificationRequest(identifier: "quiet_start", content: startContent, trigger: startTrigger)
        center.add(startRequest)

        let endContent = UNMutableNotificationContent()
        endContent.title = String(localized: "Ruhezeit beendet")
        endContent.body = String(localized: "Erinnerungen sind wieder aktiv.")
        endContent.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("toilet_alert.wav"), withAudioVolume: 1.0)
        endContent.interruptionLevel = .timeSensitive

        var endComponents = DateComponents()
        endComponents.hour = settings.quietTo
        endComponents.minute = 0
        let endTrigger = UNCalendarNotificationTrigger(dateMatching: endComponents, repeats: true)
        let endRequest = UNNotificationRequest(identifier: "quiet_end", content: endContent, trigger: endTrigger)
        center.add(endRequest)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
